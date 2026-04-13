// ignore_for_file: avoid_print
/// Standalone offline earthquake-detection pipeline simulator.
/// Replicates exactly the logic from:
///   - EarthquakeConfig
///   - StaLtaCalculator
///   - FeatureExtractor
/// No Flutter dependency — only dart:io and dart:math.
library;

import 'dart:io';
import 'dart:math' as math;

// ─── Constants (mirrors EarthquakeConfig) ───────────────────────────────────

const int staWindowSamples = 25;
const int ltaWindowSamples = 25 * 30; // 750
const double staLtaTriggerThreshold = 2.8;
const double minLtaAverage = 0.03;
const double noiseFloorMs2 = 0.03;

const int triggerWindowSamples = 50; // 2 s rolling
const int minTriggersInWindow = 18; // 36 % of window

const int postTriggerCollectionSamples = 25; // 1 s
const int featureWindowSamples = 100; // 4 s

const double iqrThreshold = 0.35;
const double zcThreshold = 4.0;
const double cavThreshold = 0.55;
const double kurtosisVoteThreshold = 60.0;
const double samplingIntervalSeconds = 40 / 1000.0; // 0.04 s

// ─── CSV parser ─────────────────────────────────────────────────────────────

List<List<double>> parseCsv(String path) {
  final lines = File(path).readAsLinesSync();
  final result = <List<double>>[];
  for (var i = 1; i < lines.length; i++) {
    // skip header
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final parts = line.split(',');
    if (parts.length < 3) continue;
    final x = double.parse(parts[0]);
    final y = double.parse(parts[1]);
    final z = double.parse(parts[2]);
    result.add([x, y, z]);
  }
  return result;
}

// ─── Net acceleration ────────────────────────────────────────────────────────

double computeNetAcc(double x, double y, double z) {
  var net = (math.sqrt(x * x + y * y + z * z) - 9.81).abs();
  if (net < noiseFloorMs2) net = 0.0;
  return net;
}

// ─── Feature extraction (mirrors FeatureExtractor.analyze) ──────────────────

class FeatureResult {
  final double iqr;
  final double zeroCrossingRate;
  final double cav;
  final double peakAcceleration;
  final double kurtosis;

  FeatureResult({
    required this.iqr,
    required this.zeroCrossingRate,
    required this.cav,
    required this.peakAcceleration,
    required this.kurtosis,
  });

  int get passedCount {
    var p = 0;
    if (iqr >= iqrThreshold) p++;
    if (zeroCrossingRate >= zcThreshold) p++;
    if (cav >= cavThreshold) p++;
    if (kurtosis < kurtosisVoteThreshold) p++;
    return p;
  }

  bool get isEarthquake => passedCount >= 2;
}

