import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway.dart';
import '../models/household_profile.dart';
import '../features/ble/ble_service.dart';
import '../core/api/disaster_repository.dart';
import '../core/api/gateway_repository.dart';
import 'device_password_service.dart';

class GatewayService {
  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  final ValueNotifier<List<Gateway>> gateways = ValueNotifier<List<Gateway>>([]);

  /// Set to a gateway ID when a periodic location check is due after connect.
  /// DashboardPage listens to this and performs the GPS comparison + prompt.
  final ValueNotifier<String?> locationCheckNeeded = ValueNotifier<String?>(null);

  final Map<String, HouseholdProfile> _householdProfiles = {};
  final BleService _bleService = BleService();

  // Re-check location every 90 days (~3 months)
  static const int _locationCheckIntervalDays = 90;

  static const String _gatewaysStorageKey = 'persisted_gateways';
  static const String _householdProfilesStorageKey = 'persisted_household_profiles';
  bool _initialized = false;

  /// Syncs gateway statuses when the BLE connection drops unexpectedly.
  /// Without this, the dashboard would show "Bağlı" forever after a BLE drop.
  void _onBleConnectionChanged() {
    if (!_bleService.isConnected.value) {
      final updated = gateways.value.map((g) {
        return g.isConnected
            ? g.copyWith(
                status: GatewayStatus.disconnected,
                clearConnectedAt: true,
                lastSeen: DateTime.now(),
              )
            : g;
      }).toList();
      gateways.value = updated;
    }
  }

  /// Load persisted gateways from SharedPreferences.
  /// Safe to call multiple times (idempotent). Must be awaited so the list
  /// is ready before any code tries to read or update it.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Keep gateway statuses in sync with real BLE connection state
    _bleService.isConnected.addListener(_onBleConnectionChanged);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gatewaysStorageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
        final loaded = jsonList
            .map((e) => Gateway.fromJson(e as Map<String, dynamic>))
            .toList();

        // All restored gateways start as disconnected (BLE state is not persisted)
        final withStatus = loaded
            .map((g) => g.copyWith(status: GatewayStatus.disconnected))
            .toList();

        gateways.value = withStatus;

