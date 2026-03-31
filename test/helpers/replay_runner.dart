import 'dart:collection';
import 'dart:math' as math;

import 'package:hayat_agi_mobile/features/earthquake_detection/algorithms/feature_extractor.dart';
import 'package:hayat_agi_mobile/features/earthquake_detection/algorithms/sta_lta.dart';
import 'package:hayat_agi_mobile/features/earthquake_detection/algorithms/stationarity_detector.dart';
import 'package:hayat_agi_mobile/features/earthquake_detection/earthquake_config.dart';

int _featurePassCount(FeatureResult f) {
  var n = 0;
  if (f.iqr >= EarthquakeConfig.iqrThreshold) n++;
  if (f.zeroCrossingRate >= EarthquakeConfig.zcThreshold) n++;
  if (f.cav >= EarthquakeConfig.cavThreshold) n++;
  return n;
}

/// Holds the outcome of running the full detection pipeline over a single
/// recording file.
class ReplayResult {
  const ReplayResult({
    required this.fileName,
    required this.triggered,
    required this.totalSamples,
    required this.maxRatio,
    required this.gateEverMet,
    required this.maxTriggerCount,
    this.triggerSampleIndex,
    this.staLtaRatio,
    this.features,
    this.bestFeatures,
    this.stationaryAtTrigger,
  });

  /// Short name or path of the source CSV file.
  final String fileName;

  /// Whether Layer 1 + Layer 2 both passed at some point during the recording.
  final bool triggered;

  /// Total number of samples fed through the pipeline.
  final int totalSamples;

  /// Highest STA/LTA ratio seen across all samples.
  final double maxRatio;

  /// True if the rolling gate (minTriggersInWindow) was ever satisfied.
  final bool gateEverMet;

  /// Maximum triggerWindowAboveCount observed when the window was full.
  final int maxTriggerCount;

  /// Index of the first sample at which detection fired, or null if no trigger.
  final int? triggerSampleIndex;

  /// STA/LTA ratio at the moment detection fired.
  final double? staLtaRatio;

  /// Feature values at trigger time when [triggered] is true.
  final FeatureResult? features;

  /// Best Layer 2 attempt when gate was met but [isEarthquake] was false
  /// (highest count of passed thresholds among IQR/ZC/CAV).
  final FeatureResult? bestFeatures;

  /// Whether the stationarity detector reported "still" at trigger time.
  final bool? stationaryAtTrigger;
}

/// Replays a pre-recorded accelerometer time-series through the same
/// two-layer detection pipeline used in [EarthquakeDetectionService].
///
/// Note: Stationarity gate and gyroscope veto are **bypassed** in replay
/// (CSV files represent a phone on a stable surface — the seismic station).
/// However, the LTA stability guard IS active since it operates on the
/// same acceleration data and catches baseline contamination.
class ReplayRunner {
  /// Run the full detection pipeline on [samples] (x, y, z in m/s²).
  static ReplayResult run(
    String fileName,
    List<(double, double, double)> samples,
  ) {
    final staLta = StaLtaCalculator();
    final stationarity = StationarityDetector();
    final featureBuffer = Queue<double>();
    final triggerWindow = Queue<bool>();
    var triggerWindowAboveCount = 0;
    var maxRatio = 0.0;
    var gateEverMet = false;
    var maxTriggerCount = 0;
    FeatureResult? bestFeatures;
    var bestPassCount = -1;

    for (var i = 0; i < samples.length; i++) {
      final (x, y, z) = samples[i];

      final magnitude = math.sqrt(x * x + y * y + z * z);
      final netAcc = (magnitude - 9.81).abs();

      // Feed stationarity detector (for diagnostics, not used as gate in replay)
      stationarity.addSample(netAcc);

      final ratio = staLta.addSample(x, y, z);
      if (ratio > maxRatio) maxRatio = ratio;

      featureBuffer.addLast(netAcc);
      if (featureBuffer.length > EarthquakeConfig.featureWindowSamples) {
        featureBuffer.removeFirst();
      }

      final isAbove = staLta.isTriggered;
      if (isAbove) triggerWindowAboveCount++;
      triggerWindow.addLast(isAbove);
      if (triggerWindow.length > EarthquakeConfig.triggerWindowSamples) {
        if (triggerWindow.removeFirst()) triggerWindowAboveCount--;
      }

      if (triggerWindow.length < EarthquakeConfig.triggerWindowSamples) {
        continue;
      }
      if (triggerWindowAboveCount > maxTriggerCount) {
        maxTriggerCount = triggerWindowAboveCount;
      }

      if (triggerWindowAboveCount < EarthquakeConfig.minTriggersInWindow) {
        staLta.unfreezeLta();
        continue;
      }

      staLta.freezeLta();
      gateEverMet = true;

      final features = FeatureExtractor.analyze(featureBuffer.toList());
      if (features != null) {
        final pc = _featurePassCount(features);
        if (pc > bestPassCount) {
          bestPassCount = pc;
          bestFeatures = features;
        }
        if (features.isEarthquake) {
          return ReplayResult(
            fileName: fileName,
            triggered: true,
            totalSamples: samples.length,
            maxRatio: maxRatio,
            gateEverMet: true,
            maxTriggerCount: maxTriggerCount,
            triggerSampleIndex: i,
            staLtaRatio: ratio,
            features: features,
            bestFeatures: bestFeatures,
            stationaryAtTrigger: stationarity.isStationary,
          );
        }
      }
    }

    return ReplayResult(
      fileName: fileName,
      triggered: false,
      totalSamples: samples.length,
      maxRatio: maxRatio,
      gateEverMet: gateEverMet,
      maxTriggerCount: maxTriggerCount,
      bestFeatures: bestFeatures,
    );
  }
}
