import 'dart:async';

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
import '../earthquake_detection/earthquake_detection_service.dart';
import '../earthquake_detection/earthquake_debug_info.dart';
import '../earthquake_detection/earthquake_config.dart';
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
          // App Settings Section
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
              'Gateway durumu ve mesaj bildirimleri',
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

          // Bluetooth Settings Section
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
              'Kayıtlı gateway\'lere otomatik bağlan',
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

          // About Section
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
          const Divider(height: 1),

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

          // Account Section
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
          // Developer Test Section
          SectionHeader(
            title: 'Geliştirici Testi',
            subtitle: 'Deprem algılama algoritmasını test et',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: EarthquakeDetectionService().isReplaying,
            builder: (context, replaying, _) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                  vertical: AppSpacing.sm,
                ),
                leading: Icon(
                  Icons.science_outlined,
                  color: replaying
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
                title: Text(
                  replaying ? 'Simülasyon Çalışıyor...' : 'Deprem Simülasyonu Başlat',
                  style: AppTypography.titleMedium(context).copyWith(
                    color: replaying ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
                subtitle: Text(
                  replaying
                      ? 'Deprem alarmı ~30 saniye içinde tetiklenecek'
                      : 'Gerçek sismik veri ile alarm akışını test eder',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: replaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                onTap: replaying
                    ? null
                    : () {
                        EarthquakeDetectionService().startReplay(
                          'assets/fixtures/earthquake/TK_3139__3c_25hz.csv',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Simülasyon başladı — ~30 saniye içinde alarm tetiklenecek',
                            ),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            leading: Icon(
              Icons.back_hand_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              'El Sallama Testi',
              style: AppTypography.titleMedium(context),
            ),
            subtitle: Text(
              'Yanlış alarm korumasını gerçek zamanlı doğrula',
              style: AppTypography.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            onTap: _startHandShakeTest,
          ),
          const Divider(height: 1),

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

  void _startHandShakeTest() {
    final service = EarthquakeDetectionService();
    service.debugForceFeatures = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HandShakeTestSheet(service: service),
    ).whenComplete(() {
      service.debugForceFeatures = false;
    });
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

// ── Hand-Shake Test Bottom Sheet ─────────────────────────────────────────────

class _HandShakeTestSheet extends StatefulWidget {
  const _HandShakeTestSheet({required this.service});
  final EarthquakeDetectionService service;

  @override
  State<_HandShakeTestSheet> createState() => _HandShakeTestSheetState();
}

class _HandShakeTestSheetState extends State<_HandShakeTestSheet> {
  EarthquakeDebugInfo? _latest;
  StreamSubscription<EarthquakeDebugInfo>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.debugStream.listen((info) {
      if (mounted) setState(() => _latest = info);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _metricRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isGood
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isGood ? 'İYİ' : 'UYARI',
              style: TextStyle(
                color: isGood ? Colors.green.shade700 : Colors.red.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _blockReasonLabel(EarthquakeBlockReason? reason) {
    if (reason == null) return 'YOK (Layer 2 çalıştı)';
    switch (reason) {
      case EarthquakeBlockReason.stationarity:
        return 'Durağanlık ✓';
      case EarthquakeBlockReason.gyroscope:
        return 'Jiroskop ✓';
      case EarthquakeBlockReason.triggerGate:
        return 'Tetik kapısı ✓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _latest;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.70,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title + subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El Sallama Testi',
                    style: AppTypography.titleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Telefonu sallayın — filtreler doğruysa tüm metrikler FAIL göstermeli',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Content
            Expanded(
              child: info == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Sallayın veya dokunun\u2026',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Block reason row
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Engel',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _blockReasonLabel(info.blockReason),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: info.blockReason == null
                                              ? Colors.amber.shade700
                                              : Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 12),
                              // STA/LTA row
                              _metricRow(
                                'STA/LTA',
                                '${info.staLtaRatio.toStringAsFixed(3)}  (eşik: ${EarthquakeConfig.staLtaTriggerThreshold})',
                                info.staLtaRatio < EarthquakeConfig.staLtaTriggerThreshold,
                              ),
                              if (info.features != null) ...[
                                const Divider(height: 12),
                                _metricRow(
                                  'IQR',
                                  '${info.features!.iqr.toStringAsFixed(4)}  (eşik: ${EarthquakeConfig.iqrThreshold})',
                                  info.features!.iqr < EarthquakeConfig.iqrThreshold,
                                ),
                                _metricRow(
                                  'ZC Oranı',
                                  '${info.features!.zeroCrossingRate.toStringAsFixed(3)} Hz  (eşik: ${EarthquakeConfig.zcThreshold})',
                                  info.features!.zeroCrossingRate < EarthquakeConfig.zcThreshold,
                                ),
                                _metricRow(
                                  'CAV',
                                  '${info.features!.cav.toStringAsFixed(4)} m/s\u00b2\u00b7s  (eşik: ${EarthquakeConfig.cavThreshold})',
                                  info.features!.cav < EarthquakeConfig.cavThreshold,
                                ),
                                _metricRow(
                                  'Kurtosis',
                                  '${info.features!.kurtosis.toStringAsFixed(2)}  (eşik: ${EarthquakeConfig.kurtosisVoteThreshold})',
                                  info.features!.kurtosis >= EarthquakeConfig.kurtosisVoteThreshold,
                                ),
                                const Divider(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Sonuç',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          info.features!.isEarthquake
                                              ? 'DEPREM'
                                              : 'İnsan hareketi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: info.features!.isEarthquake
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            // Close button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
