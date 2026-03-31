import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';
import 'package:hayat_agi_mobile/features/user_profile/services/vulnerable_group_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VulnerableGroupService', () {
    test('isVulnerableGroup defaults to false', () async {
      final svc = VulnerableGroupService();
      await svc.load();
      expect(svc.isVulnerableGroup, false);
    });

    test('save and load health profile round-trip', () async {
      final svc = VulnerableGroupService();
      final profile = UserHealthProfile(
        hasProfile: true,
        age: AgeRange.elderly75plus,
        gender: Gender.female,
        chronicDiseases: {ChronicDisease.heartDisease},
        medications: {Medication.bloodThinner},
        disability: DisabilityStatus.mobility,
      );

      await svc.saveProfile(profile: profile, isVulnerableGroup: true);
      await svc.load();

      expect(svc.isVulnerableGroup, true);
      expect(svc.profile.age, AgeRange.elderly75plus);
      expect(
        svc.profile.chronicDiseases,
        contains(ChronicDisease.heartDisease),
      );
      expect(
        svc.profile.medications,
        contains(Medication.bloodThinner),
      );
      expect(svc.profile.disability, DisabilityStatus.mobility);
    });
  });
}

