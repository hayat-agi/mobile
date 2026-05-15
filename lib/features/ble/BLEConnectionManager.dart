import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'BLEConstants.dart';
// ═══════════════════════════════════════════════════════════════════════════
//  BLE Connection Manager
//
//  This class handles everything about talking to the ESP32 over Bluetooth:
//    1. Scanning for nearby ESP32 devices
//    2. Connecting to a device
//    3. Sending text messages and binary data
//    4. Receiving responses (notifications) from the ESP32
//    5. Disconnecting cleanly
//
//  The ESP32 has two "channels" (called characteristics):
//    • RX — we WRITE data here (the ESP32 reads it)
//    • TX — the ESP32 NOTIFIES us here (we listen for responses)
//
//  All the UUID strings and response codes are in BLEConstants.dart.
// ═══════════════════════════════════════════════════════════════════════════

class BleConnection extends GetxController {
  // ── These are "reactive" variables ──
  // GetX watches them. When they change, the UI auto-updates.
  final isScanning = false.obs; // true while we're scanning for devices
  final isConnected = false.obs; // true when BLE link is active
  final isAuthenticated = false.obs; // true when ready to send commands
  final status = 'Idle'.obs; // short status text shown in the UI
  final results = <ScanResult>[].obs; // list of discovered BLE devices
  final messages = <String>[].obs; // chat-style message log

  // ── Activation state ──
  final needsActivation = false.obs; // true when ESP32 is in factory state

  // ── Private stuff (not visible to the UI) ──
  BluetoothDevice? _device; // the ESP32 we're connected to
  BluetoothCharacteristic? _rx; // characteristic we write to
  BluetoothCharacteristic? _tx; // characteristic we get notifications from
  BluetoothCharacteristic? _sensor; // MPU-6050 sensor stream characteristic

  StreamSubscription<List<ScanResult>>? _scanSub; // scan results listener
  StreamSubscription<BluetoothConnectionState>?
  _connSub; // connection state listener
  StreamSubscription<List<int>>? _notifySub; // notification listener
  StreamSubscription<List<int>>? _sensorSub; // sensor stream listener

  /// Broadcast stream of raw 24-byte MPU-6050 sensor packets from the ESP32.
  /// Emits whenever a sensor NOTIFY arrives. Empty when no ESP32 is connected.
  final _sensorController = StreamController<List<int>>.broadcast();

  /// Raw sensor byte stream — decode with [SensorPacket.fromBytes].
  Stream<List<int>> get rawSensorStream => _sensorController.stream;

  /// True when the connected ESP32 exposes the external sensor characteristic.
  bool get hasSensorCharacteristic => _sensor != null;

  // This timer lets go of the Gateway connection after a period of silence.
  // This is CRITICAL so other people in the building can also connect and send messages.
  Timer? _autoReleaseTimer;

  // This "completer" is how we wait for the ESP32's response after writing.
  // We create one before each write, and it gets completed when the
  // notification arrives from the ESP32. Think of it as a one-shot mailbox.
  Completer<String>? _responseCompleter;

  // Serialises commands that wait for a single ESP32 notification response.
  // Without this, a heartbeat or a second command can supersede the active
  // response completer and make the caller consume the wrong response.
  Completer<void>? _sendLock;

  /// Completer for NEED_ACTIVATION — used when adding a new gateway.
  /// Created before subscribe, completed when we receive NEED_ACTIVATION.
  Completer<bool>? _activationPromptCompleter;

  /// True while sendActivationPassword is waiting for response.
  /// On disconnect, we delay cancelling the completer so ACTIVATED can arrive.
  bool _isWaitingForActivationResponse = false;

  /// Fired when the ESP32 reports battery and/or RSSI via MSG_OK: or STATUS: prefix.
  /// deviceId = BLE MAC of the connected gateway, bat/rssi null if not in message.
  void Function(String deviceId, int? bat, int? rssi)? onStatusUpdate;

  /// Parses "MSG_OK:bat=82,rssi=-65", "STATUS:bat=82,rssi=-65", or "STATUS:rssi=-65".
  void _tryParseStatus(String msg) {
    final colonIdx = msg.indexOf(':');
    if (colonIdx < 0) return;
    final payload = msg.substring(colonIdx + 1);
    int? bat;
    int? rssi;
    for (final part in payload.split(',')) {
      if (part.startsWith('bat=')) {
        bat = int.tryParse(part.substring(4));
      } else if (part.startsWith('rssi=')) {
        rssi = int.tryParse(part.substring(5));
      }
    }
    if ((bat != null || rssi != null) && _lastDeviceId != null) {
      onStatusUpdate?.call(_lastDeviceId!, bat, rssi);
    }
  }

  String? _packetAckError(String response) {
    if (response == BleConstants.respMsgBadLen) {
      return 'Paket reddedildi: uzunluk hatası';
    }
    if (response == BleConstants.respMsgBadChecksum) {
      return 'Paket reddedildi: checksum hatası';
    }
    if (response == BleConstants.respMsgQueueFull) {
      return 'ESP32 gönderim kuyruğu dolu — biraz sonra tekrar deneyin';
    }
    return null;
  }

  Timer? _activationResponseCancelTimer;

  // When true, we're in the middle of connecting. This prevents
  // "unexpected disconnect" events from firing during the connection process.
  bool _connectInProgress = false;

  // ── Disaster Mode ──
  // When true, the gateway is released immediately after each send
  // so the next person in the building can connect faster.
  bool disasterMode = false;

  // When the disaster screen is disposed while a drain is in progress,
  // we can't flip disasterMode off immediately — it would leave the
  // gateway held open. This flag defers the flip until the drain ends.
  bool _pendingDisasterModeOff = false;

