import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ble/ble_service.dart';
import '../../core/routing/app_router.dart';

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
    // Tam ekran ve koyu status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    // Listen to connection status changes
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
          content: const Text(
            'Lütfen bir mesaj yazın',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Titreşim geri bildirimi
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

      // Başarı titreşimi
      HapticFeedback.heavyImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Mesaj gönderildi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.02),
                // Bağlantı Durumu - Çok Net Metin
                ValueListenableBuilder<String>(
                  valueListenable: _bleService.status,
                  builder: (context, status, _) {
                    final isConnected = _bleService.isConnected.value;
                    final statusText = isConnected
                        ? "Gateway'e bağlısın"
                        : "Gateway'e bağlı değilsin, mesaj sıraya alındı";
                    return Column(
                      children: [
                        Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.green : Colors.white70,
                          ),
                        ),
                        if (!isConnected && !_bleService.isScanning.value)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ElevatedButton(
                              onPressed: _bleService.scanDevices,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Cihaz Ara'),
                            ),
                          ),
                        if (_bleService.isScanning.value)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Cihazlar aranıyor...',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        if (!isConnected && _bleService.results.value.isNotEmpty)
                          ..._bleService.results.value.take(3).map((result) {
                            final name = result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : result.advertisementData.advName;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: ElevatedButton(
                                onPressed: () => _bleService.connect(result),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  name.isEmpty ? 'Bilinmeyen Cihaz' : name,
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
                SizedBox(height: screenHeight * 0.06),
                // Tek Büyük SOS Gönder Butonu
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: screenWidth * 0.5,
                  height: screenWidth * 0.5,
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 280,
                    minHeight: 200,
                    maxHeight: 280,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSending ? null : () => _sendSosMessage(),
                      borderRadius: BorderRadius.circular(140),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isSending ? Colors.red.shade700 : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.6),
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
                ),
                SizedBox(height: screenHeight * 0.06),
                // 3 Hızlı Durum Butonu (İkonlu)
                _buildQuickStatusButton(
                  icon: Icons.warning,
                  label: 'Ağır yaralıyım',
                  color: Colors.red,
                  onTap: () => _sendQuickStatus('Ağır yaralıyım'),
                ),
                const SizedBox(height: 16),
                _buildQuickStatusButton(
                  icon: Icons.air,
                  label: 'Sıkıştım ama nefes alıyorum',
                  color: Colors.orange,
                  onTap: () => _sendQuickStatus('Sıkıştım ama nefes alıyorum'),
                ),
                const SizedBox(height: 16),
                _buildQuickStatusButton(
                  icon: Icons.water_drop,
                  label: 'Güvendeyim ama yardıma ihtiyacım var\n(su, yiyecek vb.)',
                  color: Colors.amber,
                  onTap: () => _sendQuickStatus('Güvendeyim ama yardıma ihtiyacım var (su, yiyecek vb.)'),
                ),
                SizedBox(height: screenHeight * 0.04),
                // Serbest Metin Kutusu (İsteğe Bağlı)
                TextField(
                  controller: _messageController,
                  enabled: !_isSending,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Örn: Nefes alamıyorum, bacağım sıkıştı',
                    hintStyle: TextStyle(
                      fontSize: 16,
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
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendSosMessage(),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Mesajlar Butonu
                SizedBox(
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}

