import 'dart:typed_data';

/// Decoded MPU-6050 sensor sample received over BLE from the ESP32.
///
/// The ESP32 streams these at 25 Hz via the sensor characteristic
/// [BleConstants.charSensorUuid]. Each BLE notification carries exactly
/// 24 bytes: 6 × float32 little-endian in the order ax, ay, az, gx, gy, gz.
///
/// Units:
///   ax, ay, az — linear acceleration in m/s²  (range ±2 g = ±19.62 m/s²)
///   gx, gy, gz — angular velocity in rad/s    (range ±250 °/s ≈ ±4.36 rad/s)
class SensorPacket {
  const SensorPacket({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;

  /// Decode a 24-byte BLE payload into a [SensorPacket].
  /// Returns null if the payload is shorter than 24 bytes.
  static SensorPacket? fromBytes(List<int> bytes) {
    if (bytes.length != 24) return null;
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final bd = ByteData.sublistView(uint8);
    return SensorPacket(
      ax: bd.getFloat32(0,  Endian.little),
      ay: bd.getFloat32(4,  Endian.little),
      az: bd.getFloat32(8,  Endian.little),
      gx: bd.getFloat32(12, Endian.little),
      gy: bd.getFloat32(16, Endian.little),
      gz: bd.getFloat32(20, Endian.little),
    );
  }

  @override
  String toString() =>
      'SensorPacket(ax=$ax, ay=$ay, az=$az, gx=$gx, gy=$gy, gz=$gz)';
}
