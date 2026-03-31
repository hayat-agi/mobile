import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/disaster_enums.dart';

void main() {
  group('PriorityLevel.fromTriageScore', () {
    test('score 80+ is critical', () => expect(PriorityLevel.fromTriageScore(80), PriorityLevel.critical));
    test('score 50-79 is high',    () => expect(PriorityLevel.fromTriageScore(50), PriorityLevel.high));
    test('score 20-49 is medium',  () => expect(PriorityLevel.fromTriageScore(20), PriorityLevel.medium));
    test('score 0-19 is low',      () => expect(PriorityLevel.fromTriageScore(0),  PriorityLevel.low));
    test('bitmask round-trip',     () {
      for (final p in PriorityLevel.values) {
        expect(PriorityLevel.fromBitmask(p.bitmask), p);
      }
    });
  });
}
