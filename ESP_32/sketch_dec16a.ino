#include <NimBLEDevice.h>
#include <Preferences.h>
#include "tx_ring_buffer.h"

// ─── Configuration ──────────────────────────────────────────────────────────

static const char* DEVICE_NAME   = "ESP32_BLE_DEVICE";
static const char* SERVICE_UUID  = "12345678-1234-1234-1234-123456789abc";
static const char* CHAR_RX_UUID  = "12345678-1234-1234-1234-123456789abd";
static const char* CHAR_TX_UUID  = "12345678-1234-1234-1234-123456789abe";

static const uint32_t NOTIFY_INTERVAL_MS = 50;
static const uint8_t  MAX_CLIENTS        = 3;
static const uint8_t  PROTOCOL_V2        = 0x02;

// ─── Activation Configuration ───────────────────────────────────────────────

static const char*    ACTIVATION_PASSWORD   = "ACTIVATE_2026";
static const char*    NVS_NAMESPACE         = "device_cfg";
static const char*    NVS_KEY_ACTIVATED     = "activated";
static const char*    NVS_KEY_FAIL_CNT      = "fail_cnt";
static const char*    NVS_KEY_LOCKED        = "locked";
static const uint8_t  MAX_FAILED_ATTEMPTS   = 5;
static const uint32_t LOCKOUT_DURATION_MS   = 60000;  // 1 minute

// ─── Device Registry Configuration ──────────────────────────────────────────

static const uint8_t  MAX_REGISTERED_DEVICES = 20;
static const char*    NVS_KEY_DEV_COUNT       = "dev_count";
// Individual addresses stored as "dev_0", "dev_1", ..., "dev_19"

// ─── Activation State ───────────────────────────────────────────────────────

static Preferences    nvs;
static bool           deviceActivated     = false;
static uint8_t        failedAttempts      = 0;
static uint32_t       lockoutStartMs      = 0;
static bool           isLockedOut         = false;

// ─── NVS Helpers ────────────────────────────────────────────────────────────

static bool nvsInit() {
  if (!nvs.begin(NVS_NAMESPACE, false)) {
    Serial.println("[NVS] ERROR — failed to open namespace");
    return false;
  }
  return true;
}

static bool nvsLoadActivated() {
  return nvs.getBool(NVS_KEY_ACTIVATED, false);
}

static bool nvsSaveActivated(bool val) {
  if (!nvs.putBool(NVS_KEY_ACTIVATED, val)) {
    Serial.println("[NVS] ERROR — failed to write activated flag");
    return false;
  }
  return true;
}

static void nvsSaveFailState(uint8_t attempts, bool locked) {
  nvs.putUChar(NVS_KEY_FAIL_CNT, attempts);
  nvs.putBool(NVS_KEY_LOCKED, locked);
}

static void nvsClearFailState() {
  nvs.putUChar(NVS_KEY_FAIL_CNT, 0);
  nvs.putBool(NVS_KEY_LOCKED, false);
}

// ─── Device Registry NVS Helpers ────────────────────────────────────────────

static uint8_t nvsGetDeviceCount() {
  return nvs.getUChar(NVS_KEY_DEV_COUNT, 0);
}

static bool nvsIsDeviceRegistered(const char* addr) {
  uint8_t count = nvsGetDeviceCount();
  char key[10];
  for (uint8_t i = 0; i < count; i++) {
    snprintf(key, sizeof(key), "dev_%u", i);
    String stored = nvs.getString(key, "");
    if (stored.equals(addr)) return true;
  }
  return false;
}

// Registers addr if not already known. Returns true if newly added.
static bool nvsRegisterDevice(const char* addr) {
  if (nvsIsDeviceRegistered(addr)) return false;

  uint8_t count = nvsGetDeviceCount();
  if (count >= MAX_REGISTERED_DEVICES) {
    Serial.println("[REG] Registry full — device not stored");
    return false;
  }

  char key[10];
  snprintf(key, sizeof(key), "dev_%u", count);
  nvs.putString(key, addr);
  nvs.putUChar(NVS_KEY_DEV_COUNT, count + 1);
  Serial.printf("[REG] Registered new device #%u: %s\n", count, addr);
  return true;
}

