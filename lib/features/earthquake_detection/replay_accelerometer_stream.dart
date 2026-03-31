import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'earthquake_config.dart';

/// Reads an earthquake CSV asset and emits [AccelerometerEvent]s at 25 Hz,
/// exactly as if the phone's accelerometer were recording a real earthquake.
///
/// Usage:
///   final stream = ReplayAccelerometerStream.fromAsset(
///     'assets/fixtures/earthquake/TK_3139__3c_25hz.csv',
///   );
class ReplayAccelerometerStream {
  /// Returns a broadcast [Stream] of [AccelerometerEvent] sourced from [assetPath].
  ///
  /// Emits one sample every [EarthquakeConfig.samplingInterval] (40 ms).
  /// The stream closes automatically when all samples have been emitted.
  static Stream<AccelerometerEvent> fromAsset(String assetPath) {
    final controller = StreamController<AccelerometerEvent>.broadcast();
    _run(assetPath, controller);
    return controller.stream;
  }

  static Future<void> _run(
    String assetPath,
    StreamController<AccelerometerEvent> controller,
  ) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final samples = _parse(raw);

      for (final (x, y, z) in samples) {
        if (controller.isClosed) break;
        controller.add(AccelerometerEvent(x, y, z, DateTime.now()));
        await Future<void>.delayed(EarthquakeConfig.samplingInterval);
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      await controller.close();
    }
  }

  static List<(double, double, double)> _parse(String csv) {
    final result = <(double, double, double)>[];
    for (final line in csv.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || RegExp(r'^[a-zA-Z]').hasMatch(t)) continue;
      final parts = t.split(',');
      if (parts.length < 3) continue;
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      final z = double.tryParse(parts[2]);
      if (x != null && y != null && z != null) result.add((x, y, z));
    }
    return result;
  }
}
