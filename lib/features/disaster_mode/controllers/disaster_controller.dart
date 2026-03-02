import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import '../models/disaster_enums.dart';
import '../models/triage_payload.dart';
import '../../ble/ble_service.dart';
import '../../../services/gateway_service.dart';

/// Controller for the disaster-mode screen.
///
/// Responsibilities:
///   - Manage selected status + smart chips
///   - Calculate triage score in real time
///   - Encode bitmask payload via [TriagePayload]
///   - Send payload via [BleService.sendHexPayload]
///   - Enforce 15-minute debounce between sends
///   - Track BLE connection state
///
/// NO BLE business logic lives in widgets — all state flows through here.
class DisasterController extends GetxController {
  DisasterController({BleService? bleService})
      : _bleService = bleService ?? BleService();

  final BleService _bleService;

  // ─── Observable state ──────────────────────────────────────────────

  /// Currently selected primary status (null = nothing selected yet).
  final selectedStatus = Rxn<DisasterStatus>();

  /// Selected chips per category.
  final selectedInjuries = <InjuryChip>{}.obs;
  final selectedSituations = <SituationChip>{}.obs;
  final selectedNeeds = <NeedChip>{}.obs;
  final selectedPeople = <PeopleChip>{}.obs;

  /// People counts.
  final adultCount = 1.obs;
  final childCount = 0.obs;

  /// Real-time triage score & category.
  final triageScore = 0.obs;
  final triageCategory = TriageCategory.green.obs;

  /// Debounce tracking.
  final lastSentAt = Rxn<DateTime>();
  final canSend = true.obs;
  final debounceRemaining = 0.obs; // seconds remaining

  /// Sending state.
  final isSending = false.obs;
  final lastSendSuccess = Rxn<bool>();

  // ─── Derived BLE state (read from BleService) ─────────────────────

  // Read the RxBool directly so Obx can track reactivity.
  // _bleService.isConnected is a ValueNotifier (invisible to GetX).
  // _bleService.bleConnection.isConnected is the RxBool (tracked by Obx).
  bool get isConnected => _bleService.bleConnection.isConnected.value;
  String get bleStatus => _bleService.bleConnection.status.value;

  // ─── Constants ─────────────────────────────────────────────────────

  static const int _debounceDurationMinutes = 15;
  static const int _debounceDurationSeconds = _debounceDurationMinutes * 60;

  Timer? _debounceTimer;

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  // ─── Status selection ──────────────────────────────────────────────

  void selectStatus(DisasterStatus status) {
    final previous = selectedStatus.value;
    selectedStatus.value = status;

    // Clear chips that are not relevant for the new status
    if (status == DisasterStatus.safe) {
      selectedInjuries.clear();
      selectedSituations.clear();
    }

    // If the status TYPE changed while debounce is active, allow re-send
    if (previous != null && previous != status && !canSend.value) {
      _resetDebounce();
    }

    _recalculate();
  }

  void clearStatus() {
    selectedStatus.value = null;
    selectedInjuries.clear();
    selectedSituations.clear();
    selectedNeeds.clear();
    selectedPeople.clear();
    adultCount.value = 1;
    childCount.value = 0;
    _recalculate();
  }

  // ─── Chip toggles ─────────────────────────────────────────────────

  void toggleInjury(InjuryChip chip) {
    if (selectedInjuries.contains(chip)) {
      selectedInjuries.remove(chip);
    } else {
      selectedInjuries.add(chip);
    }
    _recalculate();
  }

  void toggleSituation(SituationChip chip) {
    if (selectedSituations.contains(chip)) {
      selectedSituations.remove(chip);
    } else {
      selectedSituations.add(chip);
    }
    _recalculate();
  }

  void toggleNeed(NeedChip chip) {
    if (selectedNeeds.contains(chip)) {
      selectedNeeds.remove(chip);
    } else {
      selectedNeeds.add(chip);
    }
  }

  void togglePeople(PeopleChip chip) {
    // "alone" is mutually exclusive with other people chips
    if (chip == PeopleChip.alone) {
      if (selectedPeople.contains(chip)) {
        selectedPeople.remove(chip);
      } else {
        selectedPeople.clear();
        selectedPeople.add(chip);
        adultCount.value = 1;
        childCount.value = 0;
      }
    } else {
      selectedPeople.remove(PeopleChip.alone);
      if (selectedPeople.contains(chip)) {
        selectedPeople.remove(chip);
      } else {
        selectedPeople.add(chip);
      }
    }
    _recalculate();
  }

