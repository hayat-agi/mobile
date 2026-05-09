import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/section_header.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/auth/auth_service.dart';
import '../../core/routing/app_router.dart';
import '../disaster_mode/models/user_health_profile.dart';
import '../user_profile/services/vulnerable_group_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoConnect = false;
  String _appVersion = '1.0.0';
  bool _isVulnerableGroup = false;
  AgeRange _selectedAge = AgeRange.unknown;
  Set<ChronicDisease> _selectedDiseases = {};
  Set<Medication> _selectedMeds = {};
  Set<DisabilityStatus> _selectedDisabilities = {};

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadVulnerableProfile();
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

  Future<void> _loadVulnerableProfile() async {
    final service = VulnerableGroupService();
    await service.load();
    if (!mounted) return;
    setState(() {
      _isVulnerableGroup = service.isVulnerableGroup;
      final p = service.profile;
      _selectedAge = p.age;
      _selectedDiseases = Set.from(p.chronicDiseases);
      _selectedMeds = Set.from(p.medications);
      _selectedDisabilities = Set.from(p.disabilities);
    });
  }

  Future<void> _saveHealthProfile() async {
    final profile = UserHealthProfile(
      hasProfile: true,
      age: _selectedAge,
      gender: Gender.unknown,
      chronicDiseases: _selectedDiseases,
      medications: _selectedMeds,
      disabilities: _selectedDisabilities,
    );
    await VulnerableGroupService().saveProfile(
      profile: profile,
      isVulnerableGroup: _isVulnerableGroup,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kırılgan grup profili kaydedildi.')),
    );
  }

  Future<void> _pickDiseases() async {
    final selected = Set<ChronicDisease>.from(_selectedDiseases);
    final result = await showDialog<Set<ChronicDisease>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Kronik Hastalıklar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ChronicDisease.values
                  .map(
                    (d) => CheckboxListTile(
                      value: selected.contains(d),
                      title: Text(_diseaseLabel(d)),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(d);
                          } else {
                            selected.remove(d);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedDiseases = result);
    }
  }

  Future<void> _pickMedications() async {
    final selected = Set<Medication>.from(_selectedMeds);
    final result = await showDialog<Set<Medication>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Düzenli İlaçlar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: Medication.values
                  .map(
                    (m) => CheckboxListTile(
                      value: selected.contains(m),
                      title: Text(_medLabel(m)),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(m);
                          } else {
                            selected.remove(m);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedMeds = result);
    }
  }

  Future<void> _pickDisabilities() async {
    final selected = Set<DisabilityStatus>.from(_selectedDisabilities);
    final result = await showDialog<Set<DisabilityStatus>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Engellilik Durumu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: DisabilityStatus.values
                  .where((d) => d != DisabilityStatus.none)
                  .map(
                    (d) => CheckboxListTile(
                      value: selected.contains(d),
                      title: Text(_disabilityLabel(d)),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(d);
                          } else {
                            selected.remove(d);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedDisabilities = result);
    }
  }

  String _ageLabel(AgeRange a) => const {
        AgeRange.unknown: 'Belirtilmedi',
        AgeRange.child0to9: '0–9',
        AgeRange.teen10to17: '10–17',
        AgeRange.young18to29: '18–29',
        AgeRange.adult30to44: '30–44',
        AgeRange.range45to59: '45–59',
        AgeRange.senior60to74: '60–74',
        AgeRange.elderly75plus: '75+',
      }[a]!;

  String _diseaseLabel(ChronicDisease d) => const {
        ChronicDisease.heartDisease: 'Kalp hastalığı',
        ChronicDisease.diabetes: 'Diyabet',
        ChronicDisease.hypertension: 'Hipertansiyon',
        ChronicDisease.asthma: 'Astım',
        ChronicDisease.epilepsy: 'Epilepsi',
        ChronicDisease.renalDisease: 'Böbrek hastalığı',
        ChronicDisease.cancer: 'Kanser',
        ChronicDisease.other: 'Diğer',
      }[d]!;

  String _medLabel(Medication m) => const {
        Medication.bloodThinner: 'Kan sulandırıcı',
        Medication.insulin: 'İnsülin',
        Medication.heartMed: 'Kalp ilacı',
        Medication.antiepileptic: 'Epilepsi ilacı',
        Medication.immunosuppressant: 'Bağışıklık ilacı',
        Medication.painKiller: 'Ağrı kesici',
        Medication.other: 'Diğer',
      }[m]!;

  String _disabilityLabel(DisabilityStatus d) => const {
        DisabilityStatus.none: 'Yok',
        DisabilityStatus.mobility: 'Hareket kısıtlılığı',
        DisabilityStatus.visual: 'Görme engeli',
        DisabilityStatus.hearing: 'İşitme engeli',
        DisabilityStatus.cognitive: 'Bilişsel engel',
        DisabilityStatus.other: 'Diğer',
      }[d]!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Ayarlar',
      body: ListView(
        children: [
          // ── Hesap ────────────────────────────────────────────────────────────
          SectionHeader(
            title: 'Hesap',
            subtitle: 'Profil ve çıkış',
          ),
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
          ListRow(
            title: 'Çıkış Yap',
            leading: const Icon(
              Icons.logout,
              color: AppColors.danger,
            ),
            onTap: _showLogoutDialog,
            showDivider: false,
            trailing: null,
          ),
          const Divider(height: 1),

          // ── Uygulama Ayarları ─────────────────────────────────────────────
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
              style: AppTypography.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

          // ── Bluetooth Ayarları ────────────────────────────────────────────
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
              style: AppTypography.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

          // ── Kırılgan Grup Profili ─────────────────────────────────────────
          SectionHeader(
            title: 'Kırılgan Grup Profili',
            subtitle: 'Afet modunda sağlık bilgisi otomatik iletimi',
          ),
          SwitchListTile(
            title: Text(
              'Kırılgan grup olarak işaretle',
              style: AppTypography.titleMedium(context),
            ),
            subtitle: Text(
              'Yaşlı, çocuk veya kronik hastalık durumu',
              style: AppTypography.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: _isVulnerableGroup,
            onChanged: (val) async {
              setState(() => _isVulnerableGroup = val);
              await VulnerableGroupService().saveProfile(
                profile: VulnerableGroupService().profile,
                isVulnerableGroup: val,
              );
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
          ),
          if (_isVulnerableGroup) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              title: Text('Yaş Grubu', style: AppTypography.titleMedium(context)),
              trailing: DropdownButton<AgeRange>(
                value: _selectedAge,
                items: AgeRange.values
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(_ageLabel(a)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedAge = val ?? AgeRange.unknown);
                },
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Kronik Hastalıklar',
                style: AppTypography.titleMedium(context),
              ),
              subtitle: Text(
                _selectedDiseases.isEmpty
                    ? 'Belirtilmedi'
                    : _selectedDiseases.map(_diseaseLabel).join(', '),
                style: AppTypography.bodySmall(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDiseases,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Düzenli İlaçlar',
                style: AppTypography.titleMedium(context),
              ),
              subtitle: Text(
                _selectedMeds.isEmpty
                    ? 'Belirtilmedi'
                    : _selectedMeds.map(_medLabel).join(', '),
                style: AppTypography.bodySmall(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickMedications,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Engellilik Durumu',
                style: AppTypography.titleMedium(context),
              ),
              subtitle: Text(
                _selectedDisabilities.isEmpty
                    ? 'Belirtilmedi'
                    : _selectedDisabilities.map(_disabilityLabel).join(', '),
                style: AppTypography.bodySmall(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDisabilities,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: ElevatedButton(
                onPressed: _saveHealthProfile,
                child: const Text('Profili Kaydet'),
              ),
            ),
          ],
          const Divider(height: 1),

          // ── Hakkında ──────────────────────────────────────────────────────
          SectionHeader(
            title: 'Hakkında',
            subtitle: 'Uygulama bilgileri ve destek',
          ),
          ListRow(
            title: 'Uygulama Versiyonu',
            subtitle: _appVersion,
            leading: Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
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
            leading: Icon(
              Icons.help_outline,
              color: theme.colorScheme.primary,
            ),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.issueReport);
            },
            showDivider: false,
          ),

          const SizedBox(height: AppSpacing.xl),
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
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: AppTypography.titleMedium(context).copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
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
                  style: AppTypography.bodySmall(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
              Navigator.pop(context); // close dialog
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
