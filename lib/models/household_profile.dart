import 'emergency_contact.dart';
import 'household_member.dart';
import 'pet.dart';

class HouseholdProfile {
  final String gatewayId; // Links to specific gateway
  final List<HouseholdMember> members; // Individual household members
  final List<Pet> pets; // Pets in the household
  final List<EmergencyContact> emergencyContacts;
  final int priorityScore; // Calculated internally, not shown to user

  HouseholdProfile({
    required this.gatewayId,
    this.members = const [],
    this.pets = const [],
    this.emergencyContacts = const [],
    this.priorityScore = 0,
  });

  // Helper getters for backward compatibility
  int get numberOfChildren => members.where((m) => m.isChild).length;
  int get numberOfElderly => members.where((m) => m.isElderly).length;

  HouseholdProfile copyWith({
    String? gatewayId,
    List<HouseholdMember>? members,
    List<Pet>? pets,
    List<EmergencyContact>? emergencyContacts,
    int? priorityScore,
  }) {
    return HouseholdProfile(
      gatewayId: gatewayId ?? this.gatewayId,
      members: members ?? this.members,
      pets: pets ?? this.pets,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }

  // Calculate priority score based on household data
  // Higher score = higher priority for rescue
  int calculatePriorityScore() {
    int score = 0;

    // Calculate based on individual members
    for (final member in members) {
      // Children add to priority
      if (member.isChild) {
        score += 10;
      }
      
      // Elderly add significantly to priority
      if (member.isElderly) {
        score += 15;
      }
      
      // Medical conditions per person add high priority
      score += member.medicalConditions.length * 20;
      
      // Special needs per person add priority
      score += member.specialNeeds.length * 15;
    }

    // Pets add to priority (they need rescue too)
    score += pets.length * 5;

    // Emergency contacts indicate preparedness (slight bonus)
    if (emergencyContacts.isNotEmpty) {
      score += 5;
    }

    return score;
  }

  Map<String, dynamic> toJson() {
    return {
      'gatewayId': gatewayId,
      'members': members.map((m) => m.toJson()).toList(),
      'pets': pets.map((p) => p.toJson()).toList(),
      'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'priorityScore': calculatePriorityScore(),
    };
  }

  factory HouseholdProfile.fromJson(Map<String, dynamic> json) {
    return HouseholdProfile(
      gatewayId: json['gatewayId'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => HouseholdMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pets: (json['pets'] as List<dynamic>?)
              ?.map((e) => Pet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      priorityScore: json['priorityScore'] as int? ?? 0,
    );
  }
}

