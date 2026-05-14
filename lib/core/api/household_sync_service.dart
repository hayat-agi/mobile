import '../../models/backend_gateway.dart';
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
      final backendGateway = gateways
          .where((gateway) => _matchesGateway(gateway, gatewayId))
          .firstOrNull;

      if (backendGateway == null) return false;

      final backendGatewayId = backendGateway.id.isNotEmpty
          ? backendGateway.id
          : gatewayId;

      // TODO(backend): Replace delete-all-recreate with ownership-aware upsert when backend supports per-user citizens.
      // Remove existing citizens and pets first, then re-add
      for (final citizen in backendGateway.citizens) {
        if (citizen.id != null) {
          try {
            await _gatewayRepository.removeCitizen(
              backendGatewayId,
              citizen.id!,
            );
          } catch (_) {}
        }
      }
      for (final pet in backendGateway.pets) {
        if (pet.id != null) {
          try {
            await _gatewayRepository.removePet(backendGatewayId, pet.id!);
          } catch (_) {}
        }
      }

      // Add members as citizens
      for (final member in members) {
        final citizenData = _memberToCitizenData(member);
        await _gatewayRepository.addCitizen(backendGatewayId, citizenData);
      }

      // Add pets
      for (final pet in pets) {
        final petData = _petToBackendData(pet);
        await _gatewayRepository.addPet(backendGatewayId, petData);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  bool _matchesGateway(BackendGateway backendGateway, String localGatewayId) {
    final localId = _normalizeGatewayIdentifier(localGatewayId);
    if (localId == null) return false;

    return [
      backendGateway.id,
      backendGateway.serialNumber,
      backendGateway.macAddress,
    ].any((value) => _normalizeGatewayIdentifier(value) == localId);
  }

  String? _normalizeGatewayIdentifier(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  Map<String, dynamic> _memberToCitizenData(HouseholdMember member) {
    return {
      'fullname': member.name,
      'birthDate': member.birthDate,
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
