import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../config/power_config.dart';

enum BatteryMode { normal, low, critical }

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  final _battery = Battery();
  Timer? _batteryTimer;
  bool _isActive = false;
  int _batteryLevel = -1;
  double? _previousBrightness;
  final ValueNotifier<BatteryMode> modeNotifier =
      ValueNotifier<BatteryMode>(BatteryMode.normal);

  bool get isActive => _isActive;
  int get batteryLevel => _batteryLevel;
  BatteryMode get mode => modeNotifier.value;
  Duration get nonCriticalInterval {
    switch (mode) {
      case BatteryMode.critical:
        return const Duration(
          milliseconds: PowerConfig.disasterNotificationIntervalMs * 2,
        );
      case BatteryMode.low:
        return const Duration(
          milliseconds: PowerConfig.disasterNotificationIntervalMs,
        );
      case BatteryMode.normal:
        return const Duration(minutes: 3);
    }
  }

  void _updateModeFromLevel() {
    if (_batteryLevel <= PowerConfig.aggressiveSaveThreshold && _batteryLevel >= 0) {
      modeNotifier.value = BatteryMode.critical;
    } else if (_batteryLevel <= PowerConfig.lowBatteryWarningThreshold &&
        _batteryLevel >= 0) {
      modeNotifier.value = BatteryMode.low;
    } else {
      modeNotifier.value = BatteryMode.normal;
    }
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _updateModeFromLevel();
    } catch (_) {}
  }

  @visibleForTesting
  void setBatteryLevelForTest(int level) {
    _batteryLevel = level;
    _updateModeFromLevel();
  }

  Future<void> activate() async {
    if (_isActive) return;
    _isActive = true;
    try {
      _previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(PowerConfig.disasterBrightness);
    } catch (_) {}
    await _refreshBatteryLevel();
    _batteryTimer = Timer.periodic(
      const Duration(milliseconds: PowerConfig.batteryCheckIntervalMs),
      (_) async {
        await _refreshBatteryLevel();
      },
    );
  }

  Future<void> deactivate() async {
    if (!_isActive) return;
    _isActive = false;
    _batteryTimer?.cancel();
    _batteryTimer = null;
    modeNotifier.value = BatteryMode.normal;
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (_) {}
    _previousBrightness = null;
  }

  bool get isBatteryCritical =>
      _batteryLevel >= 0 && _batteryLevel <= PowerConfig.aggressiveSaveThreshold;

  bool get isBatteryLow =>
      _batteryLevel >= 0 && _batteryLevel <= PowerConfig.lowBatteryWarningThreshold;
}
