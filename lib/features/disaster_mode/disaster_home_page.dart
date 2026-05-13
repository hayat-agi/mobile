import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'controllers/disaster_controller.dart';
import 'widgets/pfa_support_overlay.dart';
import 'services/pfa_message_service.dart';
import 'services/battery_optimization_service.dart';
import 'data/pfa_messages.dart';
import '../user_profile/services/vulnerable_group_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../ble/ble_service.dart';

/// Disaster Mode — CRITICAL screen.
///
/// Simplified layout with exactly three interactive elements:
///   • Message text input (with send button)
///   • Voice-to-text microphone button
///   • SOS button — triggers flashlight morse beacon (··· — — — ···)
///     AND audio beacon ("YARDIM!" every 30s) simultaneously
class DisasterHomePage extends StatefulWidget {
  const DisasterHomePage({super.key, this.autoTriggered = false});

  final bool autoTriggered;

  @override
  State<DisasterHomePage> createState() => _DisasterHomePageState();
}

class _DisasterHomePageState extends State<DisasterHomePage> {
  late final DisasterController _ctrl;
  final _manualTextController = TextEditingController();

  // ── PFA overlay (background — no UI trigger) ──────────────────────
  PfaMessage? _pfaMessage;
  bool _isVulnerableProfile = false;

  // ── Voice-to-text ──────────────────────────────────────────────────
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // ── SOS beacon state (flashlight + audio combined) ─────────────────
  bool _isSosActive = false;

  // ── Flashlight ────────────────────────────────────────────────────
  bool _isFlashlightActive = false;

  // ── Audio beacon (TTS) ────────────────────────────────────────────
  final _tts = FlutterTts();
  Timer? _soundTimer;

  // ── Inactivity auto-send ───────────────────────────────────────────
  //
  // Fires once after 5 minutes of complete inactivity.
  // Rules:
  //   • Resets on any user interaction (typing, mic, SOS) — user is alive.
  //   • Disarms permanently if the user manually sends a message.
  //   • Disarms permanently after it fires — sends exactly once, never again.
  //   • Survives screen-lock (Dart Timer runs while app is foreground).
  //     If the OS kills the process, the timer is lost — this is a known
  //     Android limitation without a foreground service.
  static const _kInactivityDuration = Duration(minutes: 5);
  Timer? _inactivityTimer;
  bool _autoSendArmed = true;

  // ── Send concurrency guard (plain bool, not observable) ───────────────
  bool _isSending = false;

  // ── Inline send-status indicator ──────────────────────────────────────
  String? _sendStatusMessage;
  Color _sendStatusColor = Colors.green;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(DisasterController());

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
    VulnerableGroupService().load().then((_) {
      if (!mounted) return;
      setState(() {
        _isVulnerableProfile = VulnerableGroupService().isVulnerableGroup;
      });
    });

