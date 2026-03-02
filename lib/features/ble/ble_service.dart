import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'BLEConnectionManager.dart';
import '../../services/gateway_service.dart';

/// The main BLE service — a singleton that all pages share.
///
/// What is a singleton?
///   Every time you write `BleService()`, you get the SAME instance.
///   This means all pages in the app share one BLE connection.
///
/// Why ValueNotifiers?
///   Some pages use GetX (Obx), others use plain Flutter (ValueListenableBuilder).
///   This class provides BOTH:
///     • bleConnection — for GetX reactive pages
///     • ValueNotifier getters — for plain Flutter pages
class BleService {

  // ── Singleton pattern ───────────────────────────────────────────
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  // The actual BLE connection manager that does all the work
  final BleConnection _bleConnection = BleConnection();

  // These ValueNotifiers mirror the GetX observables so plain
  // Flutter widgets can also listen for changes
  late final ValueNotifier<bool> _isConnected;
  late final ValueNotifier<bool> _isScanning;
  late final ValueNotifier<bool> _isAuthenticated;
  late final ValueNotifier<bool> _needsActivation;
  late final ValueNotifier<String> _status;
  late final ValueNotifier<List<ScanResult>> _results;
  late final ValueNotifier<List<String>> _messages;

  BleService._internal() {
    // Initialize ValueNotifiers with current values
    _isConnected = ValueNotifier(_bleConnection.isConnected.value);
    _isScanning = ValueNotifier(_bleConnection.isScanning.value);
    _isAuthenticated = ValueNotifier(_bleConnection.isAuthenticated.value);
    _needsActivation = ValueNotifier(_bleConnection.needsActivation.value);
    _status = ValueNotifier(_bleConnection.status.value);
    _results = ValueNotifier(_bleConnection.results.toList());
    _messages = ValueNotifier(_bleConnection.messages.toList());

    // Keep ValueNotifiers in sync with the GetX observables
    ever(_bleConnection.isConnected, (v) => _isConnected.value = v);
    ever(_bleConnection.isScanning, (v) => _isScanning.value = v);
    ever(_bleConnection.isAuthenticated, (v) => _isAuthenticated.value = v);
    ever(_bleConnection.needsActivation, (v) => _needsActivation.value = v);
    ever(_bleConnection.status, (v) => _status.value = v);

    _bleConnection.results.listen((value) {
      _results.value = List<ScanResult>.from(value);
    });

    ever(
      _bleConnection.messages,
      (value) => _messages.value = value.toList(),
    );
  }

  // ── Getters for plain Flutter widgets ───────────────────────────
  // Use these with ValueListenableBuilder in widgets that don't use GetX

  ValueNotifier<bool> get isConnected => _isConnected;
  ValueNotifier<bool> get isScanning => _isScanning;
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get needsActivation => _needsActivation;
  ValueNotifier<String> get status => _status;
  ValueNotifier<List<ScanResult>> get results => _results;
  ValueNotifier<List<String>> get messages => _messages;

  /// Direct access to the BLE connection manager.
  /// Use this in GetX pages (with Obx) for reactive state.
  BleConnection get bleConnection => _bleConnection;

  // ── Scan ────────────────────────────────────────────────────────

  /// Start scanning for nearby ESP32 devices
  Future<void> scanDevices() async {
    await _bleConnection.scanDevices();
  }

  // ── Connect / Disconnect ────────────────────────────────────────

  /// Connect to a scanned BLE device
  Future<void> connect(ScanResult result) async {
    await _bleConnection.connect(result);
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    await _bleConnection.disconnect();
  }

  /// Connect directly to a known device by its ID (no scan needed).
  /// Used for REQ-GW-05 automatic reconnection.
  Future<void> connectById(String deviceId) async {
    await _bleConnection.connectById(deviceId);
  }

