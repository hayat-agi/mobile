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

class HouseholdProfilePage extends StatefulWidget {
  final String? gatewayId;

  const HouseholdProfilePage({super.key, required this.gatewayId});

  @override
  State<HouseholdProfilePage> createState() => _HouseholdProfilePageState();
}

class _HouseholdProfilePageState extends State<HouseholdProfilePage> {
  final GatewayService _gatewayService = GatewayService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _memberAgeController = TextEditingController();
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
      _memberNameController.clear();
      _memberAgeController.clear();
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
      _memberNameController.clear();
      _memberAgeController.clear();
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
    _memberNameController.dispose();
    _memberAgeController.dispose();
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

  void _addMember() {
    final name = _memberNameController.text.trim();
    final ageStr = _memberAgeController.text.trim();
    final age = int.tryParse(ageStr);

    if (name.isEmpty || age == null || age < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen isim ve yaş girin'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _members.add(
        HouseholdMember(
          name: name,
          age: age,
          isChild: age < 18,
          isElderly: age >= 65,
          medicalConditions: [],
          specialNeeds: [],
        ),
      );
      _memberNameController.clear();
      _memberAgeController.clear();
    });
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
      actions: [
        IconButton(
          icon: const Icon(Icons.save_outlined),
          onPressed: _saveProfile,
          tooltip: 'Kaydet',
        ),
      ],
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

  void _showAddMemberSheet(BuildContext context) {
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
            Text('Hane Üyesi Ekle', style: AppTypography.titleLarge(context)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memberNameController,
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
              controller: _memberAgeController,
              decoration: const InputDecoration(
                labelText: 'Yaş',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final before = _members.length;
                  _addMember();
                  if (_members.length > before) Navigator.pop(ctx);
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
        subtitle: Text('${member.age} yaşında'),
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
