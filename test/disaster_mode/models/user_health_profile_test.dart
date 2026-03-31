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
      expect(p.disability, DisabilityStatus.none);
      expect(p.hasProfile, false);
    });

    test('toBytes() / fromBytes() round-trip', () {
      final original = UserHealthProfile(
        hasProfile: true,
        age: AgeRange.range45to59,
        gender: Gender.female,
        chronicDiseases: {ChronicDisease.diabetes, ChronicDisease.hypertension},
        medications: {Medication.insulin},
        disability: DisabilityStatus.mobility,
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
      expect(restored.disability, DisabilityStatus.mobility);
    });

    test('empty profile serializes to 4 zero-ish bytes with hasProfile=0', () {
      final bytes = UserHealthProfile.empty().toBytes();
      expect(bytes.length, 4);
      expect(bytes[0] & 0x80, 0); // hasProfile bit = 0
    });
  });
}