  // ── Heartbeat & Auto-Reconnect ──
  // Sends PING every 30s while connected. If ESP32 doesn't reply twice in
  // a row, we know the connection is dead and trigger a silent reconnect.
  Timer? _heartbeatTimer;
  int _heartbeatFailCount = 0;
  bool _pingInFlight = false;
  bool _heartbeatAutoReconnecting = false;
  // Set true when the USER explicitly disconnects so heartbeat doesn't
  // try to reconnect on their behalf.
  bool _intentionalDisconnect = false;

  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _pingTimeout = Duration(seconds: 5);
  static const int _maxHeartbeatFails = 2;
  static const int _maxAutoReconnectAttempts = 10;

  // ── Queue & Auto-Reconnect state ──
  // Remembers the last device so we can reconnect without scanning.
  String? _lastDeviceId;
  String? get lastDeviceId => _lastDeviceId;
  // Messages queued while disconnected — drained after reconnect.
  final List<String> _messageQueue = [];
  // Guard flag so only one reconnect+drain cycle runs at a time.
  bool _isDrainingQueue = false;

  /// Set the target device ID for auto-reconnect (used by SOS flow
  /// when the queue system needs to know which gateway to reconnect to).
  void setLastDeviceId(String deviceId) {
    _lastDeviceId = deviceId;
  }

  Future<void> _queueMessage(String text, {bool silent = false}) async {
    if (_messageQueue.length >= BleConstants.maxQueueSize) {
      final dropped = _messageQueue.removeAt(0);
      messages.add('[System] Kuyruk dolu — eski mesaj silindi: $dropped');
    }
    _messageQueue.add(text);
    await _persistQueue();
    if (!silent) messages.add('ME: $text');
    unawaited(_reconnectAndDrainQueue());
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SCAN — Find nearby ESP32 devices
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> scanDevices() async {
    // Don't start a new scan if one is already running
    if (isScanning.value) return;

    try {
      // Step 1: Make sure Bluetooth is turned on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        status.value = 'Bluetooth kapalı — lütfen açın';
        return;
      }

      // Step 2: Ask the user for Bluetooth & location permissions
      status.value = 'Requesting permissions…';
      final scanPerm = await Permission.bluetoothScan.request();
      final connPerm = await Permission.bluetoothConnect.request();
      final locPerm = await Permission.locationWhenInUse.request();

      if (!scanPerm.isGranted || !connPerm.isGranted || !locPerm.isGranted) {
        status.value = 'Permissions denied — enable in Settings';
        return;
      }

      // Step 3: Stop any old scan that might still be running
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 100));

      results.clear();
      isScanning.value = true;
      status.value = 'Scanning…';

      // Step 4: Listen for scan results
      final targetUuid = BleConstants.serviceUuid.toLowerCase();

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        // Use a map to avoid duplicate devices (keyed by device ID)
        final map = <String, ScanResult>{};

        for (final r in list) {
          // Check if this device advertises OUR service UUID
          final serviceUuids = r.advertisementData.serviceUuids
              .map((u) => u.toString().toLowerCase())
              .toList();

          // Only accept devices with our UUID — nothing else
          if (serviceUuids.contains(targetUuid)) {
            map[r.device.remoteId.str] = r;
          }
        }

        // REQ-GW-02: Sort by signal strength (RSSI)
        // Higher RSSI = stronger signal = closer device = shows first
        // RSSI is negative (e.g. -40 is stronger than -80)
        final filtered = map.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

