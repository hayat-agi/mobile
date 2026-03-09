import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/api/user_repository.dart';
import '../../core/api/metadata_repository.dart';
import '../../core/network/api_exception.dart';
import '../../models/system_options.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _userRepository = UserRepository();
  final _metadataRepository = MetadataRepository();

  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  String? _selectedBloodType;
  String? _selectedGender;
  List<String> _selectedConditions = [];
  List<String> _selectedMedications = [];
  List<String> _selectedProsthetics = [];
  SystemOptions _options = SystemOptions.defaults();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _options = await _metadataRepository.fetchSystemOptions();
    } catch (_) {}

    final user = AuthService().currentUser.value;
    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
      _selectedBloodType = user.bloodType;
      _selectedGender = user.gender;
      _selectedConditions = List<String>.from(user.medicalConditions);
      _selectedMedications = List<String>.from(user.medications);
      _selectedProsthetics = List<String>.from(user.prosthetics);

      if (user.emergencyContact != null) {
        _emergencyNameController.text = user.emergencyContact!['fullname'] ?? '';
        _emergencyPhoneController.text = user.emergencyContact!['phone'] ?? '';
        _emergencyRelationController.text = user.emergencyContact!['relation'] ?? '';
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'phoneNumber': _phoneController.text.trim(),
        'bloodType': _selectedBloodType,
        'gender': _selectedGender,
        'medicalConditions': _selectedConditions,
        'medications': _selectedMedications,
        'prosthetics': _selectedProsthetics,
      };

      if (_emergencyNameController.text.isNotEmpty) {
        data['emergencyContact'] = {
          'fullname': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relation': _emergencyRelationController.text.trim(),
        };
      }

      final updatedUser = await _userRepository.updateProfile(data);
      AuthService().currentUser.value = updatedUser;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil güncellenemedi'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleItem(List<String> list, String item) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Düzenle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Düzenle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // User info header
            _buildUserHeader(theme),
            const SizedBox(height: AppSpacing.lg),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefon Numarası',
                prefixIcon: Icon(Icons.phone),
                hintText: '05XX XXX XXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),

            // Gender dropdown
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Cinsiyet',
                prefixIcon: Icon(Icons.wc),
              ),
              items: _options.genderOptions.map((g) => DropdownMenuItem(
                value: g,
                child: Text(g),
              )).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: AppSpacing.md),

            // Blood type dropdown
            DropdownButtonFormField<String>(
              value: _selectedBloodType,
              decoration: const InputDecoration(
                labelText: 'Kan Grubu',
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: _options.bloodTypes.map((bt) => DropdownMenuItem(
                value: bt,
                child: Text(bt),
              )).toList(),
              onChanged: (v) => setState(() => _selectedBloodType = v),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Medical conditions
            _buildChipSection(
              'Tıbbi Durumlar',
              _options.medicalConditions,
              _selectedConditions,
            ),
            const SizedBox(height: AppSpacing.md),

            // Medications
            _buildChipSection(
              'İlaçlar',
              _options.medications,
              _selectedMedications,
            ),
            const SizedBox(height: AppSpacing.md),

            // Prosthetics
            _buildChipSection(
              'Protez / Yardımcı Cihaz',
              _options.prosthetics,
              _selectedProsthetics,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Emergency contact
            Text(
              'Acil Durum İletişimi',
              style: AppTypography.titleMedium(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _emergencyRelationController,
              decoration: const InputDecoration(
                labelText: 'Yakınlık',
                hintText: 'Örn: Eş, Kardeş',
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Kaydet',
              icon: Icons.save,
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(ThemeData theme) {
    final user = AuthService().currentUser.value;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: AppTypography.headlineMedium(context).copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: AppTypography.titleLarge(context)),
                  Text(
                    user.email,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSection(String title, List<String> options, List<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => _toggleItem(selected, option),
            );
          }).toList(),
        ),
      ],
    );
  }
}
