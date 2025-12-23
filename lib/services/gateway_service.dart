import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gateway.dart';
import '../models/household_profile.dart';
// import '../features/ble/ble_service.dart'; // TODO: Use for BLE integration

class GatewayService {
  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  final ValueNotifier<List<Gateway>> gateways = ValueNotifier<List<Gateway>>([]);
  final Map<String, HouseholdProfile> _householdProfiles = {};
  // final BleService _bleService = BleService(); // TODO: Use for BLE integration

  // Initialize with empty list or load from storage
  void initialize() {
    // TODO: Load from local storage if needed
    gateways.value = [];
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

    // Add to list
    gateways.value = [...gateways.value, gateway];

    // TODO: Save to local storage
    // TODO: Try to connect via BLE if device is available
    // TODO: Geocode address to get latitude/longitude if not provided

    return true;
  }

  // Remove a gateway
  Future<void> removeGateway(String gatewayId) async {
    gateways.value = gateways.value.where((g) => g.id != gatewayId).toList();
    // TODO: Save to local storage
    // TODO: Disconnect if connected
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
    
    // TODO: Implement actual BLE connection logic
    // For now, simulate connection
    await Future.delayed(const Duration(seconds: 2));
    
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
  }

  // Disconnect from a gateway
  Future<void> disconnectFromGateway(String gatewayId) async {
    updateGatewayStatus(gatewayId, GatewayStatus.disconnected);
    // TODO: Implement actual BLE disconnection
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

