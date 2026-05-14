import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/auth/auth_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/section_header.dart';
import '../../services/accessibility_service.dart';

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
      if (!mounted) return;
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Ayarlar',
      bottomNavigationBar: const AppBottomNavBar(
        currentItem: AppNavItem.settings,
      ),
      body: ListView(
        children: [
          SectionHeader(title: 'Hesap', subtitle: 'Profil bilgileri'),
          _buildUserInfo(theme),
          ListRow(
            title: 'Profil Düzenle',
            leading: Icon(
              Icons.person_outline,
              color: theme.colorScheme.primary,
            ),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.profileEdit);
            },
            showDivider: false,
          ),
          const Divider(height: 1),
          SectionHeader(
            title: 'Uygulama Ayarları',
            subtitle: 'Bildirimler ve genel ayarlar',
          ),
          SwitchListTile(
            title: Text(
              'Bildirimler',
              style: AppTypography.titleMedium(context),
            ),
            subtitle: Text(
              'Cihaz durumu ve mesaj bildirimleri',
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
          ),
          const Divider(height: 1),
          SectionHeader(
            title: 'Bluetooth Ayarları',
            subtitle: 'Bağlantı ve otomatik bağlanma',
          ),
          SwitchListTile(
            title: Text(
              'Otomatik Bağlan',
              style: AppTypography.titleMedium(context),
            ),
            subtitle: Text(
              'Kayıtlı cihazlara otomatik bağlan',
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            value: _autoConnect,
            onChanged: (value) {
              setState(() {
                _autoConnect = value;
              });
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
          ),
          const Divider(height: 1),
          SectionHeader(
            title: 'Erişilebilirlik',
            subtitle: 'Görünüm ve okuma kolaylığı',
          ),
          _buildAccessibilitySection(theme),
          const Divider(height: 1),
          SectionHeader(
            title: 'Hakkında',
            subtitle: 'Uygulama bilgileri ve destek',
          ),
          ListRow(
            title: 'Uygulama Versiyonu',
            subtitle: _appVersion,
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            onTap: null,
            showDivider: false,
          ),
          const Divider(height: 1),
          ListRow(
            title: 'Kullanım Koşulları',
            leading: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.primary,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
            showDivider: false,
          ),
          const Divider(height: 1),
          ListRow(
            title: 'Gizlilik Politikası',
            leading: Icon(
              Icons.privacy_tip_outlined,
              color: theme.colorScheme.primary,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yakında eklenecek')),
              );
            },
            showDivider: false,
          ),
          const Divider(height: 1),
          ListRow(
            title: 'Yardım & Destek',
            leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.issueReport);
            },
            showDivider: false,
          ),
          const Divider(height: 1),
          ListRow(
            title: 'Çıkış Yap',
            leading: const Icon(Icons.logout, color: AppColors.danger),
            onTap: _showLogoutDialog,
            showDivider: false,
            trailing: null,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildAccessibilitySection(ThemeData theme) {
    final acc = AccessibilityService();
    return ListenableBuilder(
      listenable: acc,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark mode
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema', style: AppTypography.titleMedium(context)),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistem'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Açık'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Koyu'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {acc.themeMode},
                  onSelectionChanged: (s) => acc.setThemeMode(s.first),
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: AppSpacing.screenPadding),

          // Font scale
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yazı Boyutu', style: AppTypography.titleMedium(context)),
                const SizedBox(height: 8),
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 1.0, label: Text('Normal')),
                    ButtonSegment(value: 1.2, label: Text('Büyük')),
                    ButtonSegment(value: 1.5, label: Text('Çok Büyük')),
                  ],
                  selected: {acc.fontScale},
                  onSelectionChanged: (s) => acc.setFontScale(s.first),
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: AppSpacing.screenPadding),

          // Color blind mode
          SwitchListTile(
            title: Text(
              'Renk Körlüğü Modu',
              style: AppTypography.titleMedium(context),
            ),
            subtitle: Text(
              'Kırmızı-yeşil renk körlerine uyumlu renk filtresi',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            secondary: Icon(
              Icons.palette_outlined,
              color: theme.colorScheme.primary,
            ),
            value: acc.colorBlindMode,
            onChanged: acc.setColorBlindMode,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.xs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(ThemeData theme) {
    final user = AuthService().currentUser.value;
    if (user == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AppTypography.titleMedium(context)),
                Text(
                  user.email,
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
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
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.login,
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
