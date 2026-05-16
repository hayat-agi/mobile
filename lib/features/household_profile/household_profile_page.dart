import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/household_profile.dart';
import '../../models/household_member.dart';
import '../../models/pet.dart';
import '../../models/emergency_contact.dart';
import '../../models/gateway.dart';
import '../../services/gateway_service.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/api/household_sync_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/modern_card.dart';
import '../disaster_mode/models/user_health_profile.dart';
import '../user_profile/services/vulnerable_group_service.dart';

class HouseholdProfilePage extends StatefulWidget {
  final String? gatewayId;

  const HouseholdProfilePage({super.key, required this.gatewayId});

  @override
  State<HouseholdProfilePage> createState() => _HouseholdProfilePageState();
}

class _HouseholdProfilePageState extends State<HouseholdProfilePage> {
  final GatewayService _gatewayService = GatewayService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _memberMedicalConditionController =
      TextEditingController();
  final TextEditingController _memberSpecialNeedController =
      TextEditingController();

  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _petTypeController = TextEditingController();
  final TextEditingController _petSpecialNeedsController =
      TextEditingController();

  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactRelationshipController =
      TextEditingController();

  List<HouseholdMember> _members = [];
  List<Pet> _pets = [];
  List<EmergencyContact> _emergencyContacts = [];
  String? _selectedGatewayId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _gatewayService.initialize();
    if (!mounted) return;

    final gateways = _gatewayService.gateways.value;
    final requestedGatewayId = widget.gatewayId;
    final selectedGatewayId =
        requestedGatewayId != null &&
            gateways.any((gateway) => gateway.id == requestedGatewayId)
        ? requestedGatewayId
        : gateways.length == 1
        ? gateways.first.id
        : null;

