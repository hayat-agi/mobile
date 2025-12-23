import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ble/ble_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class DisasterHomePage extends StatefulWidget {
  const DisasterHomePage({super.key});

  @override
  State<DisasterHomePage> createState() => _DisasterHomePageState();
}

class _DisasterHomePageState extends State<DisasterHomePage> {
  final TextEditingController _messageController = TextEditingController();
  final BleService _bleService = BleService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    _bleService.isConnected.addListener(_updateConnectionStatus);
    _bleService.status.addListener(_updateConnectionStatus);
  }
  
  void _updateConnectionStatus() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bleService.isConnected.removeListener(_updateConnectionStatus);
    _bleService.status.removeListener(_updateConnectionStatus);
    super.dispose();
  }

  Future<void> _sendSosMessage({String? quickMessage}) async {
    final message = quickMessage ?? _messageController.text.trim();
    
    if (message.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen bir mesaj yazın'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    
    setState(() {
      _isSending = true;
    });

    await _bleService.sendSosMessage(message);

    if (mounted) {
      setState(() {
        _isSending = false;
        _messageController.clear();
      });

      HapticFeedback.heavyImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mesaj gönderildi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _sendQuickStatus(String message) {
    _sendSosMessage(quickMessage: message);
  }

  void _navigateToMessages() {
    Navigator.pushNamed(context, AppRouter.messages);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Afet Modu',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              // Emergency Mode Banner
              _buildEmergencyBanner(),
              SizedBox(height: screenHeight * 0.04),
              
              // Connection Status
              _buildConnectionStatus(),
              SizedBox(height: screenHeight * 0.04),
              
              // SOS Button
              _buildSosButton(screenWidth),
              SizedBox(height: screenHeight * 0.04),
              
              // Quick Status Buttons
              _buildQuickStatusButtons(),
              SizedBox(height: AppSpacing.lg),
              
              // Custom Message Input
              _buildCustomMessageInput(),
              SizedBox(height: AppSpacing.lg),
              
              // Messages Button
              _buildMessagesButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acil Durum Modu',
                  style: AppTypography.titleLarge(context).copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Mesajlar gateway üzerinden gönderilecek',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ValueListenableBuilder<String>(
      valueListenable: _bleService.status,
      builder: (context, status, _) {
        final isConnected = _bleService.isConnected.value;
        final isScanning = _bleService.isScanning.value;
        
        return ModernCard(
          color: Colors.grey.shade900,
          child: Column(
            children: [
              Row(
                children: [
                  StatusPill(
                    label: isConnected ? 'Bağlı' : 'Bağlı Değil',
                    type: isConnected ? StatusType.success : StatusType.warning,
                    icon: isConnected ? Icons.check_circle : Icons.cancel,
                  ),
                  const Spacer(),
                  if (isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isConnected
                    ? "Gateway'e bağlısın"
                    : "Gateway'e bağlı değilsin, mesaj sıraya alındı",
                style: AppTypography.bodyMedium(context).copyWith(
                  color: isConnected ? AppColors.success : Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isConnected && !isScanning) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _bleService.scanDevices,
                  icon: const Icon(Icons.search),
                  label: const Text('Cihaz Ara'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              if (isScanning) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Cihazlar aranıyor...',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.info,
                  ),
                ),
              ],
              if (!isConnected && _bleService.results.value.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ..._bleService.results.value.take(3).map((result) {
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : result.advertisementData.advName;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _bleService.connect(result),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        child: Text(
                          name.isEmpty ? 'Bilinmeyen Cihaz' : name,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSosButton(double screenWidth) {
    final buttonSize = (screenWidth * 0.5).clamp(200.0, 280.0);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: buttonSize,
      height: buttonSize,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSending ? null : () => _sendSosMessage(),
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            decoration: BoxDecoration(
              color: _isSending ? AppColors.dangerDark : AppColors.danger,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withOpacity(0.6),
                  blurRadius: _isSending ? 40 : 30,
                  spreadRadius: _isSending ? 8 : 0,
                ),
              ],
            ),
            child: Center(
              child: _isSending
                  ? const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'SOS\nGÖNDER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                        height: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatusButtons() {
    return Column(
      children: [
        _buildQuickStatusButton(
          icon: Icons.warning,
          label: 'Ağır yaralıyım',
          color: AppColors.danger,
          onTap: () => _sendQuickStatus('Ağır yaralıyım'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildQuickStatusButton(
          icon: Icons.air,
          label: 'Sıkıştım ama nefes alıyorum',
          color: AppColors.warning,
          onTap: () => _sendQuickStatus('Sıkıştım ama nefes alıyorum'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildQuickStatusButton(
          icon: Icons.water_drop,
          label: 'Güvendeyim ama yardıma ihtiyacım var\n(su, yiyecek vb.)',
          color: AppColors.info,
          onTap: () => _sendQuickStatus('Güvendeyim ama yardıma ihtiyacım var (su, yiyecek vb.)'),
        ),
      ],
    );
  }

  Widget _buildQuickStatusButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomMessageInput() {
    return TextField(
      controller: _messageController,
      enabled: !_isSending,
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Örn: Nefes alamıyorum, bacağım sıkıştı',
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade900,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      maxLines: 3,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendSosMessage(),
    );
  }

  Widget _buildMessagesButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _navigateToMessages,
        icon: const Icon(Icons.message, size: 24),
        label: const Text(
          'Mesajlar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
