import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway.dart';
import '../models/household_profile.dart';
import '../features/ble/ble_service.dart';

class GatewayService {
  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  final ValueNotifier<List<Gateway>> gateways = ValueNotifier<List<Gateway>>([]);
  final Map<String, HouseholdProfile> _householdProfiles = {};
  final BleService _bleService = BleService();

  static const String _gatewaysStorageKey = 'persisted_gateways';
  bool _initialized = false;

  /// Load persisted gateways from SharedPreferences.
  /// Safe to call multiple times (idempotent). Must be awaited so the list
  /// is ready before any code tries to read or update it.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

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
  }

  /// Helper to try connecting once when app starts
  Future<void> _autoConnectOnStartup(String id) async {
    // Wait a bit for the app to settle
    await Future.delayed(const Duration(seconds: 2));
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

  // Add a new gateway by ID
  Future<bool> addGateway(
    String gatewayId, {
    String? name,
    BuildingType? buildingType,
    String? street,
    String? buildingNumber,
    String? doorNumber,
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
      name: name ?? 'Gateway ${gatewayId.substring(0, gatewayId.length > 4 ? 4 : gatewayId.length)}',
      status: GatewayStatus.disconnected,
      batteryLevel: 100,
      lastSeen: DateTime.now(),
      buildingType: buildingType,
      street: street?.trim().isEmpty == true ? null : street?.trim(),
      buildingNumber: buildingNumber?.trim().isEmpty == true ? null : buildingNumber?.trim(),
      doorNumber: doorNumber?.trim().isEmpty == true ? null : doorNumber?.trim(),
      district: district?.trim().isEmpty == true ? null : district?.trim(),
      city: city?.trim().isEmpty == true ? null : city?.trim(),
      postalCode: postalCode?.trim().isEmpty == true ? null : postalCode?.trim(),
      latitude: latitude,
      longitude: longitude,
    );

    // Add to list and persist
    gateways.value = [...gateways.value, gateway];
    await _saveGateways();

    return true;
  }

  // Remove a gateway
  Future<void> removeGateway(String gatewayId) async {
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
      
      // Step 2: Update gateway status
      final index = gateways.value.indexWhere((g) => g.id == gatewayId);
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
          connectedAt: null,
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
    // TODO: Save to local storage
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
    // TODO: Remove from local storage
  }

  void dispose() {
    gateways.dispose();
  }
}

