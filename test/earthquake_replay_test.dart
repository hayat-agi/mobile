// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/earthquake_detection/earthquake_config.dart';

import 'helpers/replay_runner.dart';

// ── CSV helpers ──────────────────────────────────────────────────────────────

/// Parse a CSV file that was produced by tool/convert_sac_to_csv.py.
/// Format: one optional header line (starts with a letter), then rows of
///   acc_x,acc_y,acc_z  (m/s², 25 Hz)
List<(double, double, double)> _parseCsv(File file) {
  final samples = <(double, double, double)>[];
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith(RegExp(r'[a-zA-Z]'))) continue;
    final p = t.split(',');
    if (p.length < 3) continue;
    final x = double.tryParse(p[0]) ?? 0.0;
    final y = double.tryParse(p[1]) ?? 0.0;
    final z = double.tryParse(p[2]) ?? 0.0;
    samples.add((x, y, z));
  }
  return samples;
}

/// Return all .csv files in [dirPath], sorted alphabetically.
List<File> _csvFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.csv'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

// ── Summary table ────────────────────────────────────────────────────────────

void _printSummaryTable(List<ReplayResult> results) {
  // File, Trig, Gate, MaxCt, Sample, Ratio, IQR, ZC, CAV, Kurt, Peak
  const w = [30, 7, 5, 5, 6, 6, 5, 5, 5, 5, 6];

  String cell(String s, int width) =>
      (s.length > width ? '${s.substring(0, width - 1)}…' : s).padRight(width);

  final headers = [
    'File',
    'Trig',
    'Gate',
    'MaxCt',
    'Samp',
    'Ratio',
    'IQR',
    'ZC',
    'CAV',
    'Kurt',
    'Peak',
  ];
  final header =
      '| ${headers.indexed.map((e) => cell(e.$2, w[e.$1])).join(' | ')} |';
  final sep = '|-${w.map((n) => '-' * n).join('-|-')}-|';

  print('\n──────────────── Earthquake Detection Replay Results ────────────────');
  print(header);
  print(sep);

  for (final r in results) {
    final name = r.fileName.split(Platform.pathSeparator).last;
    final feat = r.triggered ? r.features : r.bestFeatures;
    final row = [
      name,
      r.triggered ? 'YES' : 'NO',
      r.gateEverMet ? 'Y' : 'N',
      r.maxTriggerCount.toString(),
      r.triggerSampleIndex?.toString() ?? '-',
      (r.triggered ? r.staLtaRatio! : r.maxRatio).toStringAsFixed(2),
      feat?.iqr.toStringAsFixed(2) ?? '-',
      feat?.zeroCrossingRate.toStringAsFixed(2) ?? '-',
      feat?.cav.toStringAsFixed(2) ?? '-',
      feat?.kurtosis.toStringAsFixed(1) ?? '-',
      feat?.peakAcceleration.toStringAsFixed(2) ?? '-',
    ];
    print('| ${row.indexed.map((e) => cell(e.$2, w[e.$1])).join(' | ')} |');
  }

  final truePos = results.where((r) => r.triggered && _isEarthquakeFixture(r)).length;
  final falseNeg = results.where((r) => !r.triggered && _isEarthquakeFixture(r)).length;
  final trueNeg = results.where((r) => !r.triggered && !_isEarthquakeFixture(r)).length;
  final falsePos = results.where((r) => r.triggered && !_isEarthquakeFixture(r)).length;
  print('');
  print('  TP=$truePos  FN=$falseNeg  TN=$trueNeg  FP=$falsePos');
  print('  Layer 2: 2-of-3 (IQR≥${EarthquakeConfig.iqrThreshold}, '
      'ZC≥${EarthquakeConfig.zcThreshold}, CAV≥${EarthquakeConfig.cavThreshold}) '
      '+ kurt veto >${EarthquakeConfig.kurtosisVetoThreshold}');
  print('  STA/LTA≥${EarthquakeConfig.staLtaTriggerThreshold}, '
      'gate ${EarthquakeConfig.minTriggersInWindow}/${EarthquakeConfig.triggerWindowSamples}');
  print('─────────────────────────────────────────────────────────────────────\n');
}

