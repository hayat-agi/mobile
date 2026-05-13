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
  /// The BLE send/queue and backend sync are reported separately so the UI can
  /// delay PFA support until the web command center has received the event.
  Future<DisasterSendResult> sendManualMessage(String text) async {
    if (text.trim().isEmpty) return DisasterSendResult.failed();

    final savedGateways = GatewayService().gateways.value;
    if (savedGateways.isEmpty && !isConnected) {
      return DisasterSendResult.failed();
    }

    final connectedGatewayId = _bleService.connectedDeviceId;
    final gatewayId =
        connectedGatewayId ??
        (savedGateways.isNotEmpty ? savedGateways.first.id : null);
    if (gatewayId == null) {
      return DisasterSendResult.failed();
    }
    _bleService.bleConnection.setLastDeviceId(gatewayId);

    isSending.value = true;
    try {
      HouseholdProfile? household;
      household = GatewayService().getHouseholdProfile(gatewayId);

      final packet = DisasterMessagePacket(
        healthProfile: _healthProfile,
        messageText: text.trim(),
        household: household,
      );
      await _bleService.sendBinaryQueued(packet.encode());
      lastSendSuccess.value = true;

      var syncedToBackend = false;
      {
        final phoneId = await DevicePasswordService()
            .getOrCreateStableDeviceId();
        final gateway = GatewayService().getGateway(gatewayId);
        final payload = {
          'type': 'manual_message',
          'message': text.trim(),
          'sentAt': DateTime.now().toIso8601String(),
          'phoneDeviceId': phoneId,
          'healthProfile': _healthProfile.hasProfile
              ? _healthProfile.toJson()
              : null,
          'household': household?.toJson(),
          'gateway': {
            'id': gatewayId,
            'latitude': gateway?.latitude,
            'longitude': gateway?.longitude,
            'address': gateway?.formattedAddress,
            'buildingType': gateway?.buildingType?.name,
            'batteryLevel': gateway?.batteryLevel,
          },
        };
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            await DisasterRepository().reportDisasterEvent(gatewayId, payload);
            syncedToBackend = true;
            break;
          } catch (e) {
            if (attempt == 2) {
              debugPrint('DisasterController: backend sync failed — $e');
            } else {
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }
      }

      return DisasterSendResult(
        sentOrQueued: true,
        syncedToBackend: syncedToBackend,
      );
    } catch (_) {
      lastSendSuccess.value = false;
      return DisasterSendResult.failed();
    } finally {
      isSending.value = false;
    }
  }
}

class DisasterSendResult {
  const DisasterSendResult({
    required this.sentOrQueued,
    required this.syncedToBackend,
  });

  factory DisasterSendResult.failed() {
    return const DisasterSendResult(
      sentOrQueued: false,
      syncedToBackend: false,
    );
  }

  final bool sentOrQueued;
  final bool syncedToBackend;
}
