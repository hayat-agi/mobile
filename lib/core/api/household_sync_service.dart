import '../../models/household_member.dart';
import '../../models/pet.dart';
import 'gateway_repository.dart';

class HouseholdSyncService {
  final _gatewayRepository = GatewayRepository();

  /// Sync local household members to backend as citizens
  Future<bool> syncHousehold({
    required String gatewayId,
    required List<HouseholdMember> members,
    required List<Pet> pets,
  }) async {
    try {
      // Fetch current backend state
      final gateways = await _gatewayRepository.fetchUserGateways();
      final backendGateway = gateways.where((g) => g.id == gatewayId).firstOrNull;

      if (backendGateway == null) return false;

      // TODO(backend): Replace delete-all-recreate with ownership-aware upsert when backend supports per-user citizens.
      // Remove existing citizens and pets first, then re-add
      for (final citizen in backendGateway.citizens) {
        if (citizen.id != null) {
          try {
            await _gatewayRepository.removeCitizen(gatewayId, citizen.id!);
          } catch (_) {}
        }
      }
      for (final pet in backendGateway.pets) {
        if (pet.id != null) {
          try {
            await _gatewayRepository.removePet(gatewayId, pet.id!);
          } catch (_) {}
        }
      }

      // Add members as citizens
      for (final member in members) {
        final citizenData = _memberToCitizenData(member);
        await _gatewayRepository.addCitizen(gatewayId, citizenData);
      }

      // Add pets
      for (final pet in pets) {
        final petData = _petToBackendData(pet);
        await _gatewayRepository.addPet(gatewayId, petData);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _memberToCitizenData(HouseholdMember member) {
    final now = DateTime.now();
    final estimatedBirthDate = DateTime(now.year - member.age, 1, 1).toIso8601String();
    final birthDate = (member.birthDate != null && member.birthDate!.isNotEmpty)
        ? member.birthDate!
        : estimatedBirthDate;

    return {
      'fullname': member.name,
      'birthDate': birthDate,
      'age': member.age,
      if (member.tcNumber != null) 'tcNumber': member.tcNumber,
      if (member.gender != null) 'gender': member.gender,
      if (member.bloodType != null) 'bloodType': member.bloodType,
      'medicalConditions': member.medicalConditions,
      'specialNeeds': member.specialNeeds,
      if (member.medications != null) 'medications': member.medications,
      if (member.prosthetics != null) 'prosthetics': member.prosthetics,
    };
  }

  Map<String, dynamic> _petToBackendData(Pet pet) {
    return {
      'name': pet.name,
      'species': pet.type, // Map local 'type' to backend 'species'
      if (pet.breed != null) 'breed': pet.breed,
      if (pet.microchipId != null) 'microchipId': pet.microchipId,
      if (pet.specialNeeds != null) 'specialNeeds': pet.specialNeeds,
    };
  }
}