bool _isEarthquakeFixture(ReplayResult r) =>
    r.fileName.contains('earthquake') || r.fileName.contains('kahramanmaras');

// ── Test body ─────────────────────────────────────────────────────────────────

void main() {
  // Accumulates results from every test so the summary table can be printed
  // once all tests have finished via tearDownAll.
  final allResults = <ReplayResult>[];

  // ── Earthquake files: MUST trigger ─────────────────────────────────────────
  group('Earthquake files should trigger', () {
    final files = _csvFiles('test/fixtures/earthquake');

    if (files.isEmpty) {
      test('(no earthquake CSVs — skipping)', () {
        print(
          '\n'
          '  No earthquake CSV fixtures found in test/fixtures/earthquake/\n'
          '  1. Download the AFAD/Zenodo dataset:\n'
          '     https://zenodo.org/records/16930394\n'
          '  2. Convert SAC → CSV:\n'
          '     cd tool && pip install -r requirements.txt\n'
          '     python convert_sac_to_csv.py <sac_dir> ../test/fixtures/earthquake\n'
          '  See docs/plans/afad_seismic_data_replay_testing.plan.md for full instructions.\n',
        );
      });
    }

    for (final file in files) {
      final label = file.path.split(Platform.pathSeparator).last;
      test(label, () {
        final samples = _parseCsv(file);
        expect(
          samples,
          isNotEmpty,
          reason: '$label: CSV is empty or could not be parsed.',
        );

        final result = ReplayRunner.run(file.path, samples);
        allResults.add(result);

        expect(
          result.triggered,
          isTrue,
          reason: '$label did not trigger.\n'
              '  Samples: ${result.totalSamples}  maxRatio: ${result.maxRatio.toStringAsFixed(3)} '
              '(STA/LTA threshold: ${EarthquakeConfig.staLtaTriggerThreshold})\n'
              '  Gate ever met: ${result.gateEverMet}  maxTriggerCount: ${result.maxTriggerCount}/'
              '${EarthquakeConfig.triggerWindowSamples} (need '
              '${EarthquakeConfig.minTriggersInWindow})\n'
              '  Best Layer-2 attempt: ${result.bestFeatures}\n'
              '  Tune earthquake_config.dart or review LTA freeze / 2-of-3 thresholds.',
        );
      });
    }
  });

  // ── Daily-activity files: must NOT trigger ──────────────────────────────────
  group('Daily activity files should NOT trigger', () {
    final files = _csvFiles('test/fixtures/daily');

    if (files.isEmpty) {
      test('(no daily CSVs — skipping)', () {
        print(
          '\n'
          '  No daily-activity CSV fixtures found in test/fixtures/daily/\n'
          '  Record phone sensor data (walking, bus, table, drop) using any\n'
          '  sensor-logger app and export as CSV with columns acc_x,acc_y,acc_z.\n',
        );
      });
    }

    for (final file in files) {
      final label = file.path.split(Platform.pathSeparator).last;
      test(label, () {
        final samples = _parseCsv(file);
        expect(
          samples,
          isNotEmpty,
          reason: '$label: CSV is empty or could not be parsed.',
        );

        final result = ReplayRunner.run(file.path, samples);
        allResults.add(result);

        expect(
          result.triggered,
          isFalse,
          reason: 'FALSE POSITIVE in $label!\n'
              '  Triggered at sample ${result.triggerSampleIndex} '
              '(ratio: ${result.staLtaRatio?.toStringAsFixed(3)})\n'
              '  IQR=${result.features?.iqr.toStringAsFixed(2)}  '
              'ZC=${result.features?.zeroCrossingRate.toStringAsFixed(2)}  '
              'CAV=${result.features?.cav.toStringAsFixed(2)}\n'
              '  Hint: raise iqrThreshold, zcThreshold, or cavThreshold '
              'in earthquake_config.dart.',
        );
      });
    }
  });

  // ── Summary table (printed after all tests complete) ────────────────────────
  tearDownAll(() {
    if (allResults.isNotEmpty) _printSummaryTable(allResults);
  });
}