    setState(() {
      _selectedGatewayId = selectedGatewayId;
      _applyProfile(selectedGatewayId);
      _isLoading = false;
    });
  }

  void _applyProfile(String? gatewayId) {
    _members = [];
    _pets = [];
    _emergencyContacts = [];

    if (gatewayId == null) return;

    final profile = _gatewayService.getHouseholdProfile(gatewayId);
    if (profile != null) {
      _members = List<HouseholdMember>.from(profile.members);
      _pets = List<Pet>.from(profile.pets);
      _emergencyContacts = List<EmergencyContact>.from(
        profile.emergencyContacts,
      );
    }
  }

  void _selectGateway(String gatewayId) {
    setState(() {
      _selectedGatewayId = gatewayId;
      _applyProfile(gatewayId);
      _memberMedicalConditionController.clear();
      _memberSpecialNeedController.clear();
      _petNameController.clear();
      _petTypeController.clear();
      _petSpecialNeedsController.clear();
      _contactNameController.clear();
      _contactPhoneController.clear();
      _contactRelationshipController.clear();
    });
  }

  void _clearSelectedGateway() {
    setState(() {
      _selectedGatewayId = null;
      _applyProfile(null);
      _memberMedicalConditionController.clear();
      _memberSpecialNeedController.clear();
      _petNameController.clear();
      _petTypeController.clear();
      _petSpecialNeedsController.clear();
      _contactNameController.clear();
      _contactPhoneController.clear();
      _contactRelationshipController.clear();
    });
  }

  Gateway? _selectedGateway(List<Gateway> gateways) {
    final selectedId = _selectedGatewayId;
    if (selectedId == null) return null;
    for (final gateway in gateways) {
      if (gateway.id == selectedId) return gateway;
    }
    return null;
  }

  @override
  void dispose() {
    _memberMedicalConditionController.dispose();
    _memberSpecialNeedController.dispose();
    _petNameController.dispose();
    _petTypeController.dispose();
    _petSpecialNeedsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationshipController.dispose();
    super.dispose();
  }

  void _removeMember(int index) {
    setState(() {
      _members.removeAt(index);
    });
  }

  void _addMedicalConditionToMember(int memberIndex) {
    final condition = _memberMedicalConditionController.text.trim();
    if (condition.isNotEmpty) {
      setState(() {
        final member = _members[memberIndex];
        if (!member.medicalConditions.contains(condition)) {
          final updatedConditions = [...member.medicalConditions, condition];
          _members[memberIndex] = member.copyWith(
            medicalConditions: updatedConditions,
          );
        }
        _memberMedicalConditionController.clear();
      });
    }
  }

  void _removeMedicalConditionFromMember(int memberIndex, String condition) {
    setState(() {
      final member = _members[memberIndex];
      final updatedConditions = List<String>.from(member.medicalConditions)
        ..remove(condition);
      _members[memberIndex] = member.copyWith(
        medicalConditions: updatedConditions,
      );
    });
  }

  void _addSpecialNeedToMember(int memberIndex) {
    final need = _memberSpecialNeedController.text.trim();
    if (need.isNotEmpty) {
      setState(() {
        final member = _members[memberIndex];
        if (!member.specialNeeds.contains(need)) {
          final updatedNeeds = [...member.specialNeeds, need];
          _members[memberIndex] = member.copyWith(specialNeeds: updatedNeeds);
        }
        _memberSpecialNeedController.clear();
      });
    }
  }

  void _removeSpecialNeedFromMember(int memberIndex, String need) {
    setState(() {
      final member = _members[memberIndex];
      final updatedNeeds = List<String>.from(member.specialNeeds)..remove(need);
      _members[memberIndex] = member.copyWith(specialNeeds: updatedNeeds);
    });
  }

  void _addPet() {
    final name = _petNameController.text.trim();
    final type = _petTypeController.text.trim();

    if (name.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen evcil hayvan adı ve tipini girin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _pets.add(
        Pet(
          name: name,
          type: type,
          specialNeeds: _petSpecialNeedsController.text.trim().isEmpty
              ? null
              : _petSpecialNeedsController.text.trim(),
        ),
      );
      _petNameController.clear();
      _petTypeController.clear();
      _petSpecialNeedsController.clear();
    });
  }

  void _removePet(int index) {
    setState(() {
      _pets.removeAt(index);
    });
  }

  void _addEmergencyContact() {
    final name = _contactNameController.text.trim();
    final phone = _contactPhoneController.text.trim();
    final relationship = _contactRelationshipController.text.trim();

    if (name.isEmpty || phone.isEmpty || relationship.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen tüm alanları doldurun'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _emergencyContacts.add(
        EmergencyContact(name: name, phone: phone, relationship: relationship),
      );
      _contactNameController.clear();
      _contactPhoneController.clear();
      _contactRelationshipController.clear();
    });
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    final gatewayId = _selectedGatewayId;
    if (gatewayId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Önce bir cihaz ekleyin'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final profile = HouseholdProfile(
      gatewayId: gatewayId,
      members: _members,
      pets: _pets,
      emergencyContacts: _emergencyContacts,
    );

    await _gatewayService.saveHouseholdProfile(profile);

    if (AuthService().authState.value == AuthState.authenticated) {
      final synced = await HouseholdSyncService().syncHousehold(
        gatewayId: gatewayId,
        members: _members,
        pets: _pets,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced
                  ? 'Profil kaydedildi ve senkronize edildi'
                  : 'Profil kaydedildi (senkronizasyon başarısız)',
            ),
            backgroundColor: synced ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomNav = AppBottomNavBar(
      currentItem: AppNavItem.householdProfile,
      householdGatewayId: _selectedGatewayId,
    );

    if (_isLoading) {
      return AppScaffold(
        title: 'Hane Profili',
        bottomNavigationBar: bottomNav,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final gateways = _gatewayService.gateways.value;
    if (gateways.isEmpty) {
      return AppScaffold(
        title: 'Hane Profili',
        bottomNavigationBar: bottomNav,
        body: EmptyState(
          icon: Icons.family_restroom,
          title: 'Hane profili için cihaz gerekli',
          description: 'Hane bilgileri bir cihaz profiline bağlı tutulur.',
          actionLabel: 'Ana Sayfaya Git',
          onAction: () {
            Navigator.pushReplacementNamed(context, AppRouter.dashboard);
          },
        ),
      );
    }

    final selectedGateway = _selectedGateway(gateways);
    if (selectedGateway == null) {
      return AppScaffold(
        title: 'Cihaz Seç',
        bottomNavigationBar: bottomNav,
        body: _buildGatewaySelection(gateways),
      );
    }

    return AppScaffold(
      title: 'Hane Profili',
      bottomNavigationBar: bottomNav,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceCard(selectedGateway, gateways.length),
              const SizedBox(height: 28),

              _buildSectionHeader(
                'Hane Üyeleri',
                () => _showAddMemberSheet(context),
              ),
              const SizedBox(height: 12),
              if (_members.isEmpty)
                _buildEmptyCard(
                  icon: Icons.person_outline,
                  message: 'Henüz hane üyesi eklenmedi.',
                )
              else
                ..._members.asMap().entries.map(
                  (e) => _buildMemberCard(e.value, e.key),
                ),
              const SizedBox(height: 28),

              _buildSectionHeader(
                'Evcil Hayvanlar',
                () => _showAddPetSheet(context),
              ),
              const SizedBox(height: 12),
              if (_pets.isEmpty)
                _buildEmptyCard(
                  icon: Icons.favorite_outline,
                  message: 'Kedi, köpek veya diğer dostlarınızı ekleyin.',
                )
              else
                ..._pets.asMap().entries.map(
                  (e) => _buildPetCard(e.value, e.key),
                ),
              const SizedBox(height: 28),

              _buildSectionHeader(
                'Acil Durum İletişimleri',
                () => _showAddContactSheet(context),
              ),
              const SizedBox(height: 12),
              if (_emergencyContacts.isEmpty)
                _buildEmptyCard(
                  icon: Icons.phone_outlined,
                  message: 'Güvendiğiniz bir yakın bilgisi ekleyin.',
                )
              else
                ..._emergencyContacts.asMap().entries.map(
                  (e) => _buildContactCard(e.value, e.key),
                ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.check),
                  label: const Text('Profili Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Gateway gateway, int gatewayCount) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seçili Cihaz',
          style: AppTypography.bodySmall(context).copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ModernCard(
          onTap: gatewayCount > 1 ? _clearSelectedGateway : null,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.memory, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gateway.name,
                  style: AppTypography.titleMedium(context),
                ),
              ),
              if (gatewayCount > 1)
                Icon(
                  Icons.keyboard_arrow_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleLarge(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GestureDetector(
          onTap: onAdd,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ekle',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard({required IconData icon, required String message}) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(color: theme.colorScheme.outlineVariant),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 32),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddMemberSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_MemberAddResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMemberSheet(existingMembers: _members),
    );

    if (result == null || !mounted) return;

    setState(() {
      _members.add(
        HouseholdMember(
          name: result.name,
          birthDate: result.birthDate,
          gender: result.gender,
          tcNumber: result.tcNumber,
          bloodType: result.bloodType,
          prosthetics: result.prosthetics.isEmpty ? null : result.prosthetics.toList(),
          morningLocation: result.morningLocation,
          noonLocation: result.noonLocation,
          eveningLocation: result.eveningLocation,
          medicalConditions: [
            for (final d in result.diseases)
              if (d == ChronicDisease.other)
                result.otherDiseaseText.isNotEmpty
                    ? 'Diğer: ${result.otherDiseaseText}'
                    : 'Diğer'
              else
                _diseaseLabel(d),
          ],
          specialNeeds: [
            for (final d in result.disabilities)
              if (d == DisabilityStatus.other)
                result.otherDisabilityText.isNotEmpty
                    ? 'Diğer: ${result.otherDisabilityText}'
                    : 'Diğer'
              else
                _disabilityLabel(d),
          ],
        ),
      );
    });

    if (result.hasHealthData && _selectedGatewayId != null) {
      final healthProfile = UserHealthProfile(
        hasProfile: true,
        age: _ageRangeFromBirthDate(result.birthDate),
        gender: _genderFromString(result.gender),
        chronicDiseases: result.diseases,
        medications: result.medications,
        disabilities: result.disabilities,
      );
      await VulnerableGroupService().saveMemberProfile(
        _selectedGatewayId!,
        result.name,
        healthProfile,
        true,
      );
    }
  }

  void _showAddPetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evcil Hayvan Ekle', style: AppTypography.titleLarge(context)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _petNameController,
              decoration: const InputDecoration(
                labelText: 'İsim',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _petTypeController,
              decoration: const InputDecoration(
                labelText: 'Tip',
                hintText: 'Köpek, Kedi, vb.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _petSpecialNeedsController,
              decoration: const InputDecoration(
                labelText: 'Özel İhtiyaçlar (opsiyonel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final before = _pets.length;
                  _addPet();
                  if (_pets.length > before) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Ekle'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acil İletişim Ekle',
              style: AppTypography.titleLarge(context),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'İsim',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactRelationshipController,
              decoration: const InputDecoration(
                labelText: 'İlişki',
                hintText: 'Örn: Eş, Kardeş',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final before = _emergencyContacts.length;
                  _addEmergencyContact();
                  if (_emergencyContacts.length > before) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Ekle'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewaySelection(List<Gateway> gateways) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: gateways.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cihaz seç', style: AppTypography.headlineSmall(context)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hane bilgileri seçtiğiniz cihaza kaydedilir.',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _buildGatewayChoiceCard(gateways[index - 1]);
      },
    );
  }

  Widget _buildGatewayChoiceCard(Gateway gateway) {
    final theme = Theme.of(context);

    return ModernCard(
      onTap: () => _selectGateway(gateway.id),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusNav),
            ),
            child: Icon(
              Icons.router_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              gateway.name,
              style: AppTypography.titleLarge(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildMemberCard(HouseholdMember member, int index) {
    final hasLocations = member.morningLocation != null ||
        member.noonLocation != null ||
        member.eveningLocation != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          member.isChild
              ? Icons.child_care
              : member.isElderly
              ? Icons.elderly
              : Icons.person,
          color: member.isChild || member.isElderly ? Colors.orange : AppColors.primary,
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text('${member.age} yaşında'),
            if (hasLocations) ...[
              const SizedBox(width: 8),
              Icon(Icons.location_on, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
              Text(
                'Konum kayıtlı',
                style: TextStyle(fontSize: 12, color: AppColors.primary.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.danger),
          onPressed: () => _removeMember(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLocations) ...[
                  const Text(
                    'Günlük Konumlar:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (member.morningLocation != null)
                    _buildLocationRow(Icons.wb_sunny_outlined, 'Sabah', member.morningLocation!),
                  if (member.noonLocation != null)
                    _buildLocationRow(Icons.wb_cloudy_outlined, 'Öğlen', member.noonLocation!),
                  if (member.eveningLocation != null)
                    _buildLocationRow(Icons.nights_stay_outlined, 'Akşam', member.eveningLocation!),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Tıbbi Durumlar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _memberMedicalConditionController,
                        decoration: const InputDecoration(
                          labelText: 'Tıbbi Durum Ekle',
                          hintText: 'Örn: Diyabet',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _addMedicalConditionToMember(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 20),
                      onPressed: () => _addMedicalConditionToMember(index),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                if (member.medicalConditions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: member.medicalConditions.map((condition) {
                      return Chip(
                        label: Text(
                          condition,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () =>
                            _removeMedicalConditionFromMember(index, condition),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Özel İhtiyaçlar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _memberSpecialNeedController,
                        decoration: const InputDecoration(
                          labelText: 'Özel İhtiyaç Ekle',
                          hintText: 'Örn: Tekerlekli sandalye',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _addSpecialNeedToMember(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 20),
                      onPressed: () => _addSpecialNeedToMember(index),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                if (member.specialNeeds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: member.specialNeeds.map((need) {
                      return Chip(
                        label: Text(need, style: const TextStyle(fontSize: 12)),
                        onDeleted: () =>
                            _removeSpecialNeedFromMember(index, need),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(address, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Pet pet, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.pets, color: AppColors.primary),
        title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          pet.specialNeeds != null
              ? '${pet.type} · ${pet.specialNeeds}'
              : pet.type,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.danger),
          onPressed: () => _removePet(index),
        ),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.contact_phone, color: AppColors.primary),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${contact.relationship} · ${contact.phone}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppColors.danger),
          onPressed: () => _removeEmergencyContact(index),
        ),
      ),
    );
  }
}

// ── Add Member Sheet ──────────────────────────────────────────────────────────

const _kBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];

const _kDeviceOptions = [
  'Tekerlekli sandalye',
  'İşitme cihazı',
  'Baston / yürüteç',
  'Protez uzuv',
  'Oksijen tüpü',
  'Diyaliz cihazı',
  'Görme yardımcısı',
  'Diğer',
];

class _MemberAddResult {
  final String name;
  final String birthDate;
  final String? gender;
  final String? tcNumber;
  final String? bloodType;
  final Set<String> prosthetics;
  final String? morningLocation;
  final String? noonLocation;
  final String? eveningLocation;
  final bool hasHealthData;
  final Set<ChronicDisease> diseases;
  final Set<Medication> medications;
  final Set<DisabilityStatus> disabilities;
  final String otherDiseaseText;
  final String otherMedText;
  final String otherDisabilityText;

  _MemberAddResult({
    required this.name,
    required this.birthDate,
    this.gender,
    this.tcNumber,
    this.bloodType,
    this.prosthetics = const {},
    this.morningLocation,
    this.noonLocation,
    this.eveningLocation,
    required this.hasHealthData,
    required this.diseases,
    required this.medications,
    required this.disabilities,
    this.otherDiseaseText = '',
    this.otherMedText = '',
    this.otherDisabilityText = '',
  });
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.existingMembers});
  final List<HouseholdMember> existingMembers;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _nameController = TextEditingController();
  final _tcController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  String? _bloodType;
  var _prosthetics = <String>{};
  bool _isResponsible = false;
  final _morningController = TextEditingController();
  final _noonController = TextEditingController();
  final _eveningController = TextEditingController();
  final _otherDiseaseController = TextEditingController();
  final _otherMedController = TextEditingController();
  final _otherDisabilityController = TextEditingController();
  var _diseases = <ChronicDisease>{};
  var _medications = <Medication>{};
  var _disabilities = <DisabilityStatus>{};

  @override
  void dispose() {
    _nameController.dispose();
    _tcController.dispose();
    _morningController.dispose();
    _noonController.dispose();
    _eveningController.dispose();
    _otherDiseaseController.dispose();
    _otherMedController.dispose();
    _otherDisabilityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('İsim ve doğum tarihi gerekli'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final tc = _tcController.text.trim();

    // TC format check
    if (tc.isNotEmpty && tc.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TC kimlik numarası 11 haneli olmalıdır'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // TC duplicate check
    if (tc.isNotEmpty &&
        widget.existingMembers.any(
          (m) => m.tcNumber != null && m.tcNumber == tc,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bu TC kimlik numarası ($tc) zaten kayıtlı'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Name duplicate check (case-insensitive)
    if (widget.existingMembers.any(
      (m) => m.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" adında bir üye zaten mevcut'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final hasHealthData = _diseases.isNotEmpty ||
        _medications.isNotEmpty ||
        _disabilities.isNotEmpty;
    Navigator.pop(
      context,
      _MemberAddResult(
        name: name,
        birthDate: _isoDate(_birthDate!),
        gender: _gender,
        tcNumber: tc.isNotEmpty ? tc : null,
        bloodType: _bloodType,
        prosthetics: _prosthetics,
        morningLocation: _isResponsible && _morningController.text.trim().isNotEmpty
            ? _morningController.text.trim()
            : null,
        noonLocation: _isResponsible && _noonController.text.trim().isNotEmpty
            ? _noonController.text.trim()
            : null,
        eveningLocation: _isResponsible && _eveningController.text.trim().isNotEmpty
            ? _eveningController.text.trim()
            : null,
        hasHealthData: hasHealthData,
        diseases: _diseases,
        medications: _medications,
        disabilities: _disabilities,
        otherDiseaseText: _diseases.contains(ChronicDisease.other)
            ? _otherDiseaseController.text.trim()
            : '',
        otherMedText: _medications.contains(Medication.other)
            ? _otherMedController.text.trim()
            : '',
        otherDisabilityText: _disabilities.contains(DisabilityStatus.other)
            ? _otherDisabilityController.text.trim()
            : '',
      ),
    );
  }

  Future<Set<T>?> _pickMulti<T>(
    String title,
    List<T> options,
    Set<T> current,
    String Function(T) label, {
    TextEditingController? otherController,
  }) {
    final selected = Set<T>.from(current);
    return showDialog<Set<T>>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (item) {
                      final isOther = label(item) == 'Diğer';
                      final isSelected = selected.contains(item);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CheckboxListTile(
                            value: isSelected,
                            title: Text(label(item)),
                            onChanged: (v) => setDialog(() {
                              if (v == true) {
                                selected.add(item);
                              } else {
                                selected.remove(item);
                              }
                            }),
                          ),
                          if (isOther && isSelected && otherController != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 8,
                              ),
                              child: TextField(
                                controller: otherController,
                                decoration: const InputDecoration(
                                  hintText: 'Belirtiniz...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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

  Widget _buildPickerRow({
    required IconData icon,
    required String title,
    required String summary,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
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
                  Text(
                    title,
                    style: AppTypography.bodyMedium(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: AppTypography.bodySmall(context).copyWith(
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

  String _selectionSummary<T>(Set<T> selected, String Function(T) label) {
    if (selected.isEmpty) return 'Belirtilmedi';
    return selected.map(label).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Hane Üyesi Ekle', style: AppTypography.titleLarge(context)),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'İsim',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Gender (Cinsiyet)
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Cinsiyet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Erkek')),
                  DropdownMenuItem(value: 'female', child: Text('Kadın')),
                  DropdownMenuItem(value: 'unspecified', child: Text('Belirtmek İstemiyorum')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),

              // TC Kimlik No
              TextFormField(
                controller: _tcController,
                decoration: const InputDecoration(
                  labelText: 'TC Kimlik Numarası',
                  hintText: '11 haneli benzersiz TC kimlik numarası (opsiyonel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Birth date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Doğum Tarihi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _birthDate != null
                        ? _formatDate(_birthDate!)
                        : 'Seçiniz',
                    style: _birthDate != null
                        ? null
                        : TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Blood type (Kan Grubu)
              DropdownButtonFormField<String>(
                value: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Kan Grubu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                items: _kBloodTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _bloodType = v),
              ),
              const SizedBox(height: 24),

              // Health section header
              Row(
                children: [
                  const Icon(Icons.health_and_safety_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sağlık Bilgileri',
                    style: AppTypography.titleMedium(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(İsteğe Bağlı)',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildPickerRow(
                icon: Icons.monitor_heart_outlined,
                title: 'Rahatsızlıklar',
                summary: _selectionSummary(
                  _diseases,
                  (d) => d == ChronicDisease.other &&
                          _otherDiseaseController.text.isNotEmpty
                      ? 'Diğer: ${_otherDiseaseController.text}'
                      : _diseaseLabel(d),
                ),
                onTap: () async {
                  final result = await _pickMulti(
                    'Rahatsızlıklar',
                    ChronicDisease.values,
                    _diseases,
                    _diseaseLabel,
                    otherController: _otherDiseaseController,
                  );
                  if (result != null) setState(() => _diseases = result);
                },
              ),
              const SizedBox(height: 8),

              _buildPickerRow(
                icon: Icons.medication_outlined,
                title: 'Kullandığı İlaçlar',
                summary: _selectionSummary(
                  _medications,
                  (m) => m == Medication.other &&
                          _otherMedController.text.isNotEmpty
                      ? 'Diğer: ${_otherMedController.text}'
                      : _medLabel(m),
                ),
                onTap: () async {
                  final result = await _pickMulti(
                    'Kullandığı İlaçlar',
                    Medication.values,
                    _medications,
                    _medLabel,
                    otherController: _otherMedController,
                  );
                  if (result != null) setState(() => _medications = result);
                },
              ),
              const SizedBox(height: 8),

              _buildPickerRow(
                icon: Icons.accessible_forward_outlined,
                title: 'Engellilik Durumu',
                summary: _selectionSummary(
                  _disabilities,
                  (s) => s == DisabilityStatus.other &&
                          _otherDisabilityController.text.isNotEmpty
                      ? 'Diğer: ${_otherDisabilityController.text}'
                      : _disabilityLabel(s),
                ),
                onTap: () async {
                  final result = await _pickMulti(
                    'Engellilik Durumu',
                    DisabilityStatus.values
                        .where((s) => s != DisabilityStatus.none)
                        .toList(),
                    _disabilities,
                    _disabilityLabel,
                    otherController: _otherDisabilityController,
                  );
                  if (result != null) setState(() => _disabilities = result);
                },
              ),
              const SizedBox(height: 8),

              _buildPickerRow(
                icon: Icons.medical_services_outlined,
                title: 'Kullandığı Protez / Cihazlar',
                summary: _prosthetics.isEmpty
                    ? 'Belirtilmedi'
                    : _prosthetics.join(', '),
                onTap: () async {
                  final result = await _pickMulti<String>(
                    'Kullandığı Protez / Cihazlar',
                    _kDeviceOptions,
                    _prosthetics,
                    (s) => s,
                  );
                  if (result != null) setState(() => _prosthetics = result);
                },
              ),
              const SizedBox(height: 24),

              // "Bakmakla yükümlüyüm" button
              InkWell(
                onTap: () => setState(() => _isResponsible = !_isResponsible),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isResponsible
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: _isResponsible
                          ? AppColors.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        color: _isResponsible
                            ? AppColors.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bakmakla Yükümlüyüm',
                              style: AppTypography.bodyMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: _isResponsible
                                    ? AppColors.primary
                                    : null,
                              ),
                            ),
                            Text(
                              'Telefonu olmayan yaşlı veya çocuk için konum bilgisi ekle',
                              style: AppTypography.bodySmall(context).copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isResponsible
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // Location fields (shown when responsible)
              if (_isResponsible) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genellikle Bulunduğu Konumlar',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _morningController,
                        decoration: const InputDecoration(
                          labelText: 'Sabah Konumu',
                          hintText: 'Örn: Ev — Bağcılar Cad. No:5',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.wb_sunny_outlined),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _noonController,
                        decoration: const InputDecoration(
                          labelText: 'Öğlen Konumu',
                          hintText: 'Örn: Okul — Atatürk İlkokulu',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.wb_cloudy_outlined),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _eveningController,
                        decoration: const InputDecoration(
                          labelText: 'Akşam Konumu',
                          hintText: 'Örn: Ev — Bağcılar Cad. No:5',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.nights_stay_outlined),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Ekle'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Health profile converters ─────────────────────────────────────────────────

AgeRange _ageRangeFromBirthDate(String birthDate) {
  final birth = DateTime.tryParse(birthDate);
  if (birth == null) return AgeRange.unknown;
  final now = DateTime.now();
  int age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  if (age < 0) return AgeRange.unknown;
  if (age < 10) return AgeRange.child0to9;
  if (age < 18) return AgeRange.teen10to17;
  if (age < 30) return AgeRange.young18to29;
  if (age < 45) return AgeRange.adult30to44;
  if (age < 60) return AgeRange.range45to59;
  if (age < 75) return AgeRange.senior60to74;
  return AgeRange.elderly75plus;
}

Gender _genderFromString(String? gender) {
  switch (gender) {
    case 'male':
      return Gender.male;
    case 'female':
      return Gender.female;
    default:
      return Gender.unknown;
  }
}

// ── Label helpers ─────────────────────────────────────────────────────────────

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

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
    this.radius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
