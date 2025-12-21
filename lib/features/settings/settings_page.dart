import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoConnect = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        children: [
          // App Settings Section
          _buildSectionHeader('Uygulama Ayarları'),
          SwitchListTile(
            title: const Text('Bildirimler'),
            subtitle: const Text('Gateway durumu ve mesaj bildirimleri'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          const Divider(),

          // Bluetooth Settings Section
          _buildSectionHeader('Bluetooth Ayarları'),
          SwitchListTile(
            title: const Text('Otomatik Bağlan'),
            subtitle: const Text('Kayıtlı gateway\'lere otomatik bağlan'),
            value: _autoConnect,
            onChanged: (value) {
              setState(() {
                _autoConnect = value;
              });
            },
          ),
          const Divider(),

          // About Section
          _buildSectionHeader('Hakkında'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Uygulama Versiyonu'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Kullanım Koşulları'),
            onTap: () {
              // TODO: Show terms
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik Politikası'),
            onTap: () {
              // TODO: Show privacy policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Yardım & Destek'),
            onTap: () {
              // TODO: Show help
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
          ),
          const Divider(),

          // Account Section
          _buildSectionHeader('Hesap'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profil'),
            onTap: () {
              // TODO: Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
            onTap: () {
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement logout
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Çıkış yapıldı')),
              );
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