        // REQ-GW-05: Auto-connect to the first gateway on startup
        if (withStatus.isNotEmpty) {
          _autoConnectOnStartup(withStatus.first.id);
        }
      }
    } catch (e) {
      debugPrint('GatewayService: failed to load gateways — $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_householdProfilesStorageKey);
      if (profilesJson != null && profilesJson.isNotEmpty) {
        final Map<String, dynamic> jsonMap =
            jsonDecode(profilesJson) as Map<String, dynamic>;
        for (final entry in jsonMap.entries) {
          final profile = HouseholdProfile.fromJson(
              entry.value as Map<String, dynamic>);
          _householdProfiles[profile.gatewayId] = profile;
        }
      }
    } catch (e) {
      debugPrint('GatewayService: failed to load household profiles — $e');
    }
  }

  /// Helper to try connecting once when app starts.
  /// Skips the attempt if BLE permissions have not been granted yet
  /// (e.g. first launch) to avoid showing a spurious "Hata" status.
  Future<void> _autoConnectOnStartup(String id) async {
    // Wait a bit for the app to settle
    await Future.delayed(Duration(milliseconds: 2000 + Random().nextInt(3000)));

    // Don't attempt if BLE permissions haven't been granted yet
    final scanGranted = await Permission.bluetoothScan.isGranted;
    final connectGranted = await Permission.bluetoothConnect.isGranted;
    if (!scanGranted || !connectGranted) {
      debugPrint('GatewayService: skipping auto-reconnect — BLE permissions not granted');
      return;
    }

    if (!_bleService.isConnected.value) {
      debugPrint('GatewayService: Attempting REQ-GW-05 auto-reconnect to $id');
      await connectToGateway(id);
    }
  }

  /// Persist the current gateway list to SharedPreferences.
  Future<void> _saveGateways() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = gateways.value.map((g) => g.toJson()).toList();
      await prefs.setString(_gatewaysStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('GatewayService: failed to save gateways — $e');
    }
  }

  Future<void> _saveHouseholdProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = _householdProfiles.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await prefs.setString(_householdProfilesStorageKey, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('GatewayService: failed to save household profiles — $e');
    }
  }

  // Add a new gateway by ID
  Future<bool> addGateway(
    String gatewayId, {
    String? name,
    BuildingType? buildingType,
    String? street,
    String? buildingNumber,
    String? doorNumber,
    String? neighborhood,
    String? district,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) async {
    // Validate ID format
    if (gatewayId.trim().isEmpty) {
      return false;
    }

    // Check if gateway already exists
    if (gateways.value.any((g) => g.id == gatewayId.trim())) {
      return false;
    }

    // Create new gateway with address
    final gateway = Gateway(
      id: gatewayId.trim(),
      name: name ?? 'Cihaz ${gatewayId.substring(0, gatewayId.length > 4 ? 4 : gatewayId.length)}',
      status: GatewayStatus.disconnected,
      batteryLevel: 100,
      lastSeen: DateTime.now(),
      buildingType: buildingType,
      street: street?.trim().isEmpty == true ? null : street?.trim(),
      buildingNumber: buildingNumber?.trim().isEmpty == true ? null : buildingNumber?.trim(),
      doorNumber: doorNumber?.trim().isEmpty == true ? null : doorNumber?.trim(),
      neighborhood: neighborhood?.trim().isEmpty == true ? null : neighborhood?.trim(),
      district: district?.trim().isEmpty == true ? null : district?.trim(),
      city: city?.trim().isEmpty == true ? null : city?.trim(),
      postalCode: postalCode?.trim().isEmpty == true ? null : postalCode?.trim(),
      latitude: latitude,
      longitude: longitude,
    );

    // Add to list and persist
    gateways.value = [...gateways.value, gateway];
    await _saveGateways();

    GatewayRepository().createGateway({
      // Backend requires unique serialNumber. Use the BLE MAC as the canonical
      // device serial — same value the backend's disaster-events lookup falls
      // back to when :id isn't a Mongo ObjectId.
      'serialNumber': gateway.id,
      'name': gateway.name,
      if (gateway.buildingType != null) 'buildingType': gateway.buildingType!.name,
      if (gateway.street != null) 'street': gateway.street,
      if (gateway.buildingNumber != null) 'buildingNumber': gateway.buildingNumber,
      if (gateway.doorNumber != null) 'doorNumber': gateway.doorNumber,
      if (gateway.neighborhood != null) 'neighborhood': gateway.neighborhood,
      if (gateway.district != null) 'district': gateway.district,
      if (gateway.city != null) 'city': gateway.city,
      if (gateway.postalCode != null) 'postalCode': gateway.postalCode,
      if (gateway.latitude != null) 'latitude': gateway.latitude,
      if (gateway.longitude != null) 'longitude': gateway.longitude,
    }).catchError((Object e) {
      debugPrint('GatewayService: backend gateway create failed — $e');
    });

    return true;
  }

  // Remove a gateway
  Future<void> removeGateway(String gatewayId) async {
    await DevicePasswordService().removeDevice(gatewayId);
    await _bleService.clearQueueForGateway(gatewayId);
    GatewayRepository().deleteGateway(gatewayId).catchError((Object e) {
      debugPrint('GatewayService: backend gateway delete failed — $e');
    });
    gateways.value = gateways.value.where((g) => g.id != gatewayId).toList();
    await _saveGateways();
  }

  // Update gateway status
  void updateGatewayStatus(String gatewayId, GatewayStatus status) {
    final index = gateways.value.indexWhere((g) => g.id == gatewayId);
    if (index != -1) {
      final updated = gateways.value[index].copyWith(
        status: status,
        lastSeen: DateTime.now(),
      );
      final newList = List<Gateway>.from(gateways.value);
      newList[index] = updated;
      gateways.value = newList;
    }
  }

  /// Replace the gateway's stored ID with the real BLE remoteId.
  /// Useful when the user manually typed an ID during add and it doesn't
  /// match the actual BLE address.
  void updateGatewayBleId(String oldId, String newId) {
    if (oldId == newId) return;
    final index = gateways.value.indexWhere((g) => g.id == oldId);
    if (index != -1) {
      final updated = gateways.value[index].copyWith(id: newId);
      final newList = List<Gateway>.from(gateways.value);
      newList[index] = updated;
      gateways.value = newList;
      _saveGateways();
    }
  }

  // Update gateway battery level
  void updateGatewayBattery(String gatewayId, int batteryLevel) {
    final index = gateways.value.indexWhere((g) => g.id == gatewayId);
    if (index != -1) {
      final updated = gateways.value[index].copyWith(
        batteryLevel: batteryLevel,
        lastSeen: DateTime.now(),
      );
      final newList = List<Gateway>.from(gateways.value);
      newList[index] = updated;
      gateways.value = newList;
    }
  }

  // Update the count of registered mobile devices on a gateway
  void updateGatewayDeviceCount(String gatewayId, int count) {
    final index = gateways.value.indexWhere((g) => g.id == gatewayId);
    if (index != -1) {
      final updated = gateways.value[index].copyWith(
        connectedDeviceCount: count,
      );
      final newList = List<Gateway>.from(gateways.value);
      newList[index] = updated;
      gateways.value = newList;
      _saveGateways();
    }
  }

  // Update gateway signal strength
  void updateGatewaySignal(String gatewayId, int signalStrength) {
    final index = gateways.value.indexWhere((g) => g.id == gatewayId);
    if (index != -1) {
      final updated = gateways.value[index].copyWith(
        signalStrength: signalStrength,
        lastSeen: DateTime.now(),
      );
      final newList = List<Gateway>.from(gateways.value);
      newList[index] = updated;
      gateways.value = newList;
    }
  }

  // Connect to a gateway (via BLE)
  Future<void> connectToGateway(String gatewayId) async {
    updateGatewayStatus(gatewayId, GatewayStatus.connecting);
    
    try {
      // Step 1: Use the new REQ-GW-05 fast auto-reconnect
      // This is much faster than a full scan.
      final success = await _bleService.autoReconnect(gatewayId);
      
      if (!success) {
        updateGatewayStatus(gatewayId, GatewayStatus.error);
        return;
      }

      final actualId = _bleService.connectedDeviceId;
      if (actualId != null && actualId != gatewayId) {
        updateGatewayBleId(gatewayId, actualId);
      }

      final effectiveId = (actualId != null && actualId != gatewayId) ? actualId : gatewayId;

      // Step 2: Update gateway status
      final index = gateways.value.indexWhere((g) => g.id == effectiveId);
      if (index != -1) {
        final updated = gateways.value[index].copyWith(
          status: GatewayStatus.connected,
          connectedAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        final newList = List<Gateway>.from(gateways.value);
        newList[index] = updated;
        gateways.value = newList;
      }

      // Step 3: Trigger a periodic location check if it's been 6 months.
      // The actual GPS fetch + comparison is done in the UI layer (DashboardPage)
      // so it can show a proper dialog without needing a BuildContext here.
      _triggerLocationCheckIfDue(effectiveId);

      // Step 4: Register this phone with a stable ID (idempotent on the ESP32).
      // Uses a stable random ID stored in SharedPreferences so repeated connects
      // and app reinstalls do not create duplicate registrations.
      final stableId = await DevicePasswordService().getOrCreateStableDeviceId();
      await _bleService.registerDevice(stableId);

      // Step 4: Query how many mobile devices are registered on this gateway.
      // Only devices registered to THIS gateway count — not nearby devices on others.
      final deviceCount = await _bleService.queryDeviceCount();
      if (deviceCount != null) {
        updateGatewayDeviceCount(effectiveId, deviceCount);
        DisasterRepository().updateGatewayStats(effectiveId, deviceCount: deviceCount)
            .catchError((Object e) {
          debugPrint('GatewayService: backend device count sync failed — $e');
        });
      }
    } catch (e) {
      debugPrint('GatewayService: Connection failed — $e');
      updateGatewayStatus(gatewayId, GatewayStatus.error);
    }
  }

  // Disconnect from a gateway
  Future<void> disconnectFromGateway(String gatewayId) async {
    try {
      await _bleService.disconnect();
    updateGatewayStatus(gatewayId, GatewayStatus.disconnected);
      
      final index = gateways.value.indexWhere((g) => g.id == gatewayId);
      if (index != -1) {
        final updated = gateways.value[index].copyWith(
          status: GatewayStatus.disconnected,
          clearConnectedAt: true,
          lastSeen: DateTime.now(),
        );
        final newList = List<Gateway>.from(gateways.value);
        newList[index] = updated;
        gateways.value = newList;
      }
    } catch (e) {
      updateGatewayStatus(gatewayId, GatewayStatus.error);
    }
  }

  // Get gateway by ID
  Gateway? getGateway(String gatewayId) {
    try {
      return gateways.value.firstWhere((g) => g.id == gatewayId);
    } catch (e) {
      return null;
    }
  }

  // Get statistics
  Map<String, int> getStatistics() {
    final list = gateways.value;
    return {
      'total': list.length,
      'connected': list.where((g) => g.isConnected).length,
      'disconnected': list.where((g) => !g.isConnected).length,
      'lowBattery': list.where((g) => g.isLowBattery).length,
    };
  }

  // Get average battery level
  double getAverageBattery() {
    if (gateways.value.isEmpty) return 0.0;
    final total = gateways.value.fold<int>(
      0,
      (sum, gateway) => sum + gateway.batteryLevel,
    );
    return total / gateways.value.length;
  }

  // ---------- HOUSEHOLD PROFILE METHODS ----------
  
  // Save household profile for a gateway
  Future<void> saveHouseholdProfile(HouseholdProfile profile) async {
    final updatedProfile = profile.copyWith(
      priorityScore: profile.calculatePriorityScore(),
    );
    _householdProfiles[profile.gatewayId] = updatedProfile;
    await _saveHouseholdProfiles();
  }

  // Get household profile for a gateway
  HouseholdProfile? getHouseholdProfile(String gatewayId) {
    return _householdProfiles[gatewayId];
  }

  // Check if gateway has household profile
  bool hasHouseholdProfile(String gatewayId) {
    return _householdProfiles.containsKey(gatewayId);
  }

  // Remove household profile
  Future<void> removeHouseholdProfile(String gatewayId) async {
    _householdProfiles.remove(gatewayId);
    await _saveHouseholdProfiles();
  }

  /// Signals the UI to perform a location check if the interval has elapsed.
  void _triggerLocationCheckIfDue(String gatewayId) {
    final gateway = getGateway(gatewayId);
    if (gateway == null) return;

    // Only check gateways that have stored coordinates to compare against
    if (gateway.latitude == null || gateway.longitude == null) return;

    final last = gateway.lastLocationCheckAt;
    final isDue = last == null ||
        DateTime.now().difference(last).inDays >= _locationCheckIntervalDays;

    if (isDue) {
      locationCheckNeeded.value = gatewayId;
    }
  }

  /// Called by the UI after performing the location check (pass or fail).
  /// Records today as the last check date so the interval resets.
  void markLocationChecked(String gatewayId) {
    final index = gateways.value.indexWhere((g) => g.id == gatewayId);
    if (index == -1) return;

    final updated = gateways.value[index].copyWith(
      lastLocationCheckAt: DateTime.now(),
    );
    final newList = List<Gateway>.from(gateways.value);
    newList[index] = updated;
    gateways.value = newList;
    _saveGateways();

    // Clear the pending signal
    if (locationCheckNeeded.value == gatewayId) {
      locationCheckNeeded.value = null;
    }
  }

  /// Syncs the gateway's GPS coordinates to the backend after a UI-layer location check.
  /// Fire-and-forget: exceptions are caught and logged, never rethrown.
  void syncLocationToBackend(
    String gatewayId,
    double lat,
    double lng,
    String? address,
  ) {
    DisasterRepository()
        .updateGatewayStats(
          gatewayId,
          latitude: lat,
          longitude: lng,
          locationAddress: address,
        )
        .catchError((Object e) {
      debugPrint('GatewayService: backend location sync failed — $e');
    });
  }

  void dispose() {}
}