// Wipes all registered devices (called on factory reset)
static void nvsClearDeviceRegistry() {
  uint8_t count = nvsGetDeviceCount();
  char key[10];
  for (uint8_t i = 0; i < count; i++) {
    snprintf(key, sizeof(key), "dev_%u", i);
    nvs.remove(key);
  }
  nvs.putUChar(NVS_KEY_DEV_COUNT, 0);
  Serial.println("[REG] Device registry cleared");
}

// ─── TX Ring Buffer ─────────────────────────────────────────────────────────
//     Thread-safe via portENTER_CRITICAL / portEXIT_CRITICAL guards.
//     Producer: NimBLE host task (onWrite callback)
//     Consumer: Arduino loop task

static TxRingBuffer   txRing;
static portMUX_TYPE   txRingMux = portMUX_INITIALIZER_UNLOCKED;

static void txRingInit(TxRingBuffer& rb) {
  rb.head  = 0;
  rb.tail  = 0;
  rb.count = 0;
}

static bool txRingPush(TxRingBuffer& rb, const char* msg) {
  portENTER_CRITICAL(&txRingMux);
  if (rb.count >= TX_BUF_SLOTS) {
    portEXIT_CRITICAL(&txRingMux);
    return false;
  }
  strncpy(rb.data[rb.head], msg, TX_MSG_MAX_LEN - 1);
  rb.data[rb.head][TX_MSG_MAX_LEN - 1] = '\0';
  rb.head = (rb.head + 1) % TX_BUF_SLOTS;
  rb.count++;
  portEXIT_CRITICAL(&txRingMux);
  return true;
}

static bool txRingPop(TxRingBuffer& rb, char* out, uint8_t maxLen) {
  portENTER_CRITICAL(&txRingMux);
  if (rb.count == 0) {
    portEXIT_CRITICAL(&txRingMux);
    return false;
  }
  strncpy(out, rb.data[rb.tail], maxLen - 1);
  out[maxLen - 1] = '\0';
  rb.tail = (rb.tail + 1) % TX_BUF_SLOTS;
  rb.count--;
  portEXIT_CRITICAL(&txRingMux);
  return true;
}

static void txRingClear(TxRingBuffer& rb) {
  portENTER_CRITICAL(&txRingMux);
  txRingInit(rb);
  portEXIT_CRITICAL(&txRingMux);
}

static uint8_t txRingCount(TxRingBuffer& rb) {
  portENTER_CRITICAL(&txRingMux);
  uint8_t c = rb.count;
  portEXIT_CRITICAL(&txRingMux);
  return c;
}

// ─── Globals ────────────────────────────────────────────────────────────────

static NimBLECharacteristic* pTxChar          = nullptr;
static volatile uint8_t      clientCount      = 0;
static volatile uint8_t      subscribedCount  = 0;
static uint32_t              lastNotifyMs     = 0;

// ─── Utility ────────────────────────────────────────────────────────────────

static void trimTrailing(std::string& s) {
  while (!s.empty()) {
    char c = s.back();
    if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
      s.pop_back();
    } else {
      break;
    }
  }
}

static void queueTxMessage(const char* msg) {
  if (!txRingPush(txRing, msg)) {
    Serial.println("[TX] Ring buffer full — message dropped");
  }
}

// ─── v2 Packet Helpers ───────────────────────────────────────────────────────

static uint8_t xorChecksum(const uint8_t* data, size_t len) {
  uint8_t out = 0;
  for (size_t i = 0; i < len; i++) out ^= data[i];
  return out;
}