        results.value = List<ScanResult>.from(filtered);
        results.refresh();
        status.value = 'Found ${filtered.length} device(s)';
      });

      // Step 5: Start the actual BLE scan
      await FlutterBluePlus.startScan(
        timeout: BleConstants.scanTimeout,
        androidUsesFineLocation: false,
      );

      // Wait until scanning is fully done
      await FlutterBluePlus.isScanning
          .where((v) => v == false)
          .first
          .timeout(
            BleConstants.scanTimeout + const Duration(seconds: 3),
            onTimeout: () => false,
          );

      // Step 6: Stop listening to scan results — important!
      // Keeping this listener active during BLE connect causes Android
      // to crash the BLE connection (error 531).
      _scanSub?.cancel();
      _scanSub = null;

      isScanning.value = false;
      status.value = 'Scan complete — ${results.length} device(s)';
    } catch (e) {
      _scanSub?.cancel();
      _scanSub = null;
      isScanning.value = false;
      status.value = 'Scan error: $e';
      await FlutterBluePlus.stopScan().catchError((_) {});
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TARGETED CONNECT — Find and connect to a specific gateway by its ID
  // ═══════════════════════════════════════════════════════════════════════

  /// REQ-GW-05: Automatically find and connect to a known gateway.
  /// This is used when the app starts or when sending a background message.
  Future<bool> connectById(String deviceId) async {
    if (isConnected.value && _device?.remoteId.str == deviceId) {
      await _resetAutoReleaseTimer(); // Stay connected if we're already there
      return true;
    }

    status.value = 'Otomatik bağlanılıyor…';

    // 1. Quick targeted scan (only for 5 seconds)
    await FlutterBluePlus.stopScan();

    final Completer<ScanResult?> foundC = Completer();
    StreamSubscription<List<ScanResult>>? sub;

    try {
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          if (r.device.remoteId.str == deviceId) {
            if (!foundC.isCompleted) foundC.complete(r);
          }
        }
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: false,
      );

      final result = await foundC.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      await sub.cancel();
      await FlutterBluePlus.stopScan();

      if (result != null) {
        await connect(result);
        return isConnected.value;
      }
      status.value = 'Cihaz bulunamadı';
      return false;
    } catch (e) {
      await sub?.cancel();
      await FlutterBluePlus.stopScan().catchError((_) {});
      return false;
    }
  }

  /// Waits for NEED_ACTIVATION notification after connect.
  /// Returns true if device needs activation, false if timeout or already active.
  Future<bool> waitForActivationPrompt({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Fast path: notification already received and flag set
    if (needsActivation.value) {
      debugPrint('[ACTIVATION] waitForActivationPrompt → fast path TRUE');
      return true;
    }

    final c = _activationPromptCompleter;
    if (c == null) {
      // Completer missing — notification may still be in flight, wait briefly
      debugPrint(
        '[ACTIVATION] waitForActivationPrompt → completer NULL, waiting 1500ms',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      final result = needsActivation.value;
      debugPrint(
        '[ACTIVATION] waitForActivationPrompt → fallback result=$result',
      );
      return result;
    }
    try {
      debugPrint(
        '[ACTIVATION] waitForActivationPrompt → waiting on completer (${timeout.inSeconds}s timeout)',
      );
      final result = await c.future.timeout(
        timeout,
        onTimeout: () => needsActivation.value,
      );
      debugPrint(
        '[ACTIVATION] waitForActivationPrompt → completer result=$result',
      );
      return result;
    } catch (e) {
      debugPrint(
        '[ACTIVATION] waitForActivationPrompt → error: $e, needsActivation=${needsActivation.value}',
      );
      return needsActivation.value;
    } finally {
      _activationPromptCompleter = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CONNECT — Establish a BLE connection to the ESP32
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> connect(ScanResult r) async {
    _connectInProgress = true;
    _autoReleaseTimer?.cancel();

    // ── Clean activation state from any previous connection ──
    needsActivation.value = false;
    if (_activationPromptCompleter != null &&
        !_activationPromptCompleter!.isCompleted) {
      _activationPromptCompleter!.complete(false);
    }
    _activationPromptCompleter = null;
    debugPrint('[ACTIVATION] connect() — activation state reset');

    try {
      // Step 1: Disconnect from any previous device first
      if (_device != null || isConnected.value) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Step 2: Stop scanning — Android can't scan and connect at the same time
      _scanSub?.cancel();
      _scanSub = null;
      await FlutterBluePlus.stopScan().catchError((_) {});
      isScanning.value = false;
      await Future.delayed(const Duration(milliseconds: 300));

      status.value = 'Connecting…';
      _device = r.device;

      // Step 3: Start listening for disconnect events
      // We set this up BEFORE connecting so we never miss an early disconnect
      _connSub?.cancel();
      _connSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          // Only handle this if we're NOT in the middle of connecting
          if (isConnected.value && !_connectInProgress) {
            _onUnexpectedDisconnect();
          }
        }
      });

      // Step 4: Actually connect to the device
      await _device!.connect(
        timeout: BleConstants.connectTimeout,
        autoConnect: false,
      );

      // Step 5: Wait for Android's BLE stack to stabilize
      // Without this pause, the next steps can fail on some phones
      await Future.delayed(BleConstants.postConnectDelay);

      // Make sure we're still connected after waiting
      if (!_device!.isConnected) {
        throw 'BLE connection dropped right after connecting';
      }

      // Step 6: Discover what services & characteristics the ESP32 offers
      status.value = 'Discovering services…';
      final services = await _device!.discoverServices();

      // Find our specific service by UUID
      final service = services.firstWhere(
        (s) =>
            s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase(),
      );

      // Step 7: Find the RX, TX, and sensor characteristics inside that service
      status.value = 'Finding characteristics…';
      _rx = null;
      _tx = null;
      _sensor = null;

      for (final c in service.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid == BleConstants.charRxUuid.toLowerCase()) _rx = c;
        if (uuid == BleConstants.charTxUuid.toLowerCase()) _tx = c;
        if (uuid == BleConstants.charSensorUuid.toLowerCase()) _sensor = c;
      }

      if (_rx == null || _tx == null) {
        throw 'RX or TX characteristic not found on the ESP32';
      }

      // Step 8: Subscribe to notifications from the ESP32 (TX channel)
      // Listener MUST be set up BEFORE setNotifyValue so we don't miss
      // fast notifications like NEED_ACTIVATION that the ESP32 sends
      // immediately after the client subscribes.
      status.value = 'Subscribing to notifications…';
      _activationPromptCompleter = Completer<bool>();
      _notifySub?.cancel();
      _notifySub = _tx!.onValueReceived.listen(_onNotification);

      await _tx!.setNotifyValue(true);
      await Future.delayed(BleConstants.notifySetupDelay);

      // Subscribe to sensor characteristic if the ESP32 exposes it
      if (_sensor != null) {
        _sensorSub?.cancel();
        _sensorSub = _sensor!.onValueReceived.listen((bytes) {
          _sensorController.add(bytes);
        });
        await _sensor!.setNotifyValue(true);
      }

      // Extra wait — Android needs time to fully register the notification
      await Future.delayed(const Duration(milliseconds: 300));

      // Final check — make sure we're STILL connected after all that setup
      if (!_device!.isConnected) {
        throw 'BLE connection dropped during setup';
      }

      // Step 9: We're connected and ready!
      isConnected.value = true;
      isAuthenticated.value = true;
      status.value = 'Connected & ready';
      _lastDeviceId = r.device.remoteId.str;
      _intentionalDisconnect = false;

      // Seed signal strength with BLE scan RSSI so UI shows something immediately.
      // Will be overwritten by LoRa RSSI once ESP32 firmware sends STATUS: updates.
      onStatusUpdate?.call(_lastDeviceId!, null, r.rssi);

      // Start the timer to free the gateway if we don't do anything
      _resetAutoReleaseTimer();
      _startHeartbeat();
    } catch (e) {
      status.value = 'Connection error: $e';
      await disconnect();
    } finally {
      _connectInProgress = false;

      // Edge case: if the connection dropped DURING the connect process
      // (the disconnect event was held back by _connectInProgress),
      // handle it now.
      if (_device != null && !_device!.isConnected && isConnected.value) {
        _onUnexpectedDisconnect();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SEND TEXT MESSAGE — Send a string to the ESP32
  // ═══════════════════════════════════════════════════════════════════════

  /// Sends a text message to the ESP32. The ESP32 will reply with MSG_OK.
  /// If the text is "FACTORY_RESET", it routes to the factoryReset method.
  ///
  /// If the connection was auto-released (idle timeout), the message is
  /// queued and a fast reconnection is attempted automatically.
  Future<void> send(String text) async {
    if (text.isEmpty) return;

    // Special case: factory reset command (requires active connection)
    if (text.trim() == BleConstants.cmdFactoryReset) {
      await factoryReset();
      return;
    }

    // If not connected, queue the message and reconnect transparently
    if (_rx == null || !isConnected.value) {
      if (_lastDeviceId != null) {
        await _queueMessage(text);
        return;
      }
      // No saved gateway — message cannot be queued, log it visibly
      messages.add('[System] Gateway bulunamadı — mesaj gönderilemedi: $text');
      debugPrint('[BLE] send() dropped (no lastDeviceId): $text');
      return;
    }

    // Connected — send immediately
    messages.add('ME: $text');
    final response = await _writeAndWaitResponse(text);
    await _resetAutoReleaseTimer();

    if (response == null) {
      messages.add('[System] No response (timeout)');
      return;
    }

    switch (response) {
      case BleConstants.respMsgOk:
        break;
      default:
        final packetError = _packetAckError(response);
        messages.add(
          packetError == null ? 'ESP32: $response' : '[System] $packetError',
        );
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ACTIVATION — Send the activation password to an unprovisioned ESP32
  // ═══════════════════════════════════════════════════════════════════════

  /// Sends the activation password to the ESP32.
  /// Returns a result object with success/failure info.
  Future<ActivationResult> sendActivationPassword(String password) async {
    if (_rx == null || !isConnected.value) {
      return ActivationResult(success: false, message: 'Cihaza bağlı değil');
    }

    _isWaitingForActivationResponse = true;
    try {
      final response = await _writeAndWaitResponse(
        password,
        timeout: BleConstants.activationResponseTimeout,
      );

      if (response == null) {
        return ActivationResult(
          success: false,
          message: 'Cihazdan yanıt alınamadı (zaman aşımı)',
        );
      }

      if (response == BleConstants.respActivated) {
        needsActivation.value = false;
        messages.add('[System] Cihaz aktive edildi — yeniden başlatılıyor');
        return ActivationResult(
          success: true,
          message: 'Cihaz aktive edildi! Yeniden başlatılıyor...',
        );
      }

      if (response == BleConstants.respNvsError) {
        return ActivationResult(
          success: false,
          message: 'Cihaz bellek hatası — tekrar deneyin',
        );
      }

      if (response.startsWith(BleConstants.respWrongPwPrefix)) {
        final remaining = response.substring(
          BleConstants.respWrongPwPrefix.length,
        );
        return ActivationResult(
          success: false,
          message: 'Yanlış şifre — $remaining deneme hakkı kaldı',
          attemptsRemaining: int.tryParse(remaining),
        );
      }

      if (response.startsWith(BleConstants.respLockedPrefix)) {
        final seconds = response.substring(
          BleConstants.respLockedPrefix.length,
        );
        return ActivationResult(
          success: false,
          message: 'Çok fazla hatalı deneme — $seconds saniye bekleyin',
          lockoutSeconds: int.tryParse(seconds),
        );
      }

      return ActivationResult(
        success: false,
        message: 'Beklenmeyen yanıt: $response',
      );
    } catch (e) {
      return ActivationResult(success: false, message: 'Hata: $e');
    } finally {
      _isWaitingForActivationResponse = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FACTORY RESET — Tell the ESP32 to erase its settings and reboot
  // ═══════════════════════════════════════════════════════════════════════

  /// Sends the FACTORY_RESET command to the ESP32.
  /// The ESP32 will erase all saved settings and reboot.
  /// The BLE connection will drop shortly after.
  Future<bool> factoryReset() async {
    if (_rx == null || !isConnected.value) return false;

    try {
      messages.add('ME: ${BleConstants.cmdFactoryReset}');

      final response = await _writeAndWaitResponse(
        BleConstants.cmdFactoryReset,
      );

      if (response == BleConstants.respResetOk) {
        messages.add('[System] Factory reset confirmed — device rebooting');
        isAuthenticated.value = false;
        return true;
      }

      messages.add('[System] Factory reset: unexpected response "$response"');
      return false;
    } catch (e) {
      messages.add('[System] Factory reset error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SEND BINARY DATA — Send raw bytes (e.g. disaster triage bitmask)
  // ═══════════════════════════════════════════════════════════════════════

  /// Sends raw binary bytes to the ESP32 (not text, but actual byte data).
  /// Used for things like the disaster mode triage bitmask.
  /// Returns true if the ESP32 responded with MSG_OK.
  Future<bool> sendHexPayload(Uint8List payload) async {
    if (_rx == null || payload.isEmpty || !isConnected.value) {
      return false;
    }

    // Wait for any in-flight sendHexPayload to finish before proceeding.
    if (_sendLock != null) {
      await _sendLock!.future;
    }

    // Re-check connection after waiting — it may have dropped.
    if (_rx == null || !isConnected.value) return false;

    final lock = Completer<void>();
    _sendLock = lock;

    // Create a new "mailbox" to wait for the ESP32's response
    _responseCompleter = Completer<String>();
    final completer = _responseCompleter!;

    try {
      // Write the binary data to the ESP32
      await _rx!.write(payload.toList(), withoutResponse: false);
      messages.add('ME: [BIN ${payload.length} bytes]');

      // Wait for the ESP32 to respond (up to 5 seconds)
      final response = await completer.future.timeout(
        BleConstants.responseTimeout,
        onTimeout: () => throw TimeoutException('No response'),
      );

      // Activity detected! Keep the connection alive a bit longer
      _resetAutoReleaseTimer();

      // Check if the ESP32 said "OK"
      if (response == BleConstants.respMsgOk) {
        return true;
      }

      final packetError = _packetAckError(response);
      if (packetError != null) {
        messages.add('[System] $packetError');
        return false;
      }

      messages.add('ESP32: $response');
      return false;
    } on TimeoutException {
      messages.add('[System] Binary payload: no response (timeout)');
      return false;
    } catch (e) {
      messages.add('[System] Binary payload error: $e');
      return false;
    } finally {
      // Clean up the completer so it doesn't interfere with future sends
      if (_responseCompleter == completer) {
        _responseCompleter = null;
      }
      // Release the lock so the next queued sendHexPayload can proceed
      if (_sendLock == lock) {
        _sendLock = null;
      }
      lock.complete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DISCONNECT — Close the BLE connection
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> disconnect() async {
    // Mark as intentional so heartbeat auto-reconnect doesn't fire
    _intentionalDisconnect = true;

    // Tell the timers to stop
    _autoReleaseTimer?.cancel();
    _autoReleaseTimer = null;
    _stopHeartbeat();

    // Stop all listeners first
    _cancelSubscriptions();

    // Tell the BLE device to disconnect
    try {
      await _device?.disconnect();
    } catch (_) {}

    // Clear everything
    _device = null;
    _rx = null;
    _tx = null;

    isConnected.value = false;
    isAuthenticated.value = false;
    needsActivation.value = false;
    if (_activationPromptCompleter != null &&
        !_activationPromptCompleter!.isCompleted) {
      _activationPromptCompleter!.complete(false);
    }
    _activationPromptCompleter = null;
    status.value = 'Disconnected';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS — Internal methods (not called from the UI)
  // ═══════════════════════════════════════════════════════════════════════

  /// Writes a text string to the ESP32 and waits for the response.
  ///
  /// How it works:
  ///   1. Creates a "completer" (a one-shot mailbox)
  ///   2. Writes the text to the ESP32's RX characteristic
  ///   3. Waits up to 5 seconds for a notification on TX
  ///   4. Returns the response string, or null if it timed out
  Future<String?> _writeAndWaitResponse(
    String text, {
    Duration? timeout,
  }) async {
    if (_rx == null) return null;

    if (_sendLock != null) {
      await _sendLock!.future;
    }

    if (_rx == null || !isConnected.value) return null;

    final lock = Completer<void>();
    _sendLock = lock;

    // Create the "mailbox" BEFORE writing, so we don't miss fast responses
    _responseCompleter = Completer<String>();
    final completer = _responseCompleter!;
    final waitTimeout = timeout ?? BleConstants.responseTimeout;

    try {
      // Write the text as UTF-8 bytes
      await _rx!.write(utf8.encode(text), withoutResponse: false);

      // Wait for the ESP32's response
      final response = await completer.future.timeout(
        waitTimeout,
        onTimeout: () => throw TimeoutException('No ESP32 response'),
      );
      return response;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    } finally {
      // Clean up
      if (_responseCompleter == completer) {
        _responseCompleter = null;
      }
      if (_sendLock == lock) {
        _sendLock = null;
      }
      lock.complete();
    }
  }

  /// Called automatically whenever the ESP32 sends us a notification.
  /// This is how we receive responses after writing.
  void _onNotification(List<int> data) {
    final msg = utf8
        .decode(data, allowMalformed: true)
        .replaceAll('\x00', '')
        .trim();
    if (msg.isEmpty) return;

    debugPrint('[NOTIFY] Received: "$msg" (${data.length} bytes, raw=$data)');

    // Unsolicited activation prompt from ESP32 — set flag and complete waiter
    if (msg == BleConstants.respNeedActivation) {
      debugPrint(
        '[ACTIVATION] NEED_ACTIVATION received — setting flag & completing completer',
      );
      needsActivation.value = true;
      if (_activationPromptCompleter != null &&
          !_activationPromptCompleter!.isCompleted) {
        _activationPromptCompleter!.complete(true);
        debugPrint('[ACTIVATION] Completer completed with TRUE');
      } else {
        debugPrint(
          '[ACTIVATION] Completer was ${_activationPromptCompleter == null ? "NULL" : "already completed"}',
        );
      }
      messages.add('[System] Cihaz aktivasyon bekliyor');
      return;
    }

    // Unsolicited STATUS update — parse and fire callback, no completer to complete
    if (msg.startsWith(BleConstants.respStatusPrefix)) {
      _tryParseStatus(msg);
      return;
    }

    // MSG_OK with status suffix — extract status, deliver clean 'MSG_OK' to waiters
    final String deliverMsg;
    if (msg.startsWith('${BleConstants.respMsgOk}:')) {
      _tryParseStatus(msg);
      deliverMsg = BleConstants.respMsgOk;
    } else {
      deliverMsg = msg;
    }

    // If we're waiting for a response (completer is active), deliver it
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.complete(deliverMsg);
    } else {
      messages.add('ESP32: $deliverMsg');
    }
  }

  /// Called when the BLE connection drops unexpectedly (not by us).
  void _onUnexpectedDisconnect() {
    _autoReleaseTimer?.cancel();
    _autoReleaseTimer = null;
    _stopHeartbeat();
    _cancelSubscriptions(delayResponseCancel: _isWaitingForActivationResponse);

    _device = null;
    _rx = null;
    _tx = null;

    isConnected.value = false;
    isAuthenticated.value = false;
    needsActivation.value = false;
    if (_activationPromptCompleter != null &&
        !_activationPromptCompleter!.isCompleted) {
      _activationPromptCompleter!.complete(false);
    }
    _activationPromptCompleter = null;
    status.value = 'Disconnected (unexpected)';
  }

  /// Stops all listeners and clears any pending response.
  /// [delayResponseCancel]: when true (activation flow), keep _notifySub active
  /// so ACTIVATED can arrive; delay 2s before cancelling.
  void _cancelSubscriptions({bool delayResponseCancel = false}) {
    if (!delayResponseCancel) {
      _notifySub?.cancel();
      _notifySub = null;
    }

    _sensorSub?.cancel();
    _sensorSub = null;
    _sensor = null;

    _connSub?.cancel();
    _connSub = null;

    _scanSub?.cancel();
    _scanSub = null;

    _autoReleaseTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      if (delayResponseCancel) {
        _activationResponseCancelTimer?.cancel();
        _activationResponseCancelTimer = Timer(
          const Duration(milliseconds: 2000),
          () {
            _notifySub?.cancel();
            _notifySub = null;
            if (_responseCompleter != null &&
                !_responseCompleter!.isCompleted) {
              _responseCompleter!.completeError('Cancelled');
            }
            _responseCompleter = null;
            _activationResponseCancelTimer = null;
          },
        );
      } else {
        _responseCompleter!.completeError('Cancelled');
        _responseCompleter = null;
      }
    } else {
      _responseCompleter = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  QUEUE & AUTO-RECONNECT — Send messages even after idle disconnect
  // ═══════════════════════════════════════════════════════════════════════

  /// Reconnects to the last-known gateway and sends every queued message.
  /// Retries up to [BleConstants.maxQueueRetries] times with randomized
  /// exponential backoff so that multiple phones don't collide.
  Future<void> _reconnectAndDrainQueue() async {
    if (_isDrainingQueue) return;
    _isDrainingQueue = true;

    final rng = Random();

    try {
      final deviceId = _lastDeviceId;
      if (deviceId == null || _messageQueue.isEmpty) return;

      for (int attempt = 0; attempt < BleConstants.maxQueueRetries; attempt++) {
        if (isConnected.value) break;

        if (attempt > 0) {
          // Exponential backoff capped at maxRetryBackoff
          final baseMs =
              BleConstants.initialRetryDelay.inMilliseconds *
              (1 << (attempt - 1)); // 2s, 4s, 8s, …
          final cappedMs = baseMs.clamp(
            0,
            BleConstants.maxRetryBackoff.inMilliseconds,
          );
          final jitterMs = rng.nextInt(1500);
          final delay = Duration(milliseconds: cappedMs + jitterMs);
          status.value =
              'Gateway busy — retry ${attempt + 1}/${BleConstants.maxQueueRetries}…';
          await Future.delayed(delay);
        } else {
          // First attempt — short pause so the ESP32 finishes its
          // current client before we knock on the door.
          status.value = 'Reconnecting…';
          await Future.delayed(BleConstants.initialRetryDelay);
        }

        // Fast path — direct connect without scanning
        if (!isConnected.value) {
          await _directReconnect(deviceId);
        }

        // Slow fallback — targeted scan + connect
        if (!isConnected.value) {
          await connectById(deviceId);
        }
      }

      if (!isConnected.value) {
        messages.add(
          '[System] Gateway unreachable after '
          '${BleConstants.maxQueueRetries} attempts — '
          '${_messageQueue.length} message(s) saved',
        );
        _persistQueue();
        return;
      }

      // Drain the queue — in disaster mode send at most
      // maxMessagesPerDrain messages, then release for others.
      int sent = 0;
      while (_messageQueue.isNotEmpty && isConnected.value) {
        if (disasterMode && sent >= BleConstants.maxMessagesPerDrain) {
          break; // let others take a turn
        }

        final msg = _messageQueue.removeAt(0);
        _persistQueue();
        final response = await _writeAndWaitResponse(msg);
        sent++;

        if (response == null) {
          // Write timed out — restore message at front of queue so it
          // is the first thing retried on the next connection.
          _messageQueue.insert(0, msg);
          _persistQueue();
          messages.add(
            '[System] Gönderim zaman aşımı — mesaj yeniden kuyruğa alındı',
          );
          break; // Stop this drain cycle; reconnect will retry
        } else if (response == BleConstants.respMsgOk) {
          // success — already removed from queue
        } else {
          final packetError = _packetAckError(response);
          if (packetError != null) {
            // Packet was malformed/oversized — not a transient error, don't retry
            messages.add('[System] $packetError');
            debugPrint('[Queue] Message rejected ($response), dropping: $msg');
          } else {
            messages.add('ESP32: $response');
          }
        }
      }

      // Release the gateway so the next person can connect
      await _resetAutoReleaseTimer();
    } catch (e) {
      messages.add('[System] Queue send error: $e');
    } finally {
      _isDrainingQueue = false;

      // Apply deferred disaster-mode deactivation (set when screen disposed
      // mid-drain so we didn't cut off the auto-release behaviour).
      if (_pendingDisasterModeOff) {
        disasterMode = false;
        _pendingDisasterModeOff = false;
      }

      // If new messages were added while we were draining, start again
      // (with cooldown in disaster mode so we don't hog the gateway)
      if (_messageQueue.isNotEmpty && _lastDeviceId != null) {
        if (disasterMode) {
          Future.delayed(BleConstants.drainCooldown, () {
            _reconnectAndDrainQueue();
          });
        } else {
          _reconnectAndDrainQueue();
        }
      }
    }
  }

  /// Fast reconnect using [BluetoothDevice.fromId] — skips scanning entirely.
  /// Used when the gateway was connected seconds ago and is still in range.
  Future<void> _directReconnect(String deviceId) async {
    _connectInProgress = true;

    try {
      if (_device != null || isConnected.value) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await FlutterBluePlus.stopScan().catchError((_) {});
      isScanning.value = false;

      status.value = 'Quick reconnect…';
      _device = BluetoothDevice.fromId(deviceId);

      _connSub?.cancel();
      _connSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (isConnected.value && !_connectInProgress) {
            _onUnexpectedDisconnect();
          }
        }
      });

      await _device!.connect(
        timeout: const Duration(seconds: 5),
        autoConnect: false,
      );

      await Future.delayed(BleConstants.postConnectDelay);
      if (!_device!.isConnected) throw 'Connection dropped';

      // Use cached services when available (faster reconnect)
      status.value = 'Discovering services…';
      final services = await _device!.discoverServices(timeout: 5);

      final service = services.firstWhere(
        (s) =>
            s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase(),
      );

      _rx = null;
      _tx = null;
      _sensor = null;
      for (final c in service.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid == BleConstants.charRxUuid.toLowerCase()) _rx = c;
        if (uuid == BleConstants.charTxUuid.toLowerCase()) _tx = c;
        if (uuid == BleConstants.charSensorUuid.toLowerCase()) _sensor = c;
      }

      if (_rx == null || _tx == null) throw 'Characteristics not found';

      // Set up activation prompt completer (same as connect())
      _activationPromptCompleter = Completer<bool>();

      _notifySub?.cancel();
      _notifySub = _tx!.onValueReceived.listen(_onNotification);

      await _tx!.setNotifyValue(true);
      await Future.delayed(BleConstants.notifySetupDelay);

      // Re-subscribe to sensor characteristic if available
      if (_sensor != null) {
        _sensorSub?.cancel();
        _sensorSub = _sensor!.onValueReceived.listen((bytes) {
          _sensorController.add(bytes);
        });
        await _sensor!.setNotifyValue(true);
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (!_device!.isConnected) throw 'Connection dropped during setup';

      _lastDeviceId = deviceId;
      isConnected.value = true;
      isAuthenticated.value = true;
      status.value = 'Reconnected';
      _intentionalDisconnect = false;
      _startHeartbeat();
    } catch (e) {
      await disconnect();
    } finally {
      _connectInProgress = false;
      if (_device != null && !_device!.isConnected && isConnected.value) {
        _onUnexpectedDisconnect();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PERSISTENT QUEUE — Survive app restarts during earthquakes
  // ═══════════════════════════════════════════════════════════════════════

  static const String _queueStorageKey = 'ble_pending_messages';
  static const String _lastDeviceStorageKey = 'ble_last_device_id';

  /// Save the current message queue to SharedPreferences.
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_queueStorageKey, List.from(_messageQueue));
      if (_lastDeviceId != null) {
        await prefs.setString(_lastDeviceStorageKey, _lastDeviceId!);
      }
    } catch (_) {}
  }

  /// Load any pending messages that were saved before the app closed.
  /// If there are pending messages and a known device, start draining.
  Future<void> loadPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _lastDeviceId ??= prefs.getString(_lastDeviceStorageKey);

      final pending = prefs.getStringList(_queueStorageKey);
      if (pending != null && pending.isNotEmpty) {
        _messageQueue.addAll(pending);
        messages.add('[System] ${pending.length} pending message(s) loaded');

        if (_lastDeviceId != null) {
          _reconnectAndDrainQueue();
        }
      }
    } catch (_) {}
  }

  /// Clear the pending queue and any stored device reference for a gateway
  /// that is being removed from the app. Prevents stale reconnect attempts
  /// on next startup.
  Future<void> clearQueueForGateway(String deviceId) async {
    if (_lastDeviceId == deviceId) {
      _lastDeviceId = null;
    }
    _messageQueue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueStorageKey);
    await prefs.remove(_lastDeviceStorageKey);
  }

  /// ── Shared Gateway Help: The Auto-Release Timer ──────────────────────
  ///
  /// Frees the gateway for other users after sending.
  ///
  /// - **Disaster mode**: disconnects immediately (no timer) so the next
  ///   survivor can connect as fast as possible. This is the "Shared Mesh"
  ///   logic that lets 10+ people take turns on one ESP32.
  /// - **Normal mode**: no auto-disconnect. The user stays connected until
  ///   they leave the screen or the connection drops naturally.
  Future<void> _resetAutoReleaseTimer() async {
    _autoReleaseTimer?.cancel();
    _autoReleaseTimer = null;

    if (disasterMode && isConnected.value) {
      await disconnect();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DEVICE COUNT — Query how many mobile devices are registered on the ESP32
  // ═══════════════════════════════════════════════════════════════════════

  /// Safely deactivates disaster mode.
  /// If a drain is in progress, defers the flag flip until the drain
  /// finishes so the auto-release-after-send behaviour isn't cut off.
  void deactivateDisasterMode() {
    if (_isDrainingQueue) {
      _pendingDisasterModeOff = true;
    } else {
      disasterMode = false;
    }
  }

  /// Sends a binary payload immediately when connected, or encodes it as a
  /// hex string and pushes it through the text queue when disconnected.
  ///
  /// This gives the triage payload the same persistent, retrying delivery
  /// guarantee that text SOS messages already have.
  /// The ESP32 receives `BIN:<hex>` as an unknown command and replies MSG_OK,
  /// which is sufficient for the current protocol version.
  Future<void> sendBinaryQueued(Uint8List payload) async {
    if (payload.isEmpty) return;
    if (_lastDeviceId == null) {
      throw StateError('No gateway available — set lastDeviceId first');
    }

    // If connected, try raw binary first (fastest path)
    var alreadyLogged = false;
    if (isConnected.value && _rx != null) {
      final success = await sendHexPayload(payload);
      if (success) return;
      // Direct send failed — fall through to queue; sendHexPayload already logged
      alreadyLogged = true;
    }

    // Encode as hex and queue with full retry/persistence support.
    // This path also handles failed direct binary sends; avoid send(encoded)
    // here because connected sends are immediate and are not persisted.
    final hex = payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final encoded = 'BIN:$hex';

    // Warn when the encoded string exceeds the MTU — ESP32 will reject it
    // with MSG_BAD_LEN, which is now handled gracefully in the drain loop.
    if (encoded.length > BleConstants.maxMtu) {
      debugPrint(
        '[BLE] Warning: encoded payload ${encoded.length} bytes exceeds MTU ${BleConstants.maxMtu} — ESP32 will reject with MSG_BAD_LEN',
      );
    }

    await _queueMessage(encoded, silent: alreadyLogged);
  }

  /// Registers this phone with the ESP32 using a stable app-provided ID.
  /// The ESP32 stores it in NVS — idempotent, so re-sending same ID is a no-op.
  /// Returns true if the ESP32 confirmed with MSG_OK.
  Future<bool> registerDevice(String stableId) async {
    if (_rx == null || !isConnected.value) return false;
    final response = await _writeAndWaitResponse(
      '${BleConstants.cmdRegisterPrefix}$stableId',
    );
    return response == BleConstants.respMsgOk;
  }

  /// Sends GET_DEVICE_COUNT to the ESP32 and returns the parsed count.
  /// Returns null if not connected or the response is unexpected.
  Future<int?> queryDeviceCount() async {
    if (_rx == null || !isConnected.value) return null;

    final response = await _writeAndWaitResponse(
      BleConstants.cmdGetDeviceCount,
    );
    if (response == null) return null;

    if (response.startsWith(BleConstants.respDeviceCountPrefix)) {
      return int.tryParse(
        response.substring(BleConstants.respDeviceCountPrefix.length),
      );
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HEARTBEAT — Detect silent BLE drops and reconnect automatically
  // ═══════════════════════════════════════════════════════════════════════

  /// Starts a periodic PING→PONG probe.
  /// Skips ticks when a queue drain is in progress to avoid response collisions.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatFailCount = 0;
    _pingInFlight = false;

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      // Not connected — stop the timer, nothing to probe.
      if (!isConnected.value) {
        _stopHeartbeat();
        return;
      }

      // Skip this tick — a drain or previous ping is still running.
      if (_isDrainingQueue || _pingInFlight) return;

      _pingInFlight = true;
      try {
        final response = await _writeAndWaitResponse(
          'PING',
          timeout: _pingTimeout,
        );
        if (response == 'PONG') {
          _heartbeatFailCount = 0;
          debugPrint('[Heartbeat] PONG received — connection healthy');
          // Read BLE RSSI on every successful heartbeat so signal stays live.
          // Overwritten by LoRa RSSI once ESP32 firmware sends STATUS: updates.
          try {
            if (_device != null && _lastDeviceId != null) {
              final rssi = await _device!.readRssi();
              onStatusUpdate?.call(_lastDeviceId!, null, rssi);
            }
          } catch (_) {}
        } else {
          _heartbeatFailCount++;
          debugPrint(
            '[Heartbeat] No PONG (got: $response) — fail $_heartbeatFailCount/$_maxHeartbeatFails',
          );
          if (_heartbeatFailCount >= _maxHeartbeatFails) {
            _stopHeartbeat();
            _onUnexpectedDisconnect();
            if (!_intentionalDisconnect && _lastDeviceId != null) {
              _autoReconnectAfterHeartbeatFailure();
            }
          }
        }
      } finally {
        _pingInFlight = false;
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatFailCount = 0;
    _pingInFlight = false;
  }

  /// Silently tries to reconnect after heartbeat detects a dead connection.
  /// Uses exponential backoff (1s → 2s → 4s → … → 30s max) with jitter.
  /// Stops if the user intentionally disconnects or reconnect succeeds.
  Future<void> _autoReconnectAfterHeartbeatFailure() async {
    if (_heartbeatAutoReconnecting) return;
    _heartbeatAutoReconnecting = true;

    final rng = Random();
    final deviceId = _lastDeviceId!;

    try {
      for (int attempt = 0; attempt < _maxAutoReconnectAttempts; attempt++) {
        if (isConnected.value || _intentionalDisconnect) break;

        // Backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped) + jitter
        final baseMs = attempt == 0
            ? 1000
            : (2000 * (1 << (attempt - 1))).clamp(0, 30000);
        final jitterMs = rng.nextInt(1000);
        await Future.delayed(Duration(milliseconds: baseMs + jitterMs));

        if (_intentionalDisconnect) break;

        status.value =
            'Otomatik yeniden bağlanılıyor (${attempt + 1}/$_maxAutoReconnectAttempts)…';
        debugPrint(
          '[Heartbeat] Auto-reconnect attempt ${attempt + 1}/$_maxAutoReconnectAttempts',
        );

        // Fast path first, then full scan fallback
        await _directReconnect(deviceId);
        if (!isConnected.value) await connectById(deviceId);
      }

      if (isConnected.value) {
        debugPrint('[Heartbeat] Auto-reconnect succeeded');
        _startHeartbeat();
        if (_messageQueue.isNotEmpty) _reconnectAndDrainQueue();
      } else if (!_intentionalDisconnect) {
        status.value = 'Bağlantı kurulamadı — lütfen manuel bağlanın';
        debugPrint('[Heartbeat] Auto-reconnect exhausted all attempts');
      }
    } finally {
      _heartbeatAutoReconnecting = false;
    }
  }

  /// Called when this controller is destroyed (app closing, etc.)
  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}

/// Result of an activation attempt — returned by [BleConnection.sendActivationPassword].
class ActivationResult {
  final bool success;
  final String message;
  final int? attemptsRemaining;
  final int? lockoutSeconds;

  ActivationResult({
    required this.success,
    required this.message,
    this.attemptsRemaining,
    this.lockoutSeconds,
  });
}