FeatureResult? extractFeatures(List<double> samples) {
  final n = samples.length;
  if (n < 10) return null;

  // IQR
  final sorted = List<double>.from(samples)..sort();
  final q1 = sorted[n ~/ 4];
  final q3 = sorted[(3 * n) ~/ 4];
  final iqr = q3 - q1;

  // Pass 1: mean, CAV, peak
  double sum = 0.0;
  double cav = 0.0;
  double peak = 0.0;
  for (var i = 0; i < n; i++) {
    final v = samples[i];
    sum += v;
    if (v > peak) peak = v;
    cav += v < 0 ? -v : v;
  }
  final mean = sum / n;
  cav *= samplingIntervalSeconds;

  // Variance & kurtosis moments
  double m2 = 0.0;
  double m4 = 0.0;
  for (var i = 0; i < n; i++) {
    final d = samples[i] - mean;
    final d2 = d * d;
    m2 += d2;
    m4 += d2 * d2;
  }
  m2 /= n;
  m4 /= n;
  final kurtosis = m2 > 1e-12 ? (m4 / (m2 * m2)) - 3.0 : 0.0;

  // Zero-crossing rate
  var crossings = 0;
  for (var i = 1; i < n; i++) {
    if ((samples[i - 1] - mean) * (samples[i] - mean) < 0) crossings++;
  }
  final zeroCrossingRate = crossings / (n * samplingIntervalSeconds);

  return FeatureResult(
    iqr: iqr,
    zeroCrossingRate: zeroCrossingRate,
    cav: cav,
    peakAcceleration: peak,
    kurtosis: kurtosis,
  );
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

String pct(double value, double threshold, {bool invertedPass = false}) {
  final margin = invertedPass
      ? (threshold - value) / threshold * 100
      : (value - threshold) / threshold * 100;
  final sign = margin >= 0 ? '+' : '';
  return '$sign${margin.toStringAsFixed(1)}%';
}

String fmt(double v) => v.toStringAsFixed(4);

// ─── Pipeline simulation ─────────────────────────────────────────────────────

void analyzeDataset(String name, String csvPath) {
  print('');
  print('══════════════════════════════════════════════════════════════════');
  print('  Dataset: $name');
  print('  File   : $csvPath');
  print('══════════════════════════════════════════════════════════════════');

  final rows = parseCsv(csvPath);
  final totalSamples = rows.length;
  print('  Total samples : $totalSamples  (${(totalSamples / 25.0).toStringAsFixed(1)} s at 25 Hz)');

  // STA/LTA state
  final staQueue = <double>[];
  final ltaQueue = <double>[];
  double staSum = 0.0;
  double ltaSum = 0.0;

  // Rolling trigger gate
  final triggerWindow = <bool>[]; // last 50 above-threshold flags
  int triggersInWindow = 0;

  // Post-trigger state
  bool inPostTrigger = false;
  int postTriggerCount = 0;
  int triggerGateFiredAt = -1;
  double ratioAtGate = 0.0;

  // Recent-samples ring buffer for feature window
  final recentNetAcc = <double>[];

  var detectionCount = 0;
  // cooldown tracking (skip retriggering within 750 samples = 30 s)
  int lastDetectionSample = -9999;
  const cooldownSamples = 25 * 60; // 60 s

  for (var si = 0; si < totalSamples; si++) {
    final r = rows[si];
    final netAcc = computeNetAcc(r[0], r[1], r[2]);

    // Keep rolling recent buffer (last featureWindowSamples)
    recentNetAcc.add(netAcc);
    if (recentNetAcc.length > featureWindowSamples) {
      recentNetAcc.removeAt(0);
    }

    // ── STA update ──
    staSum += netAcc;
    staQueue.add(netAcc);
    if (staQueue.length > staWindowSamples) {
      staSum -= staQueue.removeAt(0);
    }

    // ── LTA update (not frozen in offline script) ──
    ltaSum += netAcc;
    ltaQueue.add(netAcc);
    if (ltaQueue.length > ltaWindowSamples) {
      ltaSum -= ltaQueue.removeAt(0);
    }

    // ── Compute ratio ──
    double ratio = 0.0;
    if (ltaQueue.length >= ltaWindowSamples) {
      final ltaAvg = ltaSum / ltaQueue.length;
      if (ltaAvg >= minLtaAverage) {
        final staAvg = staSum / staQueue.length;
        ratio = staAvg / ltaAvg;
      }
    }

    final aboveThreshold = ratio >= staLtaTriggerThreshold;

    // ── Rolling trigger gate ──
    if (!inPostTrigger) {
      triggerWindow.add(aboveThreshold);
      if (aboveThreshold) triggersInWindow++;
      if (triggerWindow.length > triggerWindowSamples) {
        if (triggerWindow.removeAt(0)) triggersInWindow--;
      }

      final gateFired =
          triggerWindow.length == triggerWindowSamples &&
          triggersInWindow >= minTriggersInWindow;

      if (gateFired && (si - lastDetectionSample) > cooldownSamples) {
        inPostTrigger = true;
        postTriggerCount = 0;
        triggerGateFiredAt = si;
        ratioAtGate = ratio;
        triggerWindow.clear();
        triggersInWindow = 0;
      }
    } else {
      // ── Post-trigger collection ──
      postTriggerCount++;
      if (postTriggerCount >= postTriggerCollectionSamples) {
        // Feature extraction on last featureWindowSamples
        final window = List<double>.from(recentNetAcc);
        final result = extractFeatures(window);
        inPostTrigger = false;

        final timeS = triggerGateFiredAt / 25.0;
        detectionCount++;
        lastDetectionSample = si;

        print('');
        print('  ── DETECTION EVENT #$detectionCount ──────────────────────────────────');
        print('  Trigger gate fired : sample $triggerGateFiredAt  (t = ${timeS.toStringAsFixed(2)} s)');
        print('  STA/LTA ratio      : ${fmt(ratioAtGate)}  '
            '(threshold ${staLtaTriggerThreshold})  '
            'margin ${pct(ratioAtGate, staLtaTriggerThreshold)}');
        print('  Window used        : ${window.length} samples  '
            '(${(window.length / 25.0).toStringAsFixed(2)} s)');

        if (result == null) {
          print('  Feature extraction : NOT ENOUGH DATA');
        } else {
          final iqrPass = result.iqr >= iqrThreshold;
          final zcPass = result.zeroCrossingRate >= zcThreshold;
          final cavPass = result.cav >= cavThreshold;
          final kurtPass = result.kurtosis < kurtosisVoteThreshold;

          print('');
          print('  Feature Results:');
          print('    IQR          : ${fmt(result.iqr)}'
              '  threshold ${iqrThreshold}'
              '  margin ${pct(result.iqr, iqrThreshold)}'
              '  ${iqrPass ? "PASS ✓" : "FAIL ✗"}');
          print('    ZC rate      : ${fmt(result.zeroCrossingRate)}'
              '  threshold ${zcThreshold}'
              '  margin ${pct(result.zeroCrossingRate, zcThreshold)}'
              '  ${zcPass ? "PASS ✓" : "FAIL ✗"}');
          print('    CAV          : ${fmt(result.cav)}'
              '  threshold ${cavThreshold}'
              '  margin ${pct(result.cav, cavThreshold)}'
              '  ${cavPass ? "PASS ✓" : "FAIL ✗"}');
          print('    Kurtosis     : ${fmt(result.kurtosis)}'
              '  threshold <${kurtosisVoteThreshold}'
              '  margin ${pct(result.kurtosis, kurtosisVoteThreshold, invertedPass: true)}'
              '  ${kurtPass ? "PASS ✓" : "FAIL ✗"}');
          print('    Peak acc     : ${fmt(result.peakAcceleration)} m/s²');
          print('');
          print('    Votes passed : ${result.passedCount} / 4'
              '  (need ≥ 2)');
          print('    isEarthquake : ${result.isEarthquake}');
        }
      }
    }
  }

  if (detectionCount == 0) {
    print('');
    print('  No detection events triggered.');
    // Diagnostic: print max ratio seen
    double maxRatio = 0.0;
    int maxRatioSample = -1;
    final ltaQ2 = <double>[];
    final staQ2 = <double>[];
    double ltaS2 = 0.0;
    double staS2 = 0.0;
    for (var si = 0; si < totalSamples; si++) {
      final r = rows[si];
      final netAcc = computeNetAcc(r[0], r[1], r[2]);
      staS2 += netAcc;
      staQ2.add(netAcc);
      if (staQ2.length > staWindowSamples) staS2 -= staQ2.removeAt(0);
      ltaS2 += netAcc;
      ltaQ2.add(netAcc);
      if (ltaQ2.length > ltaWindowSamples) ltaS2 -= ltaQ2.removeAt(0);
      if (ltaQ2.length >= ltaWindowSamples) {
        final ltaAvg = ltaS2 / ltaQ2.length;
        if (ltaAvg >= minLtaAverage) {
          final staAvg = staS2 / staQ2.length;
          final r2 = staAvg / ltaAvg;
          if (r2 > maxRatio) {
            maxRatio = r2;
            maxRatioSample = si;
          }
        }
      }
    }
    print('  Diagnostic max STA/LTA ratio: ${fmt(maxRatio)}'
        ' at sample $maxRatioSample'
        ' (t = ${(maxRatioSample / 25.0).toStringAsFixed(2)} s)');
  }

  print('');
  print('  Total detections: $detectionCount');
}

// ─── Entry point ─────────────────────────────────────────────────────────────

void main() {
  const base =
      r'C:\Users\u\Documents\CodingProjects\BitirmeProjesi\hayat-agi-mobile'
      r'\assets\fixtures\earthquake';

  final datasets = [
    ('TK_0118__3c_25hz', '$base\\TK_0118__3c_25hz.csv'),
    ('TK_3139__3c_25hz', '$base\\TK_3139__3c_25hz.csv'),
    ('TK_4615__3c_25hz', '$base\\TK_4615__3c_25hz.csv'),
  ];

  print('');
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║   Earthquake Detection Pipeline — Offline Replay Analysis       ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');
  print('Config:');
  print('  STA window       : $staWindowSamples samples (1 s)');
  print('  LTA window       : $ltaWindowSamples samples (30 s)');
  print('  STA/LTA thresh   : $staLtaTriggerThreshold');
  print('  minLtaAverage    : $minLtaAverage m/s²');
  print('  noiseFloor       : $noiseFloorMs2 m/s²');
  print('  Trigger gate     : $minTriggersInWindow / $triggerWindowSamples');
  print('  Post-trigger     : $postTriggerCollectionSamples samples');
  print('  Feature window   : $featureWindowSamples samples (4 s)');
  print('  IQR threshold    : $iqrThreshold m/s²');
  print('  ZC threshold     : $zcThreshold crossings/s');
  print('  CAV threshold    : $cavThreshold m/s²·s');
  print('  Kurtosis thresh  : <$kurtosisVoteThreshold (low = pass)');

  for (final (name, path) in datasets) {
    analyzeDataset(name, path);
  }

  print('');
  print('═══════════════════════ END OF REPORT ════════════════════════════');
}
