import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/disaster_message_packet.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';
import 'package:hayat_agi_mobile/models/household_profile.dart';
import 'package:hayat_agi_mobile/models/household_member.dart';

void main() {
  group('DisasterMessagePacket v4', () {
    test('encode/decode round-trip message + health', () {
      final packet = DisasterMessagePacket(
        healthProfile: UserHealthProfile(
          hasProfile: true,
          age: AgeRange.adult30to44,
          gender: Gender.male,
          chronicDiseases: {ChronicDisease.diabetes},
          medications: {Medication.insulin},
          disabilities: {DisabilityStatus.mobility, DisabilityStatus.visual},
        ),
        messageText: 'Yardım edin',
      );

      final encoded = packet.encode();
      expect(encoded[0], 0xD0);
      final decoded = DisasterMessagePacket.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.messageText, 'Yardım edin');
      expect(decoded.healthProfile.gender, Gender.male);
      expect(decoded.healthProfile.disabilities, contains(DisabilityStatus.mobility));
      expect(decoded.healthProfile.disabilities, contains(DisabilityStatus.visual));
      expect(decoded.household, isNull);
    });

    test('checksum validation rejects corrupted bytes', () {
      final packet = DisasterMessagePacket(
        healthProfile: UserHealthProfile.empty(),
        messageText: '',
      );
      final bytes = packet.encode();
      bytes[0] ^= 0xFF;
      expect(DisasterMessagePacket.decode(bytes), isNull);
    });

    test('optional household JSON round-trip', () {
      final hh = HouseholdProfile(
        gatewayId: 'gw1',
        members: [
          HouseholdMember(
            name: 'Ali',
            age: 8,
            isChild: true,
            isElderly: false,
            medicalConditions: ['Astım'],
            specialNeeds: [],
          ),
        ],
        pets: [],
        emergencyContacts: [],
      );
      final packet = DisasterMessagePacket(
        healthProfile: UserHealthProfile.empty(),
        messageText: 'Test',
        household: hh,
      );
      final decoded = DisasterMessagePacket.decode(packet.encode());
      expect(decoded, isNotNull);
      expect(decoded!.household?.members.length, 1);
      expect(decoded.household?.members.first.name, 'Ali');
    });
  });
}
