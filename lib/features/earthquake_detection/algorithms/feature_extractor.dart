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

  /// True if at least two of IQR, ZC, CAV, and kurtosis pass their thresholds
  /// (MyShake-style 2-of-4 vote). Low kurtosis (< threshold) votes for detection
  /// because sustained shaking has near-Gaussian distribution; impulsive human
  /// motion has high kurtosis and loses this vote.
  bool get isEarthquake {
    // 2-of-4 vote: IQR, ZC, CAV, and kurtosis (low kurtosis = sustained shaking, not impulsive)
    var passed = 0;
    if (iqr >= EarthquakeConfig.iqrThreshold) passed++;
    if (zeroCrossingRate >= EarthquakeConfig.zcThreshold) passed++;
    if (cav >= EarthquakeConfig.cavThreshold) passed++;
    if (kurtosis < EarthquakeConfig.kurtosisVoteThreshold) passed++;
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

    const dt = EarthquakeConfig.samplingIntervalSeconds;
    final n = samples.length;

    // --- IQR (requires sort — unavoidable separate step) ---
    final sorted = List<double>.from(samples)..sort();
    final q1 = sorted[n ~/ 4];
    final q3 = sorted[(3 * n) ~/ 4];
    final iqr = q3 - q1;

    // --- Pass 1: mean, m2 (variance), m4 (for kurtosis), cav, peak ---
    double sum = 0.0;
    double cav = 0.0;
    double peak = 0.0;
    for (int i = 0; i < n; i++) {
      final v = samples[i];
      sum += v;
      if (v > peak) peak = v;
      cav += v < 0 ? -v : v;
    }
    final mean = sum / n;
    cav *= dt;

    double m2 = 0.0;
    double m4 = 0.0;
    for (int i = 0; i < n; i++) {
      final d = samples[i] - mean;
      final d2 = d * d;
      m2 += d2;
      m4 += d2 * d2;
    }
    m2 /= n;
    m4 /= n;

    final kurtosis = m2 > 1e-12 ? (m4 / (m2 * m2)) - 3.0 : 0.0;

    // --- Pass 2: zero-crossing rate (needs mean from pass 1) ---
    int crossings = 0;
    for (int i = 1; i < n; i++) {
      if ((samples[i - 1] - mean) * (samples[i] - mean) < 0) crossings++;
    }
    final zeroCrossingRate = crossings / (n * dt);

    return FeatureResult(
      iqr: iqr,
      zeroCrossingRate: zeroCrossingRate,
      cav: cav,
      peakAcceleration: peak,
      kurtosis: kurtosis,
    );
  }
}