// Returns true if this write was recognized as a v2 packet (valid or invalid).
// Returning true means caller should not process this payload as text command.
static bool tryHandleV2Packet(const std::string& rxValue) {
  const size_t n = rxValue.size();
  if (n < 14) return false;  // minimum v2 frame size

  const uint8_t* b = reinterpret_cast<const uint8_t*>(rxValue.data());
  const uint8_t version = (b[0] >> 6) & 0x03;
  if (version != PROTOCOL_V2) return false;

  const uint8_t msgLen = b[12];
  const size_t expectedLen = 13 + (size_t)msgLen + 1;

  if (n != expectedLen) {
    Serial.printf("[V2] INVALID length: got=%u expected=%u\n",
                  (unsigned)n, (unsigned)expectedLen);
    queueTxMessage("MSG_BAD_LEN");
    return true;
  }

  const uint8_t expectedCsum = xorChecksum(b, expectedLen - 1);
  const uint8_t packetCsum = b[expectedLen - 1];
  if (expectedCsum != packetCsum) {
    Serial.printf("[V2] INVALID checksum: calc=0x%02X pkt=0x%02X\n",
                  expectedCsum, packetCsum);
    queueTxMessage("MSG_BAD_CSUM");
    return true;
  }

  const uint8_t priority = (b[0] >> 4) & 0x03;
  const uint8_t status = (b[0] >> 2) & 0x03;
  const uint8_t severity = ((b[0] & 0x03) << 2) | ((b[1] >> 6) & 0x03);
  const uint8_t injuryFlags = b[2];
  const uint8_t situationFlags = b[3];
  const uint8_t needsFlags = b[4];
  const uint8_t peopleFlags = b[5];
  const uint8_t adults = (b[6] >> 4) & 0x0F;
  const uint8_t children = b[6] & 0x0F;
  const uint8_t triageScore = b[7];

  std::string msg;
  if (msgLen > 0) {
    msg.assign(reinterpret_cast<const char*>(b + 13), msgLen);
  }

  Serial.printf("[V2] OK prio=%u status=%u sev=%u triage=%u adults=%u children=%u msgLen=%u\n",
                priority, status, severity, triageScore, adults, children, msgLen);
  Serial.printf("[V2] Flags injury=0x%02X situation=0x%02X needs=0x%02X people=0x%02X\n",
                injuryFlags, situationFlags, needsFlags, peopleFlags);
  if (!msg.empty()) {
    Serial.printf("[V2] Message: \"%s\"\n", msg.c_str());
  }

  queueTxMessage("MSG_OK");
  return true;
}

// During pre-activation we only accept explicit password text.
// Binary frames (or non-printable payloads) must not consume password attempts.
static bool looksLikeBinaryOrV2(const std::string& rxValue) {
  if (rxValue.empty()) return false;
  const uint8_t* b = reinterpret_cast<const uint8_t*>(rxValue.data());
  const uint8_t version = (b[0] >> 6) & 0x03;
  if (version == PROTOCOL_V2) return true;
  for (size_t i = 0; i < rxValue.size(); i++) {
    const uint8_t c = b[i];
    const bool printableAscii = (c >= 32 && c <= 126);
    if (!printableAscii) return true;
  }
  return false;
}

// ─── Forward declarations ───────────────────────────────────────────────────

static void startAdvertising();

// ─── BLE Characteristic Callbacks ───────────────────────────────────────────

class RxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo&) override {
    if (clientCount == 0) return;

    std::string rxValue = pChar->getValue();
    Serial.printf("[RX] %u bytes\n", (unsigned)rxValue.length());

    std::string trimmed = rxValue;
    trimTrailing(trimmed);

    // ── MODE BRANCH: Activation vs Normal ──────────────────────────
    if (!deviceActivated) {
      if (looksLikeBinaryOrV2(rxValue)) {
        Serial.println("[AUTH] Ignoring binary/non-text payload in activation mode");
        queueTxMessage("NEED_ACTIVATION");
        return;
      }
      handleActivation(trimmed);
    } else {
      // In activated mode, first try v2 binary packet handling.
      if (tryHandleV2Packet(rxValue)) return;
      handleCommand(trimmed);
    }
  }