  /// REQ-GW-05: Attempt to reconnect to a specific saved device.
  ///
  /// - Waits up to 5 seconds for Bluetooth to become available.
  /// - Returns true if reconnection succeeds.
  Future<bool> autoReconnect(String deviceId) async {
    if (deviceId.isEmpty) return false;

    try {
      // Step 1: Wait for Bluetooth to be ON
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          // Give it a few seconds to turn on
          await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          return false; // Bluetooth still off
        }
      }

      // Step 2: Attempt targeted reconnection
      await connectById(deviceId);
      return isConnected.value;
    } catch (_) {
      return false;
    }
  }

  // ── Messaging ───────────────────────────────────────────────────

  /// Send a text message to the ESP32
  Future<void> sendMessage(String text) async {
    await _bleConnection.send(text);
  }

  /// Send an SOS message via BLE.
  ///
  /// Strategy (most reliable → least reliable):
  ///   1. Already connected → send immediately
  ///   2. Saved gateway exists → use queue system (auto-reconnect + retry)
  ///   3. No saved gateway → scan, connect to nearest, then send
  ///
  /// The queue system ensures the message is persisted and retried even
  /// if the first attempt fails, so messages are never silently lost.
  Future<void> sendSosMessage(String message) async {
    final sosText = 'SOS: $message';

    // Path 1: Already connected — send right away
    if (isConnected.value) {
      await sendMessage(sosText);
      return;
    }

    // Path 2: We know a gateway — let the queue handle reconnect + retry
    final savedGateways = GatewayService().gateways.value;
    if (savedGateways.isNotEmpty) {
      // Ensure _lastDeviceId is set so the queue can reconnect
      _bleConnection.setLastDeviceId(savedGateways.first.id);
      await sendMessage(sosText); // queued + auto-reconnect
      return;
    }

    // Path 3: No saved gateway — scan and connect to the nearest one
    await scanDevices();

    // Wait for scan to finish (event-driven, not fixed delay)
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      return _bleConnection.isScanning.value;
    }).timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );

    if (results.value.isEmpty) {
      throw Exception('No BLE devices found for SOS');
    }

    await connect(results.value.first);

    if (isConnected.value) {
      await sendMessage(sosText);
    } else {
      throw Exception('Could not connect for SOS');
    }
  }

  // ── Activation ──────────────────────────────────────────────────

  /// Send the activation password to the ESP32.
  /// Returns an [ActivationResult] with success/failure info.
  Future<ActivationResult> sendActivationPassword(String password) async {
    return _bleConnection.sendActivationPassword(password);
  }

  /// Waits for NEED_ACTIVATION after connect. Call right after connect().
  Future<bool> waitForActivationPrompt({Duration timeout = const Duration(seconds: 2)}) async {
    return _bleConnection.waitForActivationPrompt(timeout: timeout);
  }

  // ── Binary Data ─────────────────────────────────────────────────

  /// Send raw bytes to the ESP32 (e.g. disaster triage bitmask).
  /// Returns true if the ESP32 confirmed with MSG_OK.
  Future<bool> sendHexPayload(Uint8List payload) async {
    return _bleConnection.sendHexPayload(payload);
  }

  // ── Factory Reset ───────────────────────────────────────────────

  /// Tell the ESP32 to erase all settings and reboot.
  /// Returns true if the ESP32 confirmed with RESET_OK.
  Future<bool> factoryReset() async {
    return _bleConnection.factoryReset();
  }

  // ── Persistent Queue ────────────────────────────────────────────

  /// Load pending messages from disk and start draining if any exist.
  /// Safe to call on every app start — no-op if the queue is empty.
  Future<void> loadAndDrainPendingQueue() async {
    await _bleConnection.loadPendingQueue();
  }

  // ── Lifecycle ───────────────────────────────────────────────────

  /// This is empty on purpose — the singleton lives forever.
  /// Call disconnect() if you need to drop the BLE link.
  void dispose() {
    // Intentionally empty — singleton never dies
  }
}