    // Reset inactivity timer whenever the user types (proves they are active).
    _manualTextController.addListener(_resetInactivityTimer);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.onDisasterActivated();
      _startNoResponseTimer();
      _resetInactivityTimer(); // arm the 5-minute inactivity countdown
    });
  }

  @override
  void dispose() {
    BleService().deactivateDisasterMode();
    PFAMessageService().cancelNoResponseTimer();
    _inactivityTimer?.cancel();
    _statusTimer?.cancel();
    _manualTextController.removeListener(_resetInactivityTimer);
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
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
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
    _resetInactivityTimer(); // user is active
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final micPerm = await Permission.microphone.request();
    if (!mounted) return;
    if (!micPerm.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mikrofon izni gerekli'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
      if (!mounted) return;
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesli giriş bu cihazda desteklenmiyor'),
            backgroundColor: Colors.orange,
          ),
        );
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

  // ─── SOS beacon (flashlight + audio combined) ──────────────────────

  Future<void> _toggleSos() async {
    _resetInactivityTimer(); // user is active
    if (_isSosActive) {
      setState(() {
        _isSosActive = false;
        _isFlashlightActive = false;
      });
      await TorchLight.disableTorch().catchError((_) {});
      _stopSoundBeacon();
      return;
    }

    // Check flashlight availability (non-blocking — continue even if absent)
    bool hasFlash = false;
    try {
      hasFlash = await TorchLight.isTorchAvailable();
    } catch (_) {}

    setState(() {
      _isSosActive = true;
      _isFlashlightActive = hasFlash;
    });

    HapticFeedback.heavyImpact();

    if (hasFlash) {
      _runSosPattern();
    }
    _startSoundBeacon();
  }

  /// Repeating SOS morse pattern: ··· — — — ···
  /// Short = 200 ms on, Long = 600 ms on, gaps between flashes = 200 ms,
  /// letter gap = 400 ms, word gap = 2000 ms.
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

  Future<void> _startSoundBeacon() async {
    await _speakBeacon();
    _soundTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _speakBeacon(),
    );
  }

  Future<void> _speakBeacon() async {
    await _tts.speak('YARDIM! YARDIM! YARDIM! Bina altındayım!');
  }

  void _stopSoundBeacon() {
    _soundTimer?.cancel();
    _soundTimer = null;
    _tts.stop();
  }

  // ─── Inactivity auto-send ──────────────────────────────────────────

  /// (Re)starts the 5-minute countdown. No-op if auto-send is already disarmed.
  void _resetInactivityTimer() {
    if (!_autoSendArmed) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_kInactivityDuration, _onInactivityTimeout);
  }

  /// Permanently disarms the auto-send. Called when the user sends manually.
  void _disarmAutoSend() {
    _autoSendArmed = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _showSendStatus(String message, Color color) {
    _statusTimer?.cancel();
    setState(() {
      _sendStatusMessage = message;
      _sendStatusColor = color;
    });
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _sendStatusMessage = null);
    });
  }

  /// Fires once after 5 minutes of complete inactivity.
  Future<void> _onInactivityTimeout() async {
    if (_isSending) {
      _resetInactivityTimer();
      return;
    }

    // Disarm first — guarantees exactly-once delivery even if this is called
    // concurrently (e.g. dispose race).
    _autoSendArmed = false;
    _inactivityTimer = null;

    const autoMessage =
        'Otomatik acil durum bildirimi — kullanıcı 5 dakikadır yanıt vermiyor';

    final result = await _ctrl.sendManualMessage(autoMessage);

    if (!mounted) return;
    if (result.sentOrQueued) {
      _showSendStatus(
        _ctrl.isConnected ? 'Mesaj iletildi ✓' : 'Mesaj kuyruğa alındı',
        _ctrl.isConnected ? Colors.green : Colors.orange,
      );
    } else {
      _showSendStatus('Mesaj gönderilemedi', Colors.red);
    }
  }

  // ─── PFA helpers (background only — no UI trigger) ─────────────────

  void _showPfaMessage(PfaMessage message) {
    if (mounted) setState(() => _pfaMessage = message);
  }

  void _dismissPfa() {
    setState(() => _pfaMessage = null);
    _startNoResponseTimer();
  }

  void _startNoResponseTimer() {
    final interval = BatteryOptimizationService().nonCriticalInterval;
    PFAMessageService().startNoResponseTimer(
      duration: interval,
      onTimeout: () {
        if (mounted) {
          _showPfaMessage(
            PFAMessageService().selectMessage(
                  PfaCategory.uncertainty,
                  isVulnerable: _isVulnerableProfile,
                  riskScore: 0,
                  seed: 'no-response',
                ) ??
                PFAMessageService().firstContactMessage(),
          );
        }
      },
    );
  }

  void _onUserMessageSent(String text) {
    PFAMessageService().cancelNoResponseTimer();
    final category = PFAMessageService().detectCategoryWithRisk(
      text,
      riskScore: 0,
    );
    final msg = PFAMessageService().selectMessage(
      category,
      isVulnerable: _isVulnerableProfile,
      riskScore: 0,
      seed: text,
    );
    if (msg != null) _showPfaMessage(msg);
    _startNoResponseTimer();
  }

  // ─── Send handler ──────────────────────────────────────────────────

  Future<void> _onManualSend() async {
    if (_isSending) return;
    final text = _manualTextController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    _isSending = true;
    setState(() {});
    DisasterSendResult result = DisasterSendResult.failed();
    try {
      result = await _ctrl.sendManualMessage(text);
    } finally {
      _isSending = false;
      if (mounted) setState(() {});
    }

    if (!mounted) return;

    if (result.sentOrQueued) {
      // Any accepted user message proves the user responded. Disarm before
      // clearing the text field, because its listener can reset the timer.
      _disarmAutoSend();
      _manualTextController.clear();
      if (result.syncedToBackend) {
        _onUserMessageSent(text);
      }
      final statusMessage = result.syncedToBackend
          ? 'Mesaj web arayüzüne iletildi ✓'
          : 'Mesaj web arayüzüne ulaşmadı';
      _showSendStatus(
        statusMessage,
        result.syncedToBackend ? Colors.green : Colors.orange,
      );
    } else {
      _showSendStatus('Mesaj gönderilemedi', Colors.red);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // Emergency banner
                  _buildEmergencyBanner(),

                  // SOS button — centered and dominant
                  Expanded(
                    child: Center(
                      child: _SosPulseButton(
                        isActive: _isSosActive,
                        onTap: _toggleSos,
                      ),
                    ),
                  ),

                  // Message input pinned to the bottom
                  _buildMessageInput(),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // PFA support overlay — rendered on top of all content
          if (_pfaMessage != null)
            Positioned.fill(
              child: PFASupportOverlay(
                message: _pfaMessage!,
                onDismiss: _dismissPfa,
              ),
            ),
        ],
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
                        color:
                            (connected ? AppColors.success : AppColors.danger)
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
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.danger,
            size: 28,
          ),
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
                if (widget.autoTriggered) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Sismik aktivite tespit edildi',
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

  // ─── Message input row ─────────────────────────────────────────────

  static const _messageInputTextColor = Color(0xFF0F172A);
  static const _messageInputFillColor = Color(0xFFF1F5F9);

  Widget _buildMessageInput() {
    final borderColor = _isListening
        ? Colors.red.shade400
        : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _sendStatusMessage != null
              ? Padding(
                  key: ValueKey(_sendStatusMessage),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _sendStatusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _sendStatusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: _isListening ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Theme(
                  // Global [inputDecorationTheme] uses filled light surfaces;
                  // disaster screen uses dark scaffold — merged theme made text
                  // white on a light fill (invisible). Override fully here.
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: const TextSelectionThemeData(
                      cursorColor: AppColors.primary,
                      selectionColor: Color(0x663B82F6),
                      selectionHandleColor: AppColors.primary,
                    ),
                  ),
                  child: TextField(
                    controller: _manualTextController,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      color: _messageInputTextColor,
                      fontSize: 16,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      isDense: false,
                      filled: true,
                      fillColor: _messageInputFillColor,
                      hintText: _isListening ? 'Dinleniyor...' : 'Mesaj yaz...',
                      hintStyle: TextStyle(
                        color: _isListening
                            ? Colors.red.shade700
                            : const Color(0xFF64748B),
                        fontSize: 16,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _onManualSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Voice-to-text mic button
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withValues(alpha: 0.25)
                        : Colors.grey.shade800,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 24,
                    color: _isListening ? Colors.red : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Send button — disabled and shows spinner while sending
              GestureDetector(
                onTap: _isSending ? null : _onManualSend,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(
                      alpha: _isSending ? 0.10 : 0.25,
                    ),
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.success,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 24,
                          color: AppColors.success,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── SOS pulse button ────────────────────────────────────────────────

/// Large red SOS button. When [isActive] is true it pulses with a
/// repeating scale + glow animation to signal the beacon is running.
class _SosPulseButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _SosPulseButton({required this.isActive, required this.onTap});

  @override
  State<_SosPulseButton> createState() => _SosPulseButtonState();
}

class _SosPulseButtonState extends State<_SosPulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 18.0,
      end: 42.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    if (widget.isActive) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_SosPulseButton old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isActive && old.isActive) {
      _pulse.stop();
      _pulse.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sosRed = Color(0xFFEF4444);
    const buttonSize = 180.0;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isActive
                        ? sosRed
                        : sosRed.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: sosRed.withValues(
                          alpha: widget.isActive ? 0.55 : 0.25,
                        ),
                        blurRadius: widget.isActive ? _glow.value : 18.0,
                        spreadRadius: widget.isActive ? 6.0 : 2.0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isActive ? Icons.sensors : Icons.sos,
                        size: 52,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  widget.isActive
                      ? 'AKTİF — Fener + Ses çalışıyor'
                      : 'Basarak SOS sinyali gönder',
                  key: ValueKey(widget.isActive),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isActive ? sosRed : Colors.white38,
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                    letterSpacing: widget.isActive ? 0.5 : 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
