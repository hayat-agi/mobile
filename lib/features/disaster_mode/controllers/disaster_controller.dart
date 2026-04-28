import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/user_health_profile.dart';
import '../models/disaster_message_packet.dart';
import '../../ble/ble_service.dart';
import '../../../models/household_profile.dart';
import '../../../services/gateway_service.dart';
import '../../../services/device_password_service.dart';
import '../../../core/api/disaster_repository.dart';
import '../../user_profile/services/vulnerable_group_service.dart';

/// Controller for the disaster-mode screen.
///
/// Responsibilities:
///   - Load health profile from registration (for all users)
///   - Send free-text messages via BLE with health profile attached
///   - Track BLE connection state
///
/// Outgoing BLE frames use v4: health profile + message + optional hane profili JSON.
class DisasterController extends GetxController {
  DisasterController({BleService? bleService})
      : _bleService = bleService ?? BleService();

  final BleService _bleService;

  // ─── Observable state ──────────────────────────────────────────────

  /// Sending state.
  final isSending = false.obs;
  final lastSendSuccess = Rxn<bool>();

  /// Health profile loaded from registration — sent with every message.
  UserHealthProfile _healthProfile = UserHealthProfile.empty();

  // ─── Derived BLE state ─────────────────────────────────────────────

  bool get isConnected => _bleService.bleConnection.isConnected.value;
  String get bleStatus => _bleService.bleConnection.status.value;

  // ─── Profile load ──────────────────────────────────────────────────

  /// Called when disaster mode opens. Loads the registered health profile
  /// for ALL users so it is always attached to outgoing BLE packets.
  Future<void> onDisasterActivated() async {
    final vgs = VulnerableGroupService();
    await vgs.load();
    _healthProfile = vgs.profile;
  }

  // ─── Send ──────────────────────────────────────────────────────────

  /// Send a free-text message via BLE with the user's health profile attached.
  /// Returns true if sent or successfully queued.
  /// Returns false only if no gateway has ever been added.
  Future<bool> sendManualMessage(String text) async {
    if (text.trim().isEmpty) return false;

    final savedGateways = GatewayService().gateways.value;
    if (savedGateways.isEmpty && !isConnected) return false;

    if (savedGateways.isNotEmpty) {
      _bleService.bleConnection.setLastDeviceId(savedGateways.first.id);
    }

    isSending.value = true;
    try {
      HouseholdProfile? household;
      if (savedGateways.isNotEmpty) {
        household =
            GatewayService().getHouseholdProfile(savedGateways.first.id);
      }

      final packet = DisasterMessagePacket(
        healthProfile: _healthProfile,
        messageText: text.trim(),
        household: household,
      );
      await _bleService.sendBinaryQueued(packet.encode());
      lastSendSuccess.value = true;

      final gatewayId =
          savedGateways.isNotEmpty ? savedGateways.first.id : null;
      if (gatewayId != null) {
        final phoneId = await DevicePasswordService().getOrCreateStableDeviceId();
        final gateway = GatewayService().getGateway(gatewayId);
        DisasterRepository().reportDisasterEvent(gatewayId, {
          'type': 'manual_message',
          'message': text.trim(),
          'sentAt': DateTime.now().toIso8601String(),
          'phoneDeviceId': phoneId,
          'healthProfile': _healthProfile.hasProfile ? _healthProfile.toJson() : null,
          'household': household?.toJson(),
          'gateway': {
            'id': gatewayId,
            'latitude': gateway?.latitude,
            'longitude': gateway?.longitude,
            'address': gateway?.formattedAddress,
            'buildingType': gateway?.buildingType?.name,
            'batteryLevel': gateway?.batteryLevel,
          },
        }).catchError((Object e) {
          debugPrint('DisasterController: backend sync failed — $e');
        });
      }

      return true;
    } catch (_) {
      lastSendSuccess.value = false;
      return false;
    } finally {
      isSending.value = false;
    }
  }
}
