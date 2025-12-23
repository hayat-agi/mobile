import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/household_profile.dart';
import '../../models/household_member.dart';
import '../../models/pet.dart';
import '../../models/emergency_contact.dart';
import '../../services/gateway_service.dart';
import '../../core/theme/app_colors.dart';

class HouseholdProfilePage extends StatefulWidget {
  final String gatewayId;

  const HouseholdProfilePage({
    super.key,
    required this.gatewayId,
  });

  @override
  State<HouseholdProfilePage> createState() => _HouseholdProfilePageState();
}

class _HouseholdProfilePageState extends State<HouseholdProfilePage> {
  final GatewayService _gatewayService = GatewayService();
  final _formKey = GlobalKey<FormState>();

  // Member form controllers
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _memberAgeController = TextEditingController();
  final TextEditingController _memberMedicalConditionController = TextEditingController();
  final TextEditingController _memberSpecialNeedController = TextEditingController();

  // Pet form controllers
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _petTypeController = TextEditingController();
  final TextEditingController _petSpecialNeedsController = TextEditingController();

  // Emergency contact controllers
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactRelationshipController = TextEditingController();

  List<HouseholdMember> _members = [];
  List<Pet> _pets = [];
  List<EmergencyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final profile = _gatewayService.getHouseholdProfile(widget.gatewayId);
    if (profile != null) {
      _members = List<HouseholdMember>.from(profile.members);
      _pets = List<Pet>.from(profile.pets);
      _emergencyContacts = List<EmergencyContact>.from(profile.emergencyContacts);
    }
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
          _members[memberIndex] = member.copyWith(
            specialNeeds: updatedNeeds,
          );
        }
        _memberSpecialNeedController.clear();
      });
    }
  }

  void _removeSpecialNeedFromMember(int memberIndex, String need) {
    setState(() {
      final member = _members[memberIndex];
      final updatedNeeds = List<String>.from(member.specialNeeds)..remove(need);
      _members[memberIndex] = member.copyWith(
        specialNeeds: updatedNeeds,
      );
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
        EmergencyContact(
          name: name,
          phone: phone,
          relationship: relationship,
        ),
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
    final profile = HouseholdProfile(
      gatewayId: widget.gatewayId,
      members: _members,
      pets: _pets,
      emergencyContacts: _emergencyContacts,
    );

    await _gatewayService.saveHouseholdProfile(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil kaydedildi'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hane Profili'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
            tooltip: 'Kaydet',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Household Member
              _buildSectionTitle('Hane Üyeleri'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _memberNameController,
                      decoration: const InputDecoration(
                        labelText: 'İsim',
                        hintText: 'Kişi adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _memberAgeController,
                      decoration: const InputDecoration(
                        labelText: 'Yaş',
                        hintText: '25',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addMember(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addMember,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              
              // Display Members
              if (_members.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._members.asMap().entries.map((entry) {
                  final index = entry.key;
                  final member = entry.value;
                  return _buildMemberCard(member, index);
                }),
              ],
              const SizedBox(height: 24),

              // Add Pet
              _buildSectionTitle('Evcil Hayvanlar'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _petNameController,
                      decoration: const InputDecoration(
                        labelText: 'İsim',
                        hintText: 'Evcil hayvan adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _petTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Tip',
                        hintText: 'Köpek, Kedi, vb.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _petSpecialNeedsController,
                      decoration: const InputDecoration(
                        labelText: 'Özel İhtiyaçlar (opsiyonel)',
                        hintText: 'Örn: İlaç gerekiyor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addPet(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addPet,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              
              // Display Pets
              if (_pets.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._pets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pet = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text(pet.name),
                      subtitle: Text(
                        pet.specialNeeds != null
                            ? '${pet.type} - ${pet.specialNeeds}'
                            : pet.type,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => _removePet(index),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),

              // Emergency Contacts
              _buildSectionTitle('Acil Durum İletişimleri'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        labelText: 'İsim',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactRelationshipController,
                      decoration: const InputDecoration(
                        labelText: 'İlişki',
                        hintText: 'Örn: Eş, Kardeş',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addEmergencyContact(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addEmergencyContact,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              if (_emergencyContacts.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._emergencyContacts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final contact = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.contact_phone),
                      title: Text(contact.name),
                      subtitle: Text('${contact.relationship} - ${contact.phone}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => _removeEmergencyContact(index),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('Profili Kaydet'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(HouseholdMember member, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          member.isChild
              ? Icons.child_care
              : member.isElderly
                  ? Icons.elderly
                  : Icons.person,
          color: member.isChild || member.isElderly ? Colors.orange : null,
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${member.age} yaşında'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeMember(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medical Conditions for this member
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
                        onFieldSubmitted: (_) => _addMedicalConditionToMember(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, size: 20),
                      onPressed: () => _addMedicalConditionToMember(index),
                      color: Theme.of(context).primaryColor,
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
                        label: Text(condition, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removeMedicalConditionFromMember(index, condition),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                
                // Special Needs for this member
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
                      color: Theme.of(context).primaryColor,
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
                        onDeleted: () => _removeSpecialNeedFromMember(index, need),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

