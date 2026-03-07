import 'package:shared_preferences/shared_preferences.dart';

class DevicePasswordService {
  static final DevicePasswordService _instance = DevicePasswordService._internal();
  factory DevicePasswordService() => _instance;
  DevicePasswordService._internal();

  static const String _passwordPrefix = 'device_password_';
  static const String _serviceUuidPrefix = 'device_service_uuid_';
  static const String _charRxUuidPrefix = 'device_char_rx_uuid_';
  static const String _charTxUuidPrefix = 'device_char_tx_uuid_';
  static const String _lastConnectedDeviceKey = 'last_connected_device_id';

  // Save password for a device
  Future<void> savePassword(String deviceId, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_passwordPrefix$deviceId', password);
  }

  // Get password for a device
  Future<String?> getPassword(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_passwordPrefix$deviceId');
  }

  // Check if device has a saved password
  Future<bool> hasPassword(String deviceId) async {
    final password = await getPassword(deviceId);
    return password != null && password.isNotEmpty;
  }

  // Save service UUID for a device
  Future<void> saveServiceUuid(String deviceId, String serviceUuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_serviceUuidPrefix$deviceId', serviceUuid);
  }

  // Get service UUID for a device
  Future<String?> getServiceUuid(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_serviceUuidPrefix$deviceId');
  }

  // Save characteristic UUIDs for a device
  Future<void> saveCharacteristicUuids(
    String deviceId,
    String charRxUuid,
    String charTxUuid,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_charRxUuidPrefix$deviceId', charRxUuid);
    await prefs.setString('$_charTxUuidPrefix$deviceId', charTxUuid);
  }

  // Get characteristic UUIDs for a device
  Future<Map<String, String?>> getCharacteristicUuids(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'rx': prefs.getString('$_charRxUuidPrefix$deviceId'),
      'tx': prefs.getString('$_charTxUuidPrefix$deviceId'),
    };
  }

  // Remove all data for a device
  Future<void> removeDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_passwordPrefix$deviceId');
    await prefs.remove('$_serviceUuidPrefix$deviceId');
    await prefs.remove('$_charRxUuidPrefix$deviceId');
    await prefs.remove('$_charTxUuidPrefix$deviceId');
  }

  // ── REQ-GW-05: Last connected device for auto-reconnect ──────

  /// Save the device ID of the last successfully connected gateway.
  Future<void> saveLastConnectedDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConnectedDeviceKey, deviceId);
  }

  /// Get the last successfully connected device ID, or null if none.
  Future<String?> getLastConnectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectedDeviceKey);
  }

  /// Clear the saved last-connected device ID.
  Future<void> clearLastConnectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastConnectedDeviceKey);
  }

  // ── Activation state ─────────────────────────────────────────────

  static const String _activatedPrefix = 'device_activated_';

  /// Returns true if this device has been successfully activated via this app.
  Future<bool> isActivated(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_activatedPrefix$deviceId') ?? false;
  }

  /// Mark this device as successfully activated.
  Future<void> markActivated(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_activatedPrefix$deviceId', true);
  }

  /// Clear the activated flag (e.g. after a factory reset).
  Future<void> clearActivated(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_activatedPrefix$deviceId');
  }
}