private:
  void handleActivation(const std::string& input) {
    // Lockout check: too many failed attempts
    if (isLockedOut) {
      uint32_t elapsed = millis() - lockoutStartMs;
      if (elapsed < LOCKOUT_DURATION_MS) {
        uint32_t remaining = (LOCKOUT_DURATION_MS - elapsed) / 1000;
        Serial.printf("[AUTH] Locked out — %u seconds remaining\n", remaining);
        char buf[48];
        snprintf(buf, sizeof(buf), "LOCKED_%u", remaining);
        queueTxMessage(buf);
        return;
      }
      isLockedOut = false;
      failedAttempts = 0;
      nvsClearFailState();
    }

    if (input == ACTIVATION_PASSWORD) {
      Serial.println("[AUTH] Activation password CORRECT");

      if (nvsSaveActivated(true)) {
        deviceActivated = true;
        nvsClearFailState();  // reset failed attempts on success
        queueTxMessage("ACTIVATED");
        Serial.println("[AUTH] Device activated — no reboot (connection stays)");
      } else {
        queueTxMessage("NVS_ERROR");
        Serial.println("[AUTH] NVS write failed — not activating");
      }
    } else {
      failedAttempts++;
      Serial.printf("[AUTH] Wrong password (attempt %d/%d)\n",
                    failedAttempts, MAX_FAILED_ATTEMPTS);

      if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
        isLockedOut = true;
        lockoutStartMs = millis();
        nvsSaveFailState(failedAttempts, true);  // persist lockout
        Serial.println("[AUTH] Too many attempts — locked for 60s");
        queueTxMessage("LOCKED_60");
      } else {
        nvsSaveFailState(failedAttempts, false);  // persist attempt count
        char buf[32];
        snprintf(buf, sizeof(buf), "WRONG_PW_%d", MAX_FAILED_ATTEMPTS - failedAttempts);
        queueTxMessage(buf);
      }
    }
  }

  void handleCommand(const std::string& input) {
    Serial.printf("[CMD] \"%s\"\n", input.c_str());

    if (input == "GET_DEVICE_COUNT") {
      uint8_t count = nvsGetDeviceCount();
      char buf[32];
      snprintf(buf, sizeof(buf), "DEVICE_COUNT_%u", count);
      queueTxMessage(buf);
      return;
    }

    if (input == "FACTORY_RESET") {
      nvsClearDeviceRegistry();
      nvsSaveActivated(false);
      nvsClearFailState();
      deviceActivated = false;
      failedAttempts  = 0;
      isLockedOut     = false;
      queueTxMessage("RESET_OK");
      Serial.println("[CMD] Factory reset — device deactivated, registry cleared");
      return;
    }

    queueTxMessage("MSG_OK");
  }
};

// ─── TX Callbacks (CCCD subscribe tracking) ─────────────────────────────────

class TxCallbacks : public NimBLECharacteristicCallbacks {
  void onSubscribe(NimBLECharacteristic*, NimBLEConnInfo&,
                   uint16_t subValue) override {
    if (subValue == 0) {
      if (subscribedCount > 0) subscribedCount--;
      Serial.println("[CCCD] Client UNSUBSCRIBED");
    } else {
      subscribedCount++;
      Serial.printf("[CCCD] Client SUBSCRIBED (0x%04X)\n", subValue);
    }
  }
};

// ─── BLE Server Callbacks ───────────────────────────────────────────────────

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo& info) override {
    clientCount++;
    Serial.printf("[BLE] Client connected (%d total)\n", clientCount);

    // Register this device by its BLE address (idempotent — no-op if already known)
    std::string addrStr = info.getAddress().toString();
    nvsRegisterDevice(addrStr.c_str());

    // Tell client whether device needs activation
    if (!deviceActivated) {
      queueTxMessage("NEED_ACTIVATION");
    }

    if (clientCount < MAX_CLIENTS) {
      startAdvertising();
    }
  }

  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int reason) override {
    if (clientCount > 0) clientCount--;
    if (subscribedCount > 0) subscribedCount--;
    Serial.printf("[BLE] Disconnected (reason %d, %d remain)\n", reason, clientCount);
    startAdvertising();
  }
};

