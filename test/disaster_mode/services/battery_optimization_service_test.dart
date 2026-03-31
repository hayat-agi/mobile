import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/services/battery_optimization_service.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/config/power_config.dart';

void main() {
  group('BatteryOptimizationService', () {
    test('singleton instance always same object', () {
      final a = BatteryOptimizationService();
      final b = BatteryOptimizationService();
      expect(identical(a, b), true);
    });

    test('isActive starts false', () {
      expect(BatteryOptimizationService().isActive, false);
    });

    test('batteryLevel starts at -1 (not fetched yet)', () {
      expect(BatteryOptimizationService().batteryLevel, -1);
    });

    test('activate and deactivate toggle isActive state', () async {
      final svc = BatteryOptimizationService();
      await svc.activate();
      expect(svc.isActive, true);
      await svc.deactivate();
      expect(svc.isActive, false);
    });

    test('mode transitions follow configured thresholds', () {
      final svc = BatteryOptimizationService();
      svc.setBatteryLevelForTest(80);
      expect(svc.mode, BatteryMode.normal);

      svc.setBatteryLevelForTest(PowerConfig.lowBatteryWarningThreshold);
      expect(svc.mode, BatteryMode.low);

      svc.setBatteryLevelForTest(PowerConfig.aggressiveSaveThreshold);
      expect(svc.mode, BatteryMode.critical);
    });

    test('nonCriticalInterval scales with power mode', () {
      final svc = BatteryOptimizationService();
      svc.setBatteryLevelForTest(80);
      final normal = svc.nonCriticalInterval;
      svc.setBatteryLevelForTest(PowerConfig.lowBatteryWarningThreshold);
      final low = svc.nonCriticalInterval;
      svc.setBatteryLevelForTest(PowerConfig.aggressiveSaveThreshold);
      final critical = svc.nonCriticalInterval;

      expect(low.inMilliseconds, greaterThan(normal.inMilliseconds));
      expect(critical.inMilliseconds, greaterThanOrEqualTo(low.inMilliseconds));
    });
  });
}
