/// Central configuration for the earthquake detection pipeline.
///
/// All values are based on OpenEEW (Apache 2.0) and MyShake (Kong et al., 2016)
/// reference implementations. Tune these after testing with AFAD seismic data.
class EarthquakeConfig {
  EarthquakeConfig._();

  // ── Sensor ──────────────────────────────────────────────────────────────────

  /// Accelerometer sampling interval (25 Hz = 40 ms per sample).
  static const Duration samplingInterval = Duration(milliseconds: 40);

  /// Samples per second derived from [samplingInterval].
  static const int samplesPerSecond = 25;

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
  /// Raised from 2.5 to 3.0 to focus on stronger earthquakes and reduce false
  /// positives. Strong events at moderate distance produce ratios above 4.0;
  /// hand-held motion typically peaks around 2.0–2.5.
  static const double staLtaTriggerThreshold = 3.0;

  // ── Rolling-window trigger gate ─────────────────────────────────────────────
  //
  // Instead of requiring N *consecutive* samples above threshold (which resets
  // on every direction-reversal during natural shaking), we track how many of
  // the last [triggerWindowSamples] samples exceeded the threshold.
  // This tolerates brief dips without wiping progress.
  //
  // At 25 Hz:  triggerWindowSamples = 50  →  2-second rolling window
  //            minTriggersInWindow   = 15  →  30 % of window must be above
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
  static const int minTriggersInWindow = 18;

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

  // ── Feature extraction (IQR / ZC / CAV) ─────────────────────────────────────

  /// Number of samples analysed by the IQR/ZC/CAV feature layer.
  /// 4 seconds of data at 25 Hz — covers the full [sustainedTriggerSamples]
  /// window (3 s) plus 1 s of context before the trigger began.
  static const int featureWindowSamples = samplesPerSecond * 4; // 100

  /// IQR threshold (m/s²). Raised from 0.2 to 0.35 for stronger earthquake focus.
  /// Strong events produce IQR > 0.5 m/s²; hand-held noise stays below 0.3.
  static const double iqrThreshold = 0.35;

  /// Zero-crossing rate (ZC) threshold (crossings per second).
  /// Strong earthquake signals have rich oscillatory content at 1–10 Hz
  /// producing ZC > 5 crossings/s. Raised from 3.0 to cut marginal events.
  static const double zcThreshold = 4.0;

  /// Cumulative Absolute Velocity threshold (m/s²·s).
  /// Raised from 0.5 to 0.7 for stronger earthquake focus. Strong events
  /// easily exceed 1.0; hand-held motion rarely reaches 0.7 in 4s.
  static const double cavThreshold = 0.7;

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
  static const double stationarityVarianceThreshold = 0.005;

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
  static const double gyroscopeVetoThreshold = 0.35;

  /// Window for tracking recent peak gyroscope reading (samples at 25 Hz).
  static const int gyroscopeWindowSamples = samplesPerSecond * 2; // 50

  // ── Kurtosis Veto ───────────────────────────────────────────────────────────
  //
  // Excess kurtosis measures "tailedness" of the acceleration distribution.
  //   Gaussian (sustained shaking) ≈ 0
  //   Impulsive human activity (tap, knock, single jerk) → high kurtosis (> 5)
  //
  // Applied as a veto in the feature layer: if kurtosis is too high, reject.

  /// Maximum excess kurtosis before the feature layer vetoes the detection.
  static const double kurtosisVetoThreshold = 6.0;

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
  static const double ltaMaxVariance = 0.05;

  // ── Cooldown ────────────────────────────────────────────────────────────────

  /// Minimum time between consecutive detections (prevents double-triggering).
  static const Duration cooldownDuration = Duration(seconds: 60);

  // ── User confirmation ────────────────────────────────────────────────────────

  /// How long to wait for user response before auto-confirming.
  /// Silence = user may be trapped → auto-activate disaster mode.
  static const Duration confirmationTimeout = Duration(seconds: 30);
}
