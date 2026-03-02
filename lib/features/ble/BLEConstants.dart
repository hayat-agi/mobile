/// All the settings that must match the ESP32 firmware exactly.
///
/// ⚠️ If you change a UUID or response string here,
///    you MUST also update the ESP32 firmware to match!
class BleConstants {
  BleConstants._(); // no instances — just static constants

  // ── Device Name ─────────────────────────────────────────────────
  // This is the name the ESP32 advertises over Bluetooth
  static const String deviceName = 'ESP32_BLE_DEVICE';

  // ── UUIDs ───────────────────────────────────────────────────────
  // These identify our BLE service and characteristics.
  // Think of a "service" as a folder and "characteristics" as files.

  /// The main BLE service — like a container for RX and TX
  static const String serviceUuid =
      '12345678-1234-1234-1234-123456789abc';

  /// RX characteristic — we write data to this (ESP32 reads it)
  static const String charRxUuid =
      '12345678-1234-1234-1234-123456789abd';

  /// TX characteristic — ESP32 sends notifications here (we read it)
  static const String charTxUuid =
      '12345678-1234-1234-1234-123456789abe';

  // ── ESP32 Response Codes ────────────────────────────────────────
  // These are the text strings the ESP32 sends back to us

  /// "Message OK" — the ESP32 received our message and processed it
  static const String respMsgOk = 'MSG_OK';

  /// "Reset OK" — the ESP32 accepted the factory reset command
  static const String respResetOk = 'RESET_OK';

  // ── Activation Response Codes ──────────────────────────────────

  /// ESP32 is in factory state and needs activation password
  static const String respNeedActivation = 'NEED_ACTIVATION';

  /// Activation succeeded — device will reboot in ~2 seconds
  static const String respActivated = 'ACTIVATED';

  /// Prefix for wrong password — full format: "WRONG_PW_3" (3 attempts left)
  static const String respWrongPwPrefix = 'WRONG_PW_';

  /// Prefix for lockout — full format: "LOCKED_58" (58 seconds remaining)
  static const String respLockedPrefix = 'LOCKED_';

  /// NVS write failed on the ESP32 side
  static const String respNvsError = 'NVS_ERROR';

  // ── Commands We Send ────────────────────────────────────────────

  /// Tells the ESP32 to erase all settings and reboot
  static const String cmdFactoryReset = 'FACTORY_RESET';

  // ── Timing Settings ─────────────────────────────────────────────

  /// Max MTU (message size) — we don't negotiate this right now
  static const int maxMtu = 247;

  /// How long to scan for devices before stopping
  static const Duration scanTimeout = Duration(seconds: 10);

  /// How long to wait for a BLE connection before giving up
  static const Duration connectTimeout = Duration(seconds: 20);

  /// How long to wait for an ESP32 response after sending a message
  static const Duration responseTimeout = Duration(seconds: 5);

  /// Longer timeout for activation — ESP32 sends ACTIVATED then reboots
  static const Duration activationResponseTimeout = Duration(seconds: 8);

  /// Short pauses to let the Android BLE stack settle
  static const Duration mtuDelay = Duration(milliseconds: 300);
  static const Duration postMtuDelay = Duration(milliseconds: 500);
  static const Duration notifySetupDelay = Duration(milliseconds: 300);
  static const Duration postConnectDelay = Duration(milliseconds: 1500);

  // ── Queue & Retry Settings ────────────────────────────────────────

  /// Max attempts when the gateway is busy (another user holds it).
  /// Set high enough for 10–15 phones competing for one ESP32.
  static const int maxQueueRetries = 12;

  /// Upper bound for randomized backoff between retry attempts
  static const Duration maxRetryBackoff = Duration(seconds: 15);

  /// Minimum backoff before the very first retry — gives the ESP32
  /// time to finish with whoever is connected right now.
  static const Duration initialRetryDelay = Duration(seconds: 2);

  /// Max messages a single phone may send per connection cycle in
  /// disaster mode.  After this many it disconnects so the next
  /// survivor can take a turn.
  static const int maxMessagesPerDrain = 2;

  /// Maximum messages allowed in the queue.  Oldest messages are
  /// dropped when new ones arrive beyond this limit.
  static const int maxQueueSize = 3;

  /// Minimum pause between drain cycles in disaster mode so one
  /// phone cannot monopolize the gateway.
  static const Duration drainCooldown = Duration(seconds: 10);
}
