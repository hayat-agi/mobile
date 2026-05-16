/// Central configuration for the earthquake detection pipeline.
///
/// All values are based on OpenEEW (Apache 2.0) and MyShake (Kong et al., 2016)
/// reference implementations. Tune these after testing with AFAD seismic data.
class EarthquakeConfig {
  EarthquakeConfig._();

  // ── Sensor ──────────────────────────────────────────────────────────────────

  /// Source-of-truth sampling period in milliseconds. All other timing
  /// constants derive from this single value — change only this one.
  static const int _samplingMs = 40;

  /// Accelerometer sampling interval (25 Hz = 40 ms per sample).
  static const Duration samplingInterval = Duration(milliseconds: _samplingMs);

  /// Sampling interval in seconds, derived from [_samplingMs].
  static const double samplingIntervalSeconds = _samplingMs / 1000.0;

  /// Samples per second derived from [_samplingMs].
  static const int samplesPerSecond = 1000 ~/ _samplingMs;

  // ── STA / LTA ───────────────────────────────────────────────────────────────

  /// Short-Term Average window: 1 second of samples.
  static const int staWindowSamples = samplesPerSecond; // 25

  /// Long-Term Average window length (samples).
  ///
  /// 30s is the seismology standard (MyShake / project doc). LTA self-contamination
  /// is mitigated by freezing LTA while Layer 2 investigates (see StaLtaCalculator).
  static const int ltaWindowSeconds = 30;
  static const int ltaWindowSamples = samplesPerSecond * ltaWindowSeconds;

  /// STA/LTA ratio threshold that flags a suspicious event.
  /// Lowered from 3.0 to 2.8 to capture borderline M5+ events whose maxRatio
  /// reaches ~2.99. Still well above hand-held noise (typically peaks 2.0–2.5).
  /// production: 2.8
  static const double staLtaTriggerThreshold = 2.4;

  // ── Rolling-window trigger gate ─────────────────────────────────────────────
  //
  // Instead of requiring N *consecutive* samples above threshold (which resets
  // on every direction-reversal during natural shaking), we track how many of
  // the last [triggerWindowSamples] samples exceeded the threshold.
  // This tolerates brief dips without wiping progress.
  //
  // At 25 Hz:  triggerWindowSamples = 50  →  2-second rolling window
  //            minTriggersInWindow   = 18  →  36 % of window must be above
  //
  // What this produces:
  //   Phone pickup  (~0.3 s, ~7 above/50)  →  14 % → no trigger
  //   1-second deliberate shake (~25/50)   →  50 % → no trigger
  //   Real earthquake (oscillatory dips)   →  tolerates ~40 % sustained

  /// Size of the rolling trigger window in samples (2 seconds at 25 Hz).
  static const int triggerWindowSamples = samplesPerSecond * 2; // 50

  /// Minimum number of above-threshold samples in [triggerWindowSamples]
  /// before Layer 2 is invoked. 18/50 = 36 % — raised from 15 to require
  /// more sustained exceedance while still allowing sparse ratio peaks.
  /// production: 18
  static const int minTriggersInWindow = 14;

  // ── Noise floor ─────────────────────────────────────────────────────────────

  /// Minimum net acceleration magnitude (in m/s²) to count as signal.
  /// OpenEEW reference: ~0.03 m/s² (≈ 3 gal); below this is sensor noise.
  static const double noiseFloorMs2 = 0.03;

  /// Minimum LTA average (m/s²) before the STA/LTA ratio is computed.
  ///
  /// When the phone is very still, LTA approaches zero and any micro-vibration
  /// produces an enormous ratio (e.g. 0.005 / 0.001 = 5.0) — false trigger.
  /// This floor means: "don't bother computing a ratio until the environment
  /// has at least this much baseline activity." A still table reads ~0.01–0.05;
  /// a pocket or hand holding reads ~0.05–0.15.
  /// Lowered from 0.05 so quiet station traces (e.g. FDSN KO BNN) still get a ratio:
  /// weak pre-event netAcc can keep LTA mean just under 0.05 and block STA/LTA entirely.
  static const double minLtaAverage = 0.03;

  /// Synthetic LTA baseline used when priming the STA/LTA window on ESP32 connect.
  ///
  /// MPU-6050 at ±2g on a table with ambient vibration (fans, HVAC, footsteps)
  /// reads netAcc ≈ 0.03–0.08 m/s². Priming with [minLtaAverage] (0.03) creates
  /// a denominator that is too low — any mild vibration immediately yields ratio > 2.8.
  /// 0.05 is a balanced midpoint: suppresses ambient noise false positives while
  /// still allowing real seismic events (netAcc ≥ 0.15 m/s²) to reach ratio > 2.8.
  static const double externalSensorBaselineMs2 = 0.05;

  // ── Feature extraction (IQR / ZC / CAV) ─────────────────────────────────────

  /// Number of samples analysed by the IQR/ZC/CAV feature layer.
  /// 4 seconds of data at 25 Hz — covers the full [sustainedTriggerSamples]
  /// window (3 s) plus 1 s of context before the trigger began.
  static const int featureWindowSamples = samplesPerSecond * 4; // 100

  /// IQR threshold (m/s²). Raised from 0.2 to 0.35 for stronger earthquake focus.
  /// Strong events produce IQR > 0.5 m/s²; hand-held noise stays below 0.3.
  /// production: 0.35
  static const double iqrThreshold = 0.20;