  // ─── People counts ────────────────────────────────────────────────

  void incrementAdults() {
    if (adultCount.value < 15) adultCount.value++;
    selectedPeople.remove(PeopleChip.alone);
  }

  void decrementAdults() {
    if (adultCount.value > 0) adultCount.value--;
  }

  void incrementChildren() {
    if (childCount.value < 15) childCount.value++;
    selectedPeople.remove(PeopleChip.alone);
    if (!selectedPeople.contains(PeopleChip.withChildren)) {
      selectedPeople.add(PeopleChip.withChildren);
    }
    _recalculate();
  }

  void decrementChildren() {
    if (childCount.value > 0) childCount.value--;
    if (childCount.value == 0) {
      selectedPeople.remove(PeopleChip.withChildren);
    }
    _recalculate();
  }

  // ─── Triage calculation ────────────────────────────────────────────

  void _recalculate() {
    final status = selectedStatus.value;
    if (status == null) {
      triageScore.value = 0;
      triageCategory.value = TriageCategory.green;
      return;
    }

    final score = calculateTriageScore(
      status: status,
      injuries: selectedInjuries.toSet(),
      situations: selectedSituations.toSet(),
      people: selectedPeople.toSet(),
    );

    triageScore.value = score;
    triageCategory.value = TriageCategoryX.fromScore(score);
  }

  // ─── Bitmask encoding ─────────────────────────────────────────────

  Uint8List buildPayload() {
    final status = selectedStatus.value;
    if (status == null) return Uint8List(0);

    final payload = TriagePayload(
      status: status,
      injuries: selectedInjuries.toSet(),
      situations: selectedSituations.toSet(),
      needs: selectedNeeds.toSet(),
      people: selectedPeople.toSet(),
      adultCount: adultCount.value,
      childCount: childCount.value,
      triageScore: triageScore.value,
    );

    return payload.encode();
  }

  // ─── Send ──────────────────────────────────────────────────────────

    /// Encode the current state and send via BLE.
  /// Returns false if debounced, not connected, or send failed.
  Future<bool> sendStatus() async {
    if (selectedStatus.value == null) return false;
    if (!canSend.value) return false;
    if (isSending.value) return false;

    // REQ-GW-05: Auto-connect if disconnected
    if (!isConnected) {
      final savedGateways = GatewayService().gateways.value;
      if (savedGateways.isNotEmpty) {
        isSending.value = true;
        final reconnected = await _bleService.autoReconnect(savedGateways.first.id);
        isSending.value = false;
        if (!reconnected) return false;
      } else {
        return false;
      }
    }

    isSending.value = true;

    try {
      final payload = buildPayload();
      if (payload.isEmpty) return false;

      final success = await _bleService.sendHexPayload(payload);
      lastSendSuccess.value = success;

      if (success) {
        _startDebounce();
      }

      return success;
    } catch (e) {
      lastSendSuccess.value = false;
      return false;
    } finally {
      isSending.value = false;
    }
  }

  // ─── Debounce ──────────────────────────────────────────────────────

  void _startDebounce() {
    lastSentAt.value = DateTime.now();
    canSend.value = false;
    debounceRemaining.value = _debounceDurationSeconds;

    _debounceTimer?.cancel();
    _debounceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final sent = lastSentAt.value;
      if (sent == null) {
        _resetDebounce();
        return;
      }

      final elapsed = DateTime.now().difference(sent).inSeconds;
      final remaining = _debounceDurationSeconds - elapsed;

      if (remaining <= 0) {
        _resetDebounce();
      } else {
        debounceRemaining.value = remaining;
      }
    });
  }

  void _resetDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    canSend.value = true;
    debounceRemaining.value = 0;
  }

  /// Format remaining debounce time as "MM:SS".
  String get debounceFormatted {
    final secs = debounceRemaining.value;
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Manual text message ───────────────────────────────────────────

  /// Send a free-text message via BLE. Returns true once the message is
  /// accepted (either sent immediately or queued for retry).
  /// The BLE queue system handles reconnection + retry transparently.
  Future<bool> sendManualMessage(String text) async {
    if (text.trim().isEmpty) return false;

    try {
      await _bleService.sendMessage(text.trim());
      return true;
    } catch (_) {
      return false;
    }
  }
}
