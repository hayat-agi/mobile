import 'dart:collection';
import 'dart:math' as math;

import '../earthquake_config.dart';

class StaLtaCalculator {
  final Queue<double> _staBuffer = Queue<double>();
  final Queue<double> _ltaBuffer = Queue<double>();
  double _staSum = 0.0;
  double _ltaSum = 0.0;
  double _currentRatio = 0.0;
  bool _ltaFrozen = false;

  double get currentRatio => _currentRatio;

  /// When true, LTA buffer does not advance — keeps pre-event background for ratio.
  void freezeLta() => _ltaFrozen = true;

  void unfreezeLta() => _ltaFrozen = false;

  bool get isLtaReady =>
      _ltaBuffer.length >= EarthquakeConfig.ltaWindowSamples;

  bool get isTriggered =>
      _currentRatio >= EarthquakeConfig.staLtaTriggerThreshold;

  double addSample(double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    var netAcc = (magnitude - 9.81).abs();
    if (netAcc < EarthquakeConfig.noiseFloorMs2) {
      netAcc = 0.0;
    }

    _staSum += netAcc;
    _staBuffer.addLast(netAcc);
    if (_staBuffer.length > EarthquakeConfig.staWindowSamples) {
      _staSum -= _staBuffer.removeFirst();
    }

    if (!_ltaFrozen) {
      _ltaSum += netAcc;
      _ltaBuffer.addLast(netAcc);
      if (_ltaBuffer.length > EarthquakeConfig.ltaWindowSamples) {
        _ltaSum -= _ltaBuffer.removeFirst();
      }
    }

    // Until LTA has [ltaWindowSamples] samples, ratio stays 0 — no detection.
    // See [EarthquakeConfig.ltaWindowSeconds] (30s seismology standard; LTA freeze
    // during investigation avoids event energy contaminating the denominator).
    if (!isLtaReady) {
      _currentRatio = 0.0;
      return 0.0;
    }
    final ltaAvg = _ltaSum / _ltaBuffer.length;

    // Guard: if background is extremely quiet, the ratio becomes unstable
    // (tiny numerator / ~zero denominator = huge spike from nothing).
    // Require a minimum baseline activity before computing a meaningful ratio.
    if (ltaAvg < EarthquakeConfig.minLtaAverage) {
      _currentRatio = 0.0;
      return 0.0;
    }

    final staAvg = _staSum / _staBuffer.length;
    _currentRatio = staAvg / ltaAvg;
    return _currentRatio;
  }

  void reset() {
    _staBuffer.clear();
    _ltaBuffer.clear();
    _staSum = 0.0;
    _ltaSum = 0.0;
    _currentRatio = 0.0;
    _ltaFrozen = false;
  }
}
