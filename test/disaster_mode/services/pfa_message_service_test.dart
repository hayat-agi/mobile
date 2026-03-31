// test/disaster_mode/services/pfa_message_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/services/pfa_message_service.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/data/pfa_messages.dart';

void main() {
  group('PFAMessageService', () {
    late PFAMessageService svc;
    setUp(() => svc = PFAMessageService());

    test('detectCategory returns panicBreathing for panic keywords', () {
      expect(
        svc.detectCategory('nefes alamıyorum çok kötüyüm'),
        PfaCategory.panicBreathing,
      );
    });

    test('detectCategory returns hopelessness for hopelessness keywords', () {
      expect(
        svc.detectCategory('kurtulamayacağım her şey bitti umudum kalmadı'),
        PfaCategory.hopelessness,
      );
    });

    test('detectCategory returns loneliness for loneliness keywords', () {
      expect(
        svc.detectCategory('yalnızım kimse gelmiyor terk edildim'),
        PfaCategory.loneliness,
      );
    });

    test('detectCategory returns painTrapped for pain keywords', () {
      expect(
        svc.detectCategory('çok ağrı var sıkıştım çıkamıyorum'),
        PfaCategory.painTrapped,
      );
    });

    test('detectCategory returns null for neutral message', () {
      expect(svc.detectCategory('tamam bekliyorum'), isNull);
    });

    test('selectMessage returns a message for valid category', () {
      final msg = svc.selectMessage(PfaCategory.firstContact, seed: 'seed');
      expect(msg, isNotNull);
      expect(msg!.category, PfaCategory.firstContact);
    });

    test('detectCategoryWithRisk falls back to panic for high risk', () {
      expect(
        svc.detectCategoryWithRisk('nötr ifade', riskScore: 85),
        PfaCategory.panicBreathing,
      );
    });

    test('selectMessage prioritizes vulnerability-specific entries', () {
      final msg = svc.selectMessage(
        PfaCategory.loneliness,
        isVulnerable: true,
        seed: 'vulnerable-seed',
      );
      expect(msg, isNotNull);
      expect(msg!.vulnerabilityPriority, greaterThan(0));
    });

    test('selectMessage is deterministic for same seed/risk', () {
      final msg1 = svc.selectMessage(
        PfaCategory.uncertainty,
        riskScore: 60,
        seed: 'same-seed',
      );
      final msg2 = svc.selectMessage(
        PfaCategory.uncertainty,
        riskScore: 60,
        seed: 'same-seed',
      );
      expect(msg1?.text, msg2?.text);
    });

    test('no-response trigger fires after timeout', () async {
      bool triggered = false;
      svc.startNoResponseTimer(
        onTimeout: () => triggered = true,
        duration: const Duration(milliseconds: 50),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      expect(triggered, true);
      svc.cancelNoResponseTimer();
    });

    test('cancelNoResponseTimer prevents callback', () async {
      bool triggered = false;
      svc.startNoResponseTimer(
        onTimeout: () => triggered = true,
        duration: const Duration(milliseconds: 50),
      );
      svc.cancelNoResponseTimer();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(triggered, false);
    });
  });
}
