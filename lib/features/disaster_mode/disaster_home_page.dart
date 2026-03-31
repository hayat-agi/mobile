import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'controllers/disaster_controller.dart';
import 'models/disaster_enums.dart';
import 'widgets/status_action_button.dart';
import 'widgets/smart_chip_selector.dart';
import 'widgets/triage_score_display.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../ble/ble_service.dart';

/// Disaster Mode — CRITICAL screen.
///
/// True-black UI with:
///   • Three long-press status buttons (Yaralıyım / Mahsurum / Güvendeyim)
///   • Context-sensitive smart chips (injury, situation, needs, people)
///   • Real-time triage score display
///   • Bitmask payload sent via BLE
///   • 15-minute debounce between sends
///   • Voice-to-text message input
///   • Flashlight SOS beacon (morse ··· — — — ···)
///   • Audio beacon (TTS "YARDIM!" every 30s)
class DisasterHomePage extends StatefulWidget {
  const DisasterHomePage({super.key, this.autoTriggered = false});

  final bool autoTriggered;

  @override
  State<DisasterHomePage> createState() => _DisasterHomePageState();
}

class _DisasterHomePageState extends State<DisasterHomePage> {
  late final DisasterController _ctrl;
  final _manualTextController = TextEditingController();

  // ── Voice-to-text ──────────────────────────────────────────────────
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // ── Flashlight SOS ────────────────────────────────────────────────
  bool _isFlashlightActive = false;

  // ── Audio beacon (TTS) ────────────────────────────────────────────
  final _tts = FlutterTts();
  bool _isSoundActive = false;
  Timer? _soundTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(DisasterController());

