// test/disaster_mode/config/power_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/config/power_config.dart';

void main() {
  test('disaster brightness is less than normal brightness', () {
    expect(PowerConfig.disasterBrightness, lessThan(PowerConfig.normalBrightness));
  });
  test('aggressive threshold is below low-battery warning threshold', () {
    expect(PowerConfig.aggressiveSaveThreshold, lessThan(PowerConfig.lowBatteryWarningThreshold));
  });
}