// ─── Advertising ────────────────────────────────────────────────────────────

static void setupAdvertising() {
  NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID);
  pAdv->setName(DEVICE_NAME);
  pAdv->enableScanResponse(true);
}

static void startAdvertising() {
  NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
  if (pAdv->isAdvertising()) return;

  if (pAdv->start()) {
    Serial.println("[ADV] Advertising started");
  } else {
    Serial.println("[ADV] ERROR — failed to start");
  }
}

// ─── setup() ────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);

  uint32_t t0 = millis();
  while (!Serial && (millis() - t0 < 500)) {}

  Serial.println("==========================================");
  Serial.println("  ESP32 BLE Server — NimBLE (multi-conn)  ");
  Serial.println("==========================================");

  // ── NVS: Load activation state ──
  if (nvsInit()) {
    deviceActivated = nvsLoadActivated();
    Serial.printf("[NVS] Device %s\n", deviceActivated ? "ACTIVATED" : "NOT ACTIVATED");

    // Restore fail/lockout state so power-cycling can't bypass the lockout
    failedAttempts = nvs.getUChar(NVS_KEY_FAIL_CNT, 0);
    isLockedOut    = nvs.getBool(NVS_KEY_LOCKED, false);
    if (isLockedOut) {
      lockoutStartMs = millis();  // restart lockout timer from boot
      Serial.println("[AUTH] Lockout restored from NVS — 60s lockout restarted");
    } else if (failedAttempts > 0) {
      Serial.printf("[AUTH] %u failed attempt(s) restored from NVS\n", failedAttempts);
    }
  } else {
    Serial.println("[NVS] Init failed — running in UNACTIVATED safe mode");
    deviceActivated = false;
  }

  txRingInit(txRing);

  NimBLEDevice::init(DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P3);

  NimBLEServer* pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService* pService = pServer->createService(SERVICE_UUID);

  // RX — client writes here
  NimBLECharacteristic* pRxChar = pService->createCharacteristic(
    CHAR_RX_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
  );
  pRxChar->setCallbacks(new RxCallbacks());

  // TX — server notifies here (CCCD auto-created)
  pTxChar = pService->createCharacteristic(
    CHAR_TX_UUID,
    NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ
  );
  pTxChar->setCallbacks(new TxCallbacks());

  pService->start();

  setupAdvertising();
  startAdvertising();

  Serial.println("------------------------------------------");
  Serial.printf("  Service : %s\n", SERVICE_UUID);
  Serial.printf("  RX Char : %s\n", CHAR_RX_UUID);
  Serial.printf("  TX Char : %s\n", CHAR_TX_UUID);
  Serial.printf("  Status  : %s\n", deviceActivated ? "READY" : "AWAITING ACTIVATION");
  Serial.println("------------------------------------------");
}

// ─── loop() ─────────────────────────────────────────────────────────────────

void loop() {
  // Drain ring buffer — only when client is connected and subscribed
  if (clientCount > 0 && subscribedCount > 0 && pTxChar && txRingCount(txRing) > 0) {
    uint32_t now = millis();
    if (now - lastNotifyMs >= NOTIFY_INTERVAL_MS) {
      char msg[TX_MSG_MAX_LEN];
      if (txRingPop(txRing, msg, sizeof(msg))) {
        pTxChar->setValue((uint8_t*)msg, strlen(msg));
        if (pTxChar->notify()) {
          Serial.printf("[TX] \"%s\"\n", msg);
        } else {
          Serial.println("[TX] notify() failed");
        }
        lastNotifyMs = now;
      }
    }
  }

  vTaskDelay(1);
}
