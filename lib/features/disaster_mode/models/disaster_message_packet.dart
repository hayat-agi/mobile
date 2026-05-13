import 'dart:convert';
import 'dart:typed_data';

import '../../../models/household_profile.dart';
import '../../ble/BLEConstants.dart';
import 'user_health_profile.dart';

/// v4 binary protocol (preferred):
///
/// Byte 0:    0xD0 — v4 marker
/// Bytes 1–4: health profile ([UserHealthProfile.toBytes])
/// Byte 5:    primary message length (0–180)
/// Bytes 6 … 6+msgLen-1: UTF-8 user message
/// Bytes …:   uint16 BE household JSON length (0 = none)
/// …:         UTF-8 JSON (members, pets, emergency contacts for this gateway)
/// Last byte: XOR checksum
///
/// v3 (legacy, decode only): marker 0xC0, no household trailer.
class DisasterMessagePacket {
  static const int _v3Marker = 0xC0;
  static const int _v4Marker = 0xD0;

  static const int _maxMessageBytes = 180;
  static const int _maxHouseholdBytes = 280;
  static const int _binPrefixBytes = 4; // "BIN:"

  final UserHealthProfile healthProfile;
  final String messageText;

  /// Hane profili — optional; omitted if null or empty.
  final HouseholdProfile? household;

  const DisasterMessagePacket({
    required this.healthProfile,
    required this.messageText,
    this.household,
  });

  List<int> _truncateUtf8ToMaxBytes(String text, int maxBytes) {
    if (maxBytes <= 0 || text.isEmpty) return const <int>[];
    final out = <int>[];
    var used = 0;
    for (final rune in text.runes) {
      final encoded = utf8.encode(String.fromCharCode(rune));
      if (used + encoded.length > maxBytes) break;
      out.addAll(encoded);
      used += encoded.length;
    }
    return out;
  }

  Uint8List encode() {
    // sendBinaryQueued persists packets as "BIN:<hex>" when it cannot deliver
    // immediately. Keep the raw packet small enough that this text fallback
    // still fits in one ESP32 command frame.
    final maxPacketBytes = (BleConstants.maxMtu - _binPrefixBytes) ~/ 2;
    final maxMsgBytes = (maxPacketBytes - 9).clamp(0, _maxMessageBytes);
    final msgBytes = _truncateUtf8ToMaxBytes(messageText, maxMsgBytes);

    List<int> hhBytes = const <int>[];
    if (_hasHouseholdPayload) {
      final jsonStr = jsonEncode(household!.toJson());
      final raw = utf8.encode(jsonStr);
      final remaining = maxPacketBytes - 9 - msgBytes.length;
      if (raw.length <= remaining && raw.length <= _maxHouseholdBytes) {
        hhBytes = raw;
      }
    }

    final hhLen = hhBytes.length;
    // v4: 1 + 4 + 1 + msgLen + 2 + hhLen + 1 checksum  →  9 + msgLen + hhLen
    final totalLen = 9 + msgBytes.length + hhLen;
    final buf = Uint8List(totalLen);

    var o = 0;
    buf[o++] = _v4Marker;

    final healthBytes = healthProfile.toBytes();
    buf[o++] = healthBytes[0];
    buf[o++] = healthBytes[1];
    buf[o++] = healthBytes[2];
    buf[o++] = healthBytes[3];

    buf[o++] = msgBytes.length;
    for (var i = 0; i < msgBytes.length; i++) {
      buf[o++] = msgBytes[i];
    }

    buf[o++] = (hhLen >> 8) & 0xFF;
    buf[o++] = hhLen & 0xFF;
    for (var i = 0; i < hhBytes.length; i++) {
      buf[o++] = hhBytes[i];
    }

    var checksum = 0;
    for (var i = 0; i < totalLen - 1; i++) {
      checksum ^= buf[i];
    }
    buf[totalLen - 1] = checksum;
    return buf;
  }

  bool get _hasHouseholdPayload {
    final h = household;
    if (h == null) return false;
    return h.members.isNotEmpty ||
        h.pets.isNotEmpty ||
        h.emergencyContacts.isNotEmpty;
  }

  /// Returns null if checksum fails or buffer invalid.
  static DisasterMessagePacket? decode(Uint8List bytes) {
    if (bytes.length < 7) return null;
    final marker = bytes[0];
    if (marker == _v4Marker) return _decodeV4(bytes);
    if (marker == _v3Marker) return _decodeV3(bytes);
    return null;
  }

  static DisasterMessagePacket? _decodeV3(Uint8List bytes) {
    int checksum = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      checksum ^= bytes[i];
    }
    if (checksum != bytes[bytes.length - 1]) return null;

    final msgLen = bytes[5];
    if (bytes.length < 7 + msgLen) return null;

    final healthProfile = UserHealthProfile.fromBytes(bytes.sublist(1, 5));
    final msgBytes = bytes.sublist(6, 6 + msgLen);
    final messageText = utf8.decode(msgBytes, allowMalformed: true);

    return DisasterMessagePacket(
      healthProfile: healthProfile,
      messageText: messageText,
      household: null,
    );
  }

  static DisasterMessagePacket? _decodeV4(Uint8List bytes) {
    if (bytes.length < 9) return null;

    final msgLen = bytes[5];
    final hhOffset = 6 + msgLen;
    if (bytes.length < hhOffset + 2) return null;

    final hhLen = (bytes[hhOffset] << 8) | bytes[hhOffset + 1];
    // 1+4+1+msgLen+2+hhLen+checksum
    final expectedLen = 9 + msgLen + hhLen;
    if (bytes.length != expectedLen) return null;

    int checksum = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      checksum ^= bytes[i];
    }
    if (checksum != bytes[bytes.length - 1]) return null;

    final healthProfile = UserHealthProfile.fromBytes(bytes.sublist(1, 5));
    final messageText = msgLen > 0
        ? utf8.decode(bytes.sublist(6, 6 + msgLen), allowMalformed: true)
        : '';

    HouseholdProfile? household;
    if (hhLen > 0) {
      try {
        final jsonStr = utf8.decode(
          bytes.sublist(hhOffset + 2, hhOffset + 2 + hhLen),
          allowMalformed: true,
        );
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        household = HouseholdProfile.fromJson(map);
      } catch (_) {
        household = null;
      }
    }

    return DisasterMessagePacket(
      healthProfile: healthProfile,
      messageText: messageText,
      household: household,
    );
  }
}
