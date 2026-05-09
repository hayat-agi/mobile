import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/modern_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../disaster_mode/models/user_health_profile.dart';
import '../user_profile/services/vulnerable_group_service.dart';

class VulnerableGroupProfilePage extends StatefulWidget {
  const VulnerableGroupProfilePage({super.key});

  @override
  State<VulnerableGroupProfilePage> createState() =>
      _VulnerableGroupProfilePageState();
}

class _VulnerableGroupProfilePageState
    extends State<VulnerableGroupProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVulnerableGroup = false;
  AgeRange _selectedAge = AgeRange.unknown;
  Set<ChronicDisease> _selectedDiseases = {};
  Set<Medication> _selectedMeds = {};
  Set<DisabilityStatus> _selectedDisabilities = {};

  @override
  void initState() {
    super.initState();
    _loadVulnerableProfile();
  }

  Future<void> _loadVulnerableProfile() async {
    final service = VulnerableGroupService();
    await service.load();
    if (!mounted) return;

    final profile = service.profile;
    setState(() {
      _isVulnerableGroup = service.isVulnerableGroup;
      _selectedAge = profile.age;
      _selectedDiseases = Set<ChronicDisease>.from(profile.chronicDiseases);
      _selectedMeds = Set<Medication>.from(profile.medications);
      _selectedDisabilities = Set<DisabilityStatus>.from(profile.disabilities);
      _isLoading = false;
    });
  }

  Future<void> _saveHealthProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final profile = UserHealthProfile(
      hasProfile: _isVulnerableGroup,
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
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kırılgan grup profili kaydedildi.'),
        backgroundColor: AppColors.success,
      ),
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
                    (disease) => CheckboxListTile(
                      value: selected.contains(disease),
                      title: Text(_diseaseLabel(disease)),
                      onChanged: (value) {
                        setLocal(() {
                          if (value == true) {
                            selected.add(disease);
                          } else {
                            selected.remove(disease);
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
                    (medication) => CheckboxListTile(
                      value: selected.contains(medication),
                      title: Text(_medLabel(medication)),
                      onChanged: (value) {
                        setLocal(() {
                          if (value == true) {
                            selected.add(medication);
                          } else {
                            selected.remove(medication);
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
                  .where((status) => status != DisabilityStatus.none)
                  .map(
                    (status) => CheckboxListTile(
                      value: selected.contains(status),
                      title: Text(_disabilityLabel(status)),
                      onChanged: (value) {
                        setLocal(() {
                          if (value == true) {
                            selected.add(status);
                          } else {
                            selected.remove(status);
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

  String _ageLabel(AgeRange age) => const {
    AgeRange.unknown: 'Belirtilmedi',
    AgeRange.child0to9: '0-9',
    AgeRange.teen10to17: '10-17',
    AgeRange.young18to29: '18-29',
    AgeRange.adult30to44: '30-44',
    AgeRange.range45to59: '45-59',
    AgeRange.senior60to74: '60-74',
    AgeRange.elderly75plus: '75+',
  }[age]!;

  String _diseaseLabel(ChronicDisease disease) => const {
    ChronicDisease.heartDisease: 'Kalp hastalığı',
    ChronicDisease.diabetes: 'Diyabet',
    ChronicDisease.hypertension: 'Hipertansiyon',
    ChronicDisease.asthma: 'Astım',
    ChronicDisease.epilepsy: 'Epilepsi',
    ChronicDisease.renalDisease: 'Böbrek hastalığı',
    ChronicDisease.cancer: 'Kanser',
    ChronicDisease.other: 'Diğer',
  }[disease]!;

  String _medLabel(Medication medication) => const {
    Medication.bloodThinner: 'Kan sulandırıcı',
    Medication.insulin: 'İnsülin',
    Medication.heartMed: 'Kalp ilacı',
    Medication.antiepileptic: 'Epilepsi ilacı',
    Medication.immunosuppressant: 'Bağışıklık ilacı',
    Medication.painKiller: 'Ağrı kesici',
    Medication.other: 'Diğer',
  }[medication]!;

  String _disabilityLabel(DisabilityStatus status) => const {
    DisabilityStatus.none: 'Yok',
    DisabilityStatus.mobility: 'Hareket kısıtlılığı',
    DisabilityStatus.visual: 'Görme engeli',
    DisabilityStatus.hearing: 'İşitme engeli',
    DisabilityStatus.cognitive: 'Bilişsel engel',
    DisabilityStatus.other: 'Diğer',
  }[status]!;

  String _selectionSummary<T>(Set<T> selected, String Function(T) label) {
    if (selected.isEmpty) return 'Belirtilmedi';
    return selected.map(label).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kırılgan Grup Profili',
      bottomNavigationBar: const AppBottomNavBar(
        currentItem: AppNavItem.settings,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                _buildHeaderCard(context),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Sağlık Bilgileri',
                  subtitle: 'Afet modu öncelik verisi',
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isVulnerableGroup
                      ? _buildProfileForm(context)
                      : _buildInactiveCard(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Profili Kaydet',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _saveHealthProfile,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);

    return ModernCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusNav),
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Afet Önceliği', style: AppTypography.titleLarge(context)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isVulnerableGroup ? 'Aktif' : 'Kapalı',
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: _isVulnerableGroup,
            onChanged: (value) {
              setState(() => _isVulnerableGroup = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveCard(BuildContext context) {
    return ModernCard(
      key: const ValueKey('inactive'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Kırılgan grup işareti kapalı.',
              style: AppTypography.bodyMedium(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(BuildContext context) {
    return Column(
      key: const ValueKey('profile-form'),
      children: [
        DropdownButtonFormField<AgeRange>(
          initialValue: _selectedAge,
          decoration: const InputDecoration(
            labelText: 'Yaş Grubu',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          items: AgeRange.values
              .map(
                (age) =>
                    DropdownMenuItem(value: age, child: Text(_ageLabel(age))),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _selectedAge = value ?? AgeRange.unknown);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ModernCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListRow(
                title: 'Kronik Hastalıklar',
                subtitle: _selectionSummary(_selectedDiseases, _diseaseLabel),
                leading: Icon(
                  Icons.monitor_heart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: _pickDiseases,
              ),
              ListRow(
                title: 'Düzenli İlaçlar',
                subtitle: _selectionSummary(_selectedMeds, _medLabel),
                leading: Icon(
                  Icons.medication_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: _pickMedications,
              ),
              ListRow(
                title: 'Engellilik Durumu',
                subtitle: _selectionSummary(
                  _selectedDisabilities,
                  _disabilityLabel,
                ),
                leading: Icon(
                  Icons.accessible_forward_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: _pickDisabilities,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
