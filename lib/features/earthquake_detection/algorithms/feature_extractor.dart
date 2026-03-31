import '../earthquake_config.dart';

class FeatureResult {
  const FeatureResult({
    required this.iqr,
    required this.zeroCrossingRate,
    required this.cav,
    required this.peakAcceleration,
    required this.kurtosis,
  });

  final double iqr;
  final double zeroCrossingRate;
  final double cav;
  final double peakAcceleration;

  /// Excess kurtosis of the net-acceleration distribution.
  /// Gaussian = 0, impulsive human motion > 3, sustained shaking ≈ 0–2.
  final double kurtosis;

  /// True if at least two of IQR, ZC, and CAV pass their thresholds (MyShake-style
  /// feature layer; avoids one marginal metric vetoing a clear event).
  ///
  /// Additionally, very high kurtosis vetoes the detection because impulsive
  /// human activities (phone pickup, single knock) produce sharp spikes that
  /// can fool individual metrics.
  bool get isEarthquake {
    // Veto: impulsive signal — likely human activity, not sustained shaking
    if (kurtosis > EarthquakeConfig.kurtosisVetoThreshold) return false;

    var passed = 0;
    if (iqr >= EarthquakeConfig.iqrThreshold) passed++;
    if (zeroCrossingRate >= EarthquakeConfig.zcThreshold) passed++;
    if (cav >= EarthquakeConfig.cavThreshold) passed++;
    return passed >= 2;
  }

  @override
  String toString() =>
      'FeatureResult(IQR=$iqr, ZC=$zeroCrossingRate, CAV=$cav, '
      'kurt=$kurtosis, peak=$peakAcceleration, earthquake=$isEarthquake)';
}

class FeatureExtractor {
  /// Analyze a list of net acceleration magnitudes (m/s²).
  /// [samples] should match [EarthquakeConfig.featureWindowSamples] when full.
  /// Returns null if not enough samples to analyze.
  static FeatureResult? analyze(List<double> samples) {
    if (samples.length < 10) return null; // need at least 10 samples

    // dt per sample in seconds
    final dt = EarthquakeConfig.samplingInterval.inMilliseconds / 1000.0;
    final n = samples.length;

    // --- IQR ---
    final sorted = List<double>.from(samples)..sort();
    final q1 = sorted[n ~/ 4];
    final q3 = sorted[(3 * n) ~/ 4];
    final iqr = q3 - q1;

    // --- ZC (Zero Crossing Rate) ---
    // Count how many times the signal crosses zero (sign changes relative to mean)
    final mean = samples.fold(0.0, (a, b) => a + b) / n;
    int crossings = 0;
    for (int i = 1; i < n; i++) {
      final prev = samples[i - 1] - mean;
      final curr = samples[i] - mean;
      if (prev * curr < 0) crossings++;
    }
    // Normalize to crossings per second
    final windowSeconds = n * dt;
    final zeroCrossingRate = crossings / windowSeconds;

    // --- CAV (Cumulative Absolute Velocity) ---
    // sum(|a_i| * dt) over the window
    final cav = samples.fold(0.0, (sum, a) => sum + a.abs()) * dt;

    // --- Peak acceleration ---
    final peakAcceleration = samples.fold(0.0, (max, a) => a > max ? a : max);

    // --- Kurtosis (excess) ---
    // Kurt = E[(x-μ)⁴] / σ⁴ − 3
    // Gaussian = 0. Impulsive human motion > 3. Sustained shaking ≈ 0–2.
    final m2 = samples.fold(0.0, (s, x) => s + (x - mean) * (x - mean)) / n;
    final kurtosis = m2 > 1e-12
        ? (samples.fold(0.0, (s, x) {
              final d = x - mean;
              return s + d * d * d * d;
            }) /
                n /
                (m2 * m2)) -
            3.0
        : 0.0;

    return FeatureResult(
      iqr: iqr,
      zeroCrossingRate: zeroCrossingRate,
      cav: cav,
      peakAcceleration: peakAcceleration,
      kurtosis: kurtosis,
    );
  }
}
