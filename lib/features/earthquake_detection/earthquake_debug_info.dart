import 'algorithms/feature_extractor.dart';
import 'earthquake_config.dart';

/// Emitted every time the feature layer is evaluated (or would have been).
/// Used for threshold validation: compare real earthquake values vs hand-shake values.
class EarthquakeDebugInfo {
  const EarthquakeDebugInfo({
    required this.timestamp,
    required this.source,
    required this.staLtaRatio,
    required this.stationarityVariance,
    required this.peakGyroMagnitude,
    required this.blockReason,
    this.features,
  });

  /// Where this sample came from.
  final EarthquakeDebugSource source;

  /// STA/LTA ratio at the moment of evaluation.
  final double staLtaRatio;

  /// Net-acc variance from the stationarity detector (null if not available).
  final double? stationarityVariance;

  /// Peak gyroscope magnitude in the recent window (null if not available).
  final double? peakGyroMagnitude;

  /// Why detection was blocked, or null if it reached Layer 2 evaluation.
  final EarthquakeBlockReason? blockReason;

  /// Feature values. Non-null whenever Layer 2 was evaluated (blockReason == null
  /// OR debugForceFeatures == true).
  final FeatureResult? features;

  final DateTime timestamp;

  /// Human-readable threshold comparison for console printing.
  String get thresholdReport {
    final buf = StringBuffer();
    buf.writeln('──────────────────────────────────────────');
    buf.writeln('EQ Debug  [${source.name}]  ${timestamp.toIso8601String()}');
    buf.writeln(
        '  STA/LTA ratio  : ${staLtaRatio.toStringAsFixed(3)}  (threshold: ${EarthquakeConfig.staLtaTriggerThreshold})');
    if (stationarityVariance != null) {
      final pass =
          stationarityVariance! < EarthquakeConfig.stationarityVarianceThreshold;
      buf.writeln(
          '  Stationarity   : ${stationarityVariance!.toStringAsExponential(3)}  (threshold: ${EarthquakeConfig.stationarityVarianceThreshold})  ${pass ? "PASS" : "FAIL"}');
    }
    if (peakGyroMagnitude != null) {
      final pass =
          peakGyroMagnitude! < EarthquakeConfig.gyroscopeVetoThreshold;
      buf.writeln(
          '  Gyro magnitude : ${peakGyroMagnitude!.toStringAsFixed(3)} rad/s  (threshold: ${EarthquakeConfig.gyroscopeVetoThreshold})  ${pass ? "PASS" : "FAIL"}');
    }
    if (blockReason != null) {
      buf.writeln('  BLOCKED by     : ${blockReason!.name}');
    }
    if (features != null) {
      final f = features!;
      buf.writeln(
          '  IQR            : ${f.iqr.toStringAsFixed(4)}  (threshold: ${EarthquakeConfig.iqrThreshold})  ${f.iqr >= EarthquakeConfig.iqrThreshold ? "PASS" : "fail"}');
      buf.writeln(
          '  ZC rate        : ${f.zeroCrossingRate.toStringAsFixed(3)}/s  (threshold: ${EarthquakeConfig.zcThreshold})  ${f.zeroCrossingRate >= EarthquakeConfig.zcThreshold ? "PASS" : "fail"}');
      buf.writeln(
          '  CAV            : ${f.cav.toStringAsFixed(4)} m/s²·s  (threshold: ${EarthquakeConfig.cavThreshold})  ${f.cav >= EarthquakeConfig.cavThreshold ? "PASS" : "fail"}');
      buf.writeln(
          '  Kurtosis       : ${f.kurtosis.toStringAsFixed(2)}  (vote threshold: ${EarthquakeConfig.kurtosisVoteThreshold})  ${f.kurtosis < EarthquakeConfig.kurtosisVoteThreshold ? "PASS" : "fail"}');
      buf.writeln(
          '  Peak accel     : ${f.peakAcceleration.toStringAsFixed(4)} m/s²');
      buf.writeln('  → isEarthquake : ${f.isEarthquake}');
    }
    buf.write('──────────────────────────────────────────');
    return buf.toString();
  }
}

enum EarthquakeDebugSource { replay, live }

enum EarthquakeBlockReason { stationarity, gyroscope, triggerGate }
