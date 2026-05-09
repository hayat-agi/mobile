import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/gateway.dart';
import '../../models/household_member.dart';
import '../../services/gateway_service.dart';
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
  final GatewayService _gatewayService = GatewayService();
  String? _selectedGatewayId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _gatewayService.initialize();
    if (!mounted) return;

    final gateways = _gatewayService.gateways.value;
    setState(() {
      _selectedGatewayId = gateways.length == 1 ? gateways.first.id : null;
      _isLoading = false;
    });
  }

  Gateway? get _selectedGateway {
    final id = _selectedGatewayId;
    if (id == null) return null;
    return _gatewayService.gateways.value
        .cast<Gateway?>()
        .firstWhere((g) => g?.id == id, orElse: () => null);
  }

  List<HouseholdMember> get _members {
    final id = _selectedGatewayId;
    if (id == null) return [];
    return _gatewayService.getHouseholdProfile(id)?.members ?? [];
  }

  void _showMemberEditor(HouseholdMember member) async {
    final gatewayId = _selectedGatewayId!;
    final service = VulnerableGroupService();
    final (profile, isVulnerable) =
        await service.loadMemberProfile(gatewayId, member.name);

    if (!mounted) return;

    var isVulnerableLocal = isVulnerable;
    var selectedAge = profile.age;
    var selectedDiseases = Set<ChronicDisease>.from(profile.chronicDiseases);
    var selectedMeds = Set<Medication>.from(profile.medications);
    var selectedDisabilities = Set<DisabilityStatus>.from(profile.disabilities);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member header + vulnerable toggle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      member.isChild
                          ? Icons.child_care
                          : member.isElderly
                          ? Icons.elderly
                          : Icons.person,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: AppTypography.titleLarge(context),
                        ),
                        Text(
                          '${member.age} yaşında',
                          style: AppTypography.bodySmall(context).copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Kırılgan Grup',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Switch(
                        value: isVulnerableLocal,
                        onChanged: (v) => setLocal(() => isVulnerableLocal = v),
                      ),
                    ],
                  ),
                ],
              ),

              if (isVulnerableLocal) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Yaş grubu
                DropdownButtonFormField<AgeRange>(
                  initialValue: selectedAge,
                  decoration: const InputDecoration(
                    labelText: 'Yaş Grubu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: AgeRange.values
                      .map(
                        (age) => DropdownMenuItem(
                          value: age,
                          child: Text(_ageLabel(age)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => selectedAge = v ?? AgeRange.unknown),
                ),
                const SizedBox(height: 12),

                // Kronik hastalıklar
                _buildPickerRow(
                  ctx: ctx,
                  icon: Icons.monitor_heart_outlined,
                  title: 'Kronik Hastalıklar',
                  summary: _selectionSummary(selectedDiseases, _diseaseLabel),
                  onTap: () async {
                    final result = await _pickMulti<ChronicDisease>(
                      ctx,
                      'Kronik Hastalıklar',
                      ChronicDisease.values,
                      selectedDiseases,
                      _diseaseLabel,
                    );
                    if (result != null) {
                      setLocal(() => selectedDiseases = result);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Düzenli ilaçlar
                _buildPickerRow(
                  ctx: ctx,
                  icon: Icons.medication_outlined,
                  title: 'Düzenli İlaçlar',
                  summary: _selectionSummary(selectedMeds, _medLabel),
                  onTap: () async {
                    final result = await _pickMulti<Medication>(
                      ctx,
                      'Düzenli İlaçlar',
                      Medication.values,
                      selectedMeds,
                      _medLabel,
                    );
                    if (result != null) {
                      setLocal(() => selectedMeds = result);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Engellilik durumu
                _buildPickerRow(
                  ctx: ctx,
                  icon: Icons.accessible_forward_outlined,
                  title: 'Engellilik Durumu',
                  summary: _selectionSummary(
                    selectedDisabilities,
                    _disabilityLabel,
                  ),
                  onTap: () async {
                    final result = await _pickMulti<DisabilityStatus>(
                      ctx,
                      'Engellilik Durumu',
                      DisabilityStatus.values
                          .where((s) => s != DisabilityStatus.none)
                          .toList(),
                      selectedDisabilities,
                      _disabilityLabel,
                    );
                    if (result != null) {
                      setLocal(() => selectedDisabilities = result);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),

              // Kaydet butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newProfile = UserHealthProfile(
                      hasProfile: isVulnerableLocal,
                      age: selectedAge,
                      gender: Gender.unknown,
                      chronicDiseases: selectedDiseases,
                      medications: selectedMeds,
                      disabilities: selectedDisabilities,
                    );
                    await service.saveMemberProfile(
                      gatewayId,
                      member.name,
                      newProfile,
                      isVulnerableLocal,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${member.name} profili kaydedildi.',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      setState(() {}); // refresh member cards
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerRow({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String summary,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium(ctx).copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: AppTypography.bodySmall(ctx).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<Set<T>?> _pickMulti<T>(
    BuildContext ctx,
    String title,
    List<T> options,
    Set<T> current,
    String Function(T) label,
  ) {
    final selected = Set<T>.from(current);
    return showDialog<Set<T>>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (item) => CheckboxListTile(
                      value: selected.contains(item),
                      title: Text(label(item)),
                      onChanged: (v) => setDialog(() {
                        if (v == true) {
                          selected.add(item);
                        } else {
                          selected.remove(item);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, selected),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomNav = const AppBottomNavBar(currentItem: AppNavItem.settings);

    if (_isLoading) {
      return AppScaffold(
        title: 'Kırılgan Grup Profili',
        bottomNavigationBar: bottomNav,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final gateways = _gatewayService.gateways.value;

    if (gateways.isEmpty) {
      return AppScaffold(
        title: 'Kırılgan Grup Profili',
        bottomNavigationBar: bottomNav,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.device_unknown_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cihaz bulunamadı',
                  style: AppTypography.titleLarge(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kırılgan grup profili oluşturmak için önce bir cihaz ekleyin.',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Gateway selection screen
    if (_selectedGatewayId == null) {
      return AppScaffold(
        title: 'Cihaz Seç',
        bottomNavigationBar: bottomNav,
        body: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          itemCount: gateways.length + 1,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cihaz seç',
                      style: AppTypography.headlineSmall(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Kırılgan grup bilgileri seçtiğiniz cihaza bağlı hane üyelerine göre düzenlenir.',
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            final gw = gateways[i - 1];
            return ModernCard(
              onTap: () => setState(() => _selectedGatewayId = gw.id),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusNav),
                    ),
                    child: const Icon(
                      Icons.memory,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      gw.name,
                      style: AppTypography.titleLarge(context),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final gateway = _selectedGateway!;
    final members = _members;

    return AppScaffold(
      title: 'Kırılgan Grup Profili',
      bottomNavigationBar: bottomNav,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Seçili cihaz
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seçili Cihaz',
                style: AppTypography.bodySmall(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ModernCard(
                onTap: gateways.length > 1
                    ? () => setState(() => _selectedGatewayId = null)
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.memory,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        gateway.name,
                        style: AppTypography.titleMedium(context),
                      ),
                    ),
                    if (gateways.length > 1)
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Üye listesi
          Text(
            'Hane Üyeleri',
            style: AppTypography.titleLarge(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (members.isEmpty)
            ModernCard(
              child: Column(
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bu cihaza henüz hane üyesi eklenmemiş.',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/household-profile',
                    ),
                    icon: const Icon(Icons.family_restroom),
                    label: const Text('Hane Profiline Git'),
                  ),
                ],
              ),
            )
          else
            ...members.map((member) => _buildMemberCard(member)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(HouseholdMember member) {
    return FutureBuilder<(UserHealthProfile, bool)>(
      future: VulnerableGroupService().loadMemberProfile(
        _selectedGatewayId!,
        member.name,
      ),
      builder: (context, snapshot) {
        final isVulnerable = snapshot.data?.$2 ?? false;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ModernCard(
            onTap: () => _showMemberEditor(member),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (member.isChild || member.isElderly
                            ? Colors.orange
                            : AppColors.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    member.isChild
                        ? Icons.child_care
                        : member.isElderly
                        ? Icons.elderly
                        : Icons.person,
                    color: member.isChild || member.isElderly
                        ? Colors.orange
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: AppTypography.titleMedium(context),
                      ),
                      Text(
                        '${member.age} yaşında',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVulnerable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Kırılgan',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Label helpers ─────────────────────────────────────────────────────────

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

  String _disabilityLabel(DisabilityStatus s) => const {
    DisabilityStatus.none: 'Yok',
    DisabilityStatus.mobility: 'Hareket kısıtlılığı',
    DisabilityStatus.visual: 'Görme engeli',
    DisabilityStatus.hearing: 'İşitme engeli',
    DisabilityStatus.cognitive: 'Bilişsel engel',
    DisabilityStatus.other: 'Diğer',
  }[s]!;

  String _selectionSummary<T>(Set<T> selected, String Function(T) label) {
    if (selected.isEmpty) return 'Belirtilmedi';
    return selected.map(label).join(', ');
  }
}
