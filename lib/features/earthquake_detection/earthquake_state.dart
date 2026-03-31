import 'dart:math' as math;

/// Lifecycle states of the earthquake monitor.
enum EarthquakeMonitorState {
  /// Monitoring has not started (sensors not subscribed).
  idle,

  /// Actively sampling accelerometer, STA/LTA running.
  monitoring,

  /// STA/LTA triggered; IQR/ZC/CAV feature analysis in progress.
  suspicious,

  /// All detection layers passed; user confirmation shown (or auto-confirmed).
  confirmed,

  /// In cooldown period after a detection; ignoring new events.
  cooldown,
}

/// Immutable snapshot of a single earthquake detection event.
class EarthquakeEvent {
  const EarthquakeEvent({
    required this.timestamp,
    required this.staLtaRatio,
    required this.peakAcceleration,
    required this.iqr,
    required this.zeroCrossingRate,
    required this.cav,
    required this.kurtosis,
    this.autoConfirmed = false,
  });

  /// When the detection was confirmed.
  final DateTime timestamp;

  /// STA/LTA ratio that triggered Layer 1.
  final double staLtaRatio;

  /// Peak net acceleration magnitude (m/s²) during the feature window.
  final double peakAcceleration;

  /// Interquartile range of the acceleration signal (m/s²).
  final double iqr;

  /// Zero-crossing rate (crossings per second) of the feature window.
  final double zeroCrossingRate;

  /// Cumulative Absolute Velocity of the feature window (m/s²·s).
  final double cav;

  /// Excess kurtosis of the feature window acceleration distribution.
  final double kurtosis;

  /// True when the user did not respond within the confirmation timeout.
  final bool autoConfirmed;

  /// Rough Richter-scale-like magnitude estimate based on peak acceleration.
  /// Formula derived from OpenEEW gal → magnitude approximation.
  /// Peak acceleration in gal (1 m/s² = 100 gal).
  double get estimatedMagnitude {
    final peakGal = peakAcceleration * 100;
    if (peakGal <= 0) return 0;
    return (math.log(peakGal) / math.ln10 * 0.7 + 0.5).clamp(0.0, 9.0);
  }

  @override
  String toString() =>
      'EarthquakeEvent(ratio=$staLtaRatio, peak=${peakAcceleration.toStringAsFixed(2)}m/s², '
      'IQR=$iqr, ZC=$zeroCrossingRate, CAV=$cav, kurt=$kurtosis, auto=$autoConfirmed)';
}
