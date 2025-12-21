import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_constants.dart';

class BleService {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ---------- STATE ----------
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> status = ValueNotifier<String>('Idle');

  final ValueNotifier<List<ScanResult>> results = ValueNotifier<List<ScanResult>>([]);
  final ValueNotifier<List<String>> messages = ValueNotifier<List<String>>([]);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx; // WRITE
  BluetoothCharacteristic? _tx; // NOTIFY

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  // ---------- SCAN ----------
  Future<void> scanDevices() async {
    if (isScanning.value) return;

    try {
      status.value = 'Checking Bluetooth...';

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        status.value = 'Bluetooth is OFF (turn it ON)';
        return;
      }

      status.value = 'Requesting permissions...';

      final scanStatus = await Permission.bluetoothScan.request();
      final connStatus = await Permission.bluetoothConnect.request();
      final locStatus = await Permission.locationWhenInUse.request();

      status.value =
          'Perms scan=$scanStatus connect=$connStatus loc=$locStatus';

      if (!scanStatus.isGranted || !connStatus.isGranted || !locStatus.isGranted) {
        status.value = 'Permission denied. Enable in Settings > Apps > your app';
        return;
      }

      // Stop any existing scan first
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 100));

      results.value = [];
      isScanning.value = true;
      status.value = 'Scanning...';

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        final map = <String, ScanResult>{};
        for (final r in list) {
          map[r.device.remoteId.str] = r;
        }
        results.value = map.values.toList();
        status.value = 'Found: ${results.value.length} devices';
      });

      // Start scan filtered by service UUID (only shows ESP32 devices)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid(BleConstants.serviceUuid)],
        androidUsesFineLocation: false,
      );

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 15));

      isScanning.value = false;
      status.value = 'Scan finished (${results.value.length} devices)';
    } catch (e) {
      isScanning.value = false;
      status.value = 'Scan error: $e';
      await FlutterBluePlus.stopScan();
    }
  }

  // ---------- CONNECT ----------
  Future<void> connect(ScanResult r) async {
    try {
      status.value = 'Connecting...';
      _device = r.device;

      // Connect first
      await _device!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Set up connection state listener AFTER connection is established
      _connSub?.cancel();
      _connSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && isConnected.value) {
          // Only handle disconnect if we were actually connected
          disconnect();
        }
      });

      status.value = 'Requesting MTU...';
      // Try MTU request, but don't fail if it doesn't work
      try {
        await _device!.requestMtu(BleConstants.maxMtu);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // MTU request failed, continue anyway
        status.value = 'MTU request failed, continuing...';
      }

      status.value = 'Discovering services...';
      final services = await _device!.discoverServices();

      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase(),
      );

      status.value = 'Finding characteristics...';
      for (final c in service.characteristics) {
        if (c.uuid.toString().toLowerCase() ==
            BleConstants.charRxUuid.toLowerCase()) {
          _rx = c;
        }
        if (c.uuid.toString().toLowerCase() ==
            BleConstants.charTxUuid.toLowerCase()) {
          _tx = c;
        }
      }

      if (_rx == null || _tx == null) {
        throw 'RX / TX characteristic not found';
      }

      status.value = 'Enabling notifications...';
      await _tx!.setNotifyValue(true);
      await Future.delayed(const Duration(milliseconds: 200));

      _notifySub?.cancel();
      _notifySub = _tx!.onValueReceived.listen((data) {
        final msg = utf8.decode(data, allowMalformed: true);
        messages.value = [...messages.value, 'ESP32: $msg'];
      });

      isConnected.value = true;
      status.value = 'Connected';
    } catch (e) {
      status.value = 'Connect error: $e';
      await disconnect();
    }
  }

  // ---------- SEND ----------
  Future<void> send(String text) async {
    if (_rx == null || text.isEmpty) return;

    await _rx!.write(
      utf8.encode(text),
      withoutResponse: _rx!.properties.writeWithoutResponse,
    );

    messages.value = [...messages.value, 'ME: $text'];
  }

  // ---------- SEND SOS MESSAGE ----------
  Future<void> sendSosMessage(String message) async {
    await send(message);
  }

  // ---------- DISCONNECT ----------
  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _rx = null;
    _tx = null;

    isConnected.value = false;
    status.value = 'Disconnected';
  }

  void dispose() {
    disconnect();
    isScanning.dispose();
    isConnected.dispose();
    status.dispose();
    results.dispose();
    messages.dispose();
  }
}

