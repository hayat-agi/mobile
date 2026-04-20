import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';

void main() {
  group('UserHealthProfile', () {
    test('empty() produces safe defaults', () {
      final p = UserHealthProfile.empty();
      expect(p.age, AgeRange.unknown);
      expect(p.gender, Gender.unknown);
      expect(p.chronicDiseases, isEmpty);
      expect(p.medications, isEmpty);
      expect(p.disabilities, isEmpty);
      expect(p.hasProfile, false);
    });

    test('toBytes() / fromBytes() round-trip — multiple disabilities', () {
      final original = UserHealthProfile(
        hasProfile: true,
        age: AgeRange.range45to59,
        gender: Gender.female,
        chronicDiseases: {ChronicDisease.diabetes, ChronicDisease.hypertension},
        medications: {Medication.insulin},
        disabilities: {
          DisabilityStatus.mobility,
          DisabilityStatus.hearing,
        },
      );
      final bytes = original.toBytes();
      expect(bytes.length, 4);
      final restored = UserHealthProfile.fromBytes(bytes);
      expect(restored.hasProfile, true);
      expect(restored.age, AgeRange.range45to59);
      expect(restored.gender, Gender.female);
      expect(restored.chronicDiseases, contains(ChronicDisease.diabetes));
      expect(restored.chronicDiseases, contains(ChronicDisease.hypertension));
      expect(restored.medications, contains(Medication.insulin));
      expect(restored.disabilities, contains(DisabilityStatus.mobility));
      expect(restored.disabilities, contains(DisabilityStatus.hearing));
    });

    test('legacy single-disability bytes still decode', () {
      // Old encoder: idx 1 (mobility) → byte0 lower 2 bits 0, byte1 = 0x80
      final legacy = Uint8List.fromList([0x80, 0x80, 0x00, 0x00]);
      final restored = UserHealthProfile.fromBytes(legacy);
      expect(restored.disabilities, contains(DisabilityStatus.mobility));
    });

    test('empty profile serializes to 4 bytes with hasProfile=0', () {
      final bytes = UserHealthProfile.empty().toBytes();
      expect(bytes.length, 4);
      expect(bytes[0] & 0x80, 0);
    });
  });
}