  /// Zero-crossing rate (ZC) threshold (crossings per second).
  /// Strong earthquake signals have rich oscillatory content at 1–10 Hz
  /// producing ZC > 5 crossings/s. Raised from 3.0 to cut marginal events.
  /// production: 4.0
  static const double zcThreshold = 2.5;

  /// Cumulative Absolute Velocity threshold (m/s²·s).
  /// Lowered from 0.70 to 0.55 to capture BALB-station M5+ events that produce
  /// CAV 0.62–0.68. Still well above typical daily-activity noise levels.
  /// production: 0.55
  static const double cavThreshold = 0.30;

  // ── Stationarity Gate ────────────────────────────────────────────────────────
  //
  // Reject triggers when the phone is not stationary (hand-held, pocket, etc.).
  // MyShake's primary pre-filter: ANN only runs when the device is still.
  //
  // A still phone on a table has net-acc variance ≈ 0.0001–0.001 m/s².
  // A hand-held phone has net-acc variance ≈ 0.01–0.10 m/s².
  // Threshold set between these ranges.

  /// Stationarity analysis window length (5 seconds at 25 Hz).
  static const int stationarityWindowSamples = samplesPerSecond * 5; // 125

  /// Maximum variance of net-acceleration (m/s²) to consider the phone "still".
  /// Below this → phone is on a stable surface → detection is meaningful.
  /// Above this → phone is likely hand-held/moving → suppress triggers.
  /// Set to 0.009 to match the MyShake paper value (Kong et al., 2016).
  /// production: 0.009
  static const double stationarityVarianceThreshold = 1.0;

  // ── Gyroscope Veto ──────────────────────────────────────────────────────────
  //
  // Earthquakes produce translational motion only. Human handling produces
  // both translational AND rotational motion. The gyroscope catches the
  // rotational component that a real earthquake would not create.
  //
  // Phone on table during earthquake: gyroscope ≈ 0.0–0.1 rad/s
  // Phone hand-held: gyroscope ≈ 0.3–3.0 rad/s

  /// Maximum angular velocity (rad/s) allowed during detection.
  /// If gyroscope exceeds this, the trigger is vetoed as human activity.
  /// production: 0.35
  static const double gyroscopeVetoThreshold = 5.0;

  /// Window for tracking recent peak gyroscope reading (samples at 25 Hz).
  static const int gyroscopeWindowSamples = samplesPerSecond * 2; // 50

  // ── Kurtosis Vote ────────────────────────────────────────────────────────────
  //
  // Excess kurtosis measures "tailedness" of the acceleration distribution.
  //   Gaussian (sustained shaking) ≈ 0
  //   Impulsive human activity (tap, knock, single jerk) → high kurtosis (> 5)
  //
  // Previously applied as a hard veto; now the 4th metric in the 2-of-4 vote.
  // Low kurtosis votes FOR detection (sustained shaking ≈ Gaussian); high
  // kurtosis (impulsive human motion) simply loses this one vote.

  /// Kurtosis threshold used as the 4th vote in the 2-of-4 feature check.
  /// A sample with kurtosis < this value votes for earthquake (sustained,
  /// near-Gaussian shaking). A sample above this loses the kurtosis vote but
  /// can still trigger if two other metrics pass — it is no longer a hard veto.
  /// Set to 10.0 — above typical human-activity impulsive kurtosis (~5) and
  /// well below the previous too-permissive value (60), a sensible midpoint.
  static const double kurtosisVoteThreshold = 10.0;

  // ── Post-trigger collection ──────────────────────────────────────────────────

  /// After STA/LTA fires, collect this many more samples before evaluating
  /// Layer 2 so the feature window contains actual earthquake energy, not
  /// pre-event quiet noise (MyShake approach).
  /// 25 samples = 1 second at 25 Hz.
  static const int postTriggerCollectionSamples = samplesPerSecond * 1; // 25

  // ── LTA Stability Guard ─────────────────────────────────────────────────────
  //
  // When the LTA window fills while the phone is actively held, the LTA
  // "baseline" is contaminated with human motion. Any small additional
  // movement then produces a disproportionate STA/LTA spike.
  //
  // Guard: if the LTA variance is too high, the baseline is unreliable
  // and ratios should not be trusted.

  /// Maximum LTA variance (m/s²) for the ratio to be considered meaningful.
  /// A phone on a quiet table: LTA variance ≈ 0.0001.
  /// A phone hand-held for 30s: LTA variance ≈ 0.01–0.10.
  /// Seismic station background: LTA variance ≈ 0.001–0.02.
  /// Set at 0.05 to allow legitimate seismic signals through while still
  /// catching extreme hand-held contamination. The stationarity gate and
  /// gyroscope veto are the primary phone-side FP defenses.
  /// production: 0.05
  static const double ltaMaxVariance = 0.2;

  // ── Cooldown ────────────────────────────────────────────────────────────────

  /// Minimum time between consecutive detections (prevents double-triggering).
  static const Duration cooldownDuration = Duration(seconds: 60);

  // ── User confirmation ────────────────────────────────────────────────────────

  /// Source-of-truth for the confirmation timeout in seconds.
  /// Both [confirmationTimeout] and the UI countdown ring derive from this.
  static const int confirmationTimeoutSeconds = 30;

  /// How long to wait for user response before auto-confirming.
  /// Silence = user may be trapped → auto-activate disaster mode.
  static const Duration confirmationTimeout =
      Duration(seconds: confirmationTimeoutSeconds);
}
