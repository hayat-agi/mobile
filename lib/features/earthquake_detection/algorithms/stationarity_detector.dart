import 'dart:collection';
import 'dart:math' as math;

import '../earthquake_config.dart';

/// Detects whether the phone is in a stationary state (e.g. on a table, shelf)
/// vs being actively handled / carried.
///
/// Uses a rolling variance of *net* acceleration magnitude over a 5-second
/// window. When the phone is flat on a surface, net-acc is near-zero with tiny
/// variance (sensor noise). When hand-held, micro-tremors and postural sway
/// produce higher variance.
///
/// **Why this matters:** STA/LTA is only meaningful when the sensor is
/// stationary. MyShake also applies a stationarity pre-filter before engaging
/// the ANN classifier.
class StationarityDetector {
  final Queue<double> _buffer = Queue<double>();
  double _sum = 0.0;
  double _sumSq = 0.0;

  /// True once the window is full and variance is below threshold.
  bool get isStationary {
    if (_buffer.length < EarthquakeConfig.stationarityWindowSamples) {
      return false;
    }
    return currentVariance < EarthquakeConfig.stationarityVarianceThreshold;
  }

  /// Current variance of the net-acceleration magnitudes in the window.
  double get currentVariance {
    if (_buffer.isEmpty) return double.infinity;
    final n = _buffer.length;
    final mean = _sum / n;
    return math.max(0.0, (_sumSq / n) - (mean * mean));
  }

  /// Feed a new net-acceleration magnitude (|√(x²+y²+z²) − 9.81|).
  void addSample(double netAcc) {
    _buffer.addLast(netAcc);
    _sum += netAcc;
    _sumSq += netAcc * netAcc;

    if (_buffer.length > EarthquakeConfig.stationarityWindowSamples) {
      final old = _buffer.removeFirst();
      _sum -= old;
      _sumSq -= old * old;
    }
  }

  void reset() {
    _buffer.clear();
    _sum = 0.0;
    _sumSq = 0.0;
  }
}