    // Activate disaster mode: gateway is released immediately after each send
    BleService().bleConnection.disasterMode = true;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _initSpeech();
    _initTts();
  }

  @override
  void dispose() {
    // Deactivate disaster mode safely — defers if a queue drain is in progress
    BleService().deactivateDisasterMode();

    _manualTextController.dispose();

    // Stop all beacons
    _isFlashlightActive = false;
    TorchLight.disableTorch().catchError((_) {});
    _stopSoundBeacon();
    _speech.cancel();

    Get.delete<DisasterController>();
    super.dispose();
  }

  // ─── Speech init ───────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() => _speechAvailable = available);
  }

  // ─── TTS init ──────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.8);
  }

  // ─── Voice-to-text ─────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Request microphone permission
    final micPerm = await Permission.microphone.request();
    if (!micPerm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mikrofon izni gerekli'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_speechAvailable) {
      // Try re-initializing
      await _initSpeech();
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesli giriş bu cihazda desteklenmiyor'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        _manualTextController.text = result.recognizedWords;
        _manualTextController.selection = TextSelection.fromPosition(
          TextPosition(offset: _manualTextController.text.length),
        );
      },
      localeId: 'tr_TR',
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
    );
  }

  // ─── Flashlight SOS ────────────────────────────────────────────────

  Future<void> _toggleFlashlight() async {
    if (_isFlashlightActive) {
      setState(() => _isFlashlightActive = false);
      await TorchLight.disableTorch().catchError((_) {});
      return;
    }

    // Check if device has a flashlight
    try {
      final hasFlash = await TorchLight.isTorchAvailable();
      if (!hasFlash) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu cihazda fener bulunamadı'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    setState(() => _isFlashlightActive = true);
    HapticFeedback.heavyImpact();
    _runSosPattern(); // runs until _isFlashlightActive = false
  }

  /// Repeating SOS morse pattern: ··· — — — ···
  /// Short = 200ms, Long = 600ms, letter gap = 400ms, word gap = 2000ms
  Future<void> _runSosPattern() async {
    const shortMs = 200;
    const longMs = 600;
    const offMs = 200;
    const letterGapMs = 400;
    const wordGapMs = 2000;

    Future<void> flash(int onMs, int nextGapMs) async {
      if (!_isFlashlightActive) return;
      await TorchLight.enableTorch().catchError((_) {});
      await Future.delayed(Duration(milliseconds: onMs));
      await TorchLight.disableTorch().catchError((_) {});
      await Future.delayed(Duration(milliseconds: nextGapMs));
    }

    while (_isFlashlightActive) {
      // S: · · ·
      await flash(shortMs, offMs);
      await flash(shortMs, offMs);
      await flash(shortMs, letterGapMs);
      if (!_isFlashlightActive) break;

      // O: — — —
      await flash(longMs, offMs);
      await flash(longMs, offMs);
      await flash(longMs, letterGapMs);
      if (!_isFlashlightActive) break;

      // S: · · ·
      await flash(shortMs, offMs);
      await flash(shortMs, offMs);
      await flash(shortMs, wordGapMs);
    }

    await TorchLight.disableTorch().catchError((_) {});
  }

  // ─── Audio beacon ──────────────────────────────────────────────────

  Future<void> _toggleSound() async {
    if (_isSoundActive) {
      _stopSoundBeacon();
      return;
    }
    setState(() => _isSoundActive = true);
    HapticFeedback.heavyImpact();

    // Speak immediately, then every 30 seconds
    await _speakBeacon();
    _soundTimer = Timer.periodic(const Duration(seconds: 30), (_) => _speakBeacon());
  }

  Future<void> _speakBeacon() async {
    await _tts.speak('YARDIM! YARDIM! YARDIM! Bina altındayım!');
  }

  void _stopSoundBeacon() {
    _soundTimer?.cancel();
    _soundTimer = null;
    _tts.stop();
    setState(() => _isSoundActive = false);
  }

  // ─── Send handlers ─────────────────────────────────────────────────

  Future<void> _onSend() async {
    HapticFeedback.mediumImpact();

    final success = await _ctrl.sendStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (_ctrl.isConnected
                  ? 'Durum bilgisi gönderildi'
                  : 'Kuyruğa alındı — bağlantı kurulunca iletilecek')
              : 'Gateway eklenmemiş — önce bir gateway ekleyin',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onManualSend() async {
    final text = _manualTextController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    final success = await _ctrl.sendManualMessage(text);

    if (!mounted) return;

    if (success) {
      _manualTextController.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (_ctrl.isConnected
                  ? 'Mesaj gönderildi'
                  : 'Kuyruğa alındı — bağlantıda iletilecek')
              : 'Gateway eklenmemiş — önce bir gateway ekleyin',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Obx(() {
          final status = _ctrl.selectedStatus.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emergency banner
                _buildEmergencyBanner(),
                const SizedBox(height: 20),

                // Status buttons
                _buildStatusButtons(),
                const SizedBox(height: 24),

                // Smart chip sections (context-sensitive)
                if (status != null) ...[
                  // Injury chips — only for injured / trapped
                  if (status != DisasterStatus.safe) ...[
                    Obx(() => SmartChipSelector<InjuryChip>(
                          title: 'YARALANMA DURUMU',
                          chips: InjuryChip.values,
                          selected: _ctrl.selectedInjuries.toSet(),
                          labelOf: (c) => c.label,
                          iconOf: (c) => c.icon,
                          accentColor: const Color(0xFFEF4444),
                          onToggle: _ctrl.toggleInjury,
                        )),
                    const SizedBox(height: 16),

                    // Situation chips
                    Obx(() => SmartChipSelector<SituationChip>(
                          title: 'DURUM',
                          chips: SituationChip.values,
                          selected: _ctrl.selectedSituations.toSet(),
                          labelOf: (c) => c.label,
                          iconOf: (c) => c.icon,
                          accentColor: const Color(0xFFF59E0B),
                          onToggle: _ctrl.toggleSituation,
                        )),
                    const SizedBox(height: 16),
                  ],

                  // Needs chips — all statuses
                  Obx(() => SmartChipSelector<NeedChip>(
                        title: 'İHTİYAÇLAR',
                        chips: NeedChip.values,
                        selected: _ctrl.selectedNeeds.toSet(),
                        labelOf: (c) => c.label,
                        iconOf: (c) => c.icon,
                        accentColor: const Color(0xFF3B82F6),
                        onToggle: _ctrl.toggleNeed,
                      )),
                  const SizedBox(height: 16),

                  // People chips — all statuses
                  Obx(() => SmartChipSelector<PeopleChip>(
                        title: 'KİŞİLER',
                        chips: PeopleChip.values,
                        selected: _ctrl.selectedPeople.toSet(),
                        labelOf: (c) => c.label,
                        iconOf: (c) => c.icon,
                        accentColor: const Color(0xFF8B5CF6),
                        onToggle: _ctrl.togglePeople,
                      )),
                  const SizedBox(height: 16),

                  // People count
                  _buildPeopleCount(),
                  const SizedBox(height: 24),

                  // Triage score
                  Obx(() => TriageScoreDisplay(
                        score: _ctrl.triageScore.value,
                        category: _ctrl.triageCategory.value,
                      )),
                  const SizedBox(height: 24),

                  // Send button
                  _buildSendButton(),
                  const SizedBox(height: 16),

                  // Manual text input with voice-to-text
                  _buildManualTextInput(),
                  const SizedBox(height: 16),

                  // Messages link
                  _buildMessagesButton(),
                  const SizedBox(height: 16),

                  // Flashlight & sound beacons
                  _buildBeaconSection(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Afet Modu', style: TextStyle(color: Colors.white)),
      actions: [
        // Live connection indicator
        Obx(() {
          final connected = _ctrl.isConnected;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? AppColors.success : AppColors.danger,
                    boxShadow: [
                      BoxShadow(
                        color: (connected ? AppColors.success : AppColors.danger)
                            .withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  connected ? 'Bağlı' : 'Bağlantı Yok',
                  style: TextStyle(
                    color: connected ? AppColors.success : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── Emergency banner ──────────────────────────────────────────────

  Widget _buildEmergencyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acil Durum Modu',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Durumunuzu seçin, detayları işaretleyin, gönderin',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (widget.autoTriggered) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Sismik aktivite tespit edildi — durumunuzu seçin',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status buttons ────────────────────────────────────────────────

  Widget _buildStatusButtons() {
    return Obx(() {
      final current = _ctrl.selectedStatus.value;

      return Row(
        children: DisasterStatus.values.map((status) {
          final isSelected = current == status;
          final isOtherSelected = current != null && !isSelected;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: status == DisasterStatus.injured ? 0 : 6,
                right: status == DisasterStatus.safe ? 0 : 6,
              ),
              child: StatusActionButton(
                label: status.label,
                subtitle: status.subtitle,
                icon: status.icon,
                color: status.color,
                isSelected: isSelected,
                isDisabled: isOtherSelected,
                onConfirmed: () => _ctrl.selectStatus(status),
                onDeselected: () => _ctrl.clearStatus(),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  // ─── People count ──────────────────────────────────────────────────

  Widget _buildPeopleCount() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Adults
          Expanded(
            child: Obx(() => _CounterTile(
                  label: 'Yetişkin',
                  value: _ctrl.adultCount.value,
                  onIncrement: _ctrl.incrementAdults,
                  onDecrement: _ctrl.decrementAdults,
                )),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade700,
          ),
          // Children
          Expanded(
            child: Obx(() => _CounterTile(
                  label: 'Çocuk',
                  value: _ctrl.childCount.value,
                  onIncrement: _ctrl.incrementChildren,
                  onDecrement: _ctrl.decrementChildren,
                )),
          ),
        ],
      ),
    );
  }

  // ─── Send button ───────────────────────────────────────────────────

  Widget _buildSendButton() {
    return Obx(() {
      final canSend = _ctrl.canSend.value;
      final isSending = _ctrl.isSending.value;
      final hasStatus = _ctrl.selectedStatus.value != null;
      final connected = _ctrl.isConnected;
      // Button stays enabled when disconnected — payload will be queued
      // and delivered automatically when the connection is restored.
      final enabled = canSend && hasStatus && !isSending;

      final color = enabled ? _ctrl.triageCategory.value.color : Colors.grey.shade700;

      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: enabled ? _onSend : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: enabled ? 4 : 0,
              ),
              child: isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          canSend
                              ? 'DURUM BİLDİR'
                              : 'BEKLEME (${_ctrl.debounceFormatted})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Status hints
          if (!connected && hasStatus)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bağlantı yok — gönderilince iletilecek',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          if (!canSend)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Yeni durum bildirimi için ${_ctrl.debounceFormatted} bekleyin',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      );
    });
  }

  // ─── Manual text input with voice-to-text ──────────────────────────

  Widget _buildManualTextInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isListening ? Colors.red : Colors.grey.shade700,
          width: _isListening ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualTextController,
              enabled: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isListening ? 'Dinleniyor...' : 'Mesaj yaz...',
                hintStyle: TextStyle(
                  color: _isListening ? Colors.red.shade300 : Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _onManualSend(),
            ),
          ),
          const SizedBox(width: 4),

          // Voice-to-text mic button
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.red.withValues(alpha: 0.25)
                    : Colors.grey.shade800,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 20,
                color: _isListening ? Colors.red : Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Send button
          GestureDetector(
            onTap: _onManualSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 20,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Messages button ───────────────────────────────────────────────

  Widget _buildMessagesButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(context, AppRouter.messages),
        icon: const Icon(Icons.message, size: 20),
        label: const Text('Mesajlar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: BorderSide(color: Colors.grey.shade700),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Beacon section ────────────────────────────────────────────────

  Widget _buildBeaconSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KONUM SİNYALİ',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Flashlight SOS button
            Expanded(
              child: _BeaconButton(
                icon: Icons.flashlight_on,
                label: 'Fener SOS',
                sublabel: _isFlashlightActive ? 'AKTİF — ··· — — — ···' : 'Morse kodu',
                isActive: _isFlashlightActive,
                activeColor: const Color(0xFFF59E0B),
                onTap: _toggleFlashlight,
              ),
            ),
            const SizedBox(width: 12),

            // Audio beacon button
            Expanded(
              child: _BeaconButton(
                icon: Icons.campaign,
                label: 'Ses Sinyali',
                sublabel: _isSoundActive ? 'AKTİF — her 30s' : '"YARDIM!" sesi',
                isActive: _isSoundActive,
                activeColor: const Color(0xFFEF4444),
                onTap: _toggleSound,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Helper: beacon button ───────────────────────────────────────────

class _BeaconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _BeaconButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.shade700,
            width: isActive ? 1.5 : 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isActive ? activeColor : Colors.white38,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? activeColor.withValues(alpha: 0.8) : Colors.white30,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper: counter tile ────────────────────────────────────────────

class _CounterTile extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterTile({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleButton(Icons.remove, onDecrement),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _circleButton(Icons.add, onIncrement),
          ],
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
