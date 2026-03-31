// lib/features/disaster_mode/config/power_config.dart

/// Threshold values and settings for disaster mode power optimization.
/// These are the agreed technical parameters — change here to affect all behavior.
class PowerConfig {
  PowerConfig._();

  /// Screen brightness reduced to this fraction (0.0–1.0) when disaster mode is active.
  static const double disasterBrightness = 0.15;

  /// Normal brightness is restored to this fraction when leaving disaster mode.
  static const double normalBrightness = 1.0;

  /// Battery percentage below which we enter aggressive power-saving mode.
  static const int aggressiveSaveThreshold = 20; // percent

  /// Battery percentage below which a low-battery warning is shown to user.
  static const int lowBatteryWarningThreshold = 30; // percent

  /// Notification check interval in disaster mode (milliseconds).
  static const int disasterNotificationIntervalMs = 5 * 60 * 1000; // 5 minutes

  /// How often the battery level is polled (milliseconds).
  static const int batteryCheckIntervalMs = 60 * 1000; // 1 minute
}
