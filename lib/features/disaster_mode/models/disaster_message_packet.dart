import 'dart:convert';
import 'dart:typed_data';
import 'disaster_enums.dart';
import 'user_health_profile.dart';

/// v2 binary protocol layout:
///
/// Byte 0:  [7:6]=0b10 (v2) | [5:4]=priority | [3:2]=statusBitmask[1:0] | [1:0]=severity[3:2]
/// Byte 1:  [7:6]=severity[1:0] | [5:0]=0x00
/// Byte 2:  injury flags
/// Byte 3:  situation flags
/// Byte 4:  needs flags
/// Byte 5:  people flags
/// Byte 6:  people count [7:4]=adults [3:0]=children
/// Byte 7:  triage score
/// Bytes 8–11: health profile (4 bytes from UserHealthProfile.toBytes())
/// Byte 12: message length (0–243)
/// Bytes 13..13+len-1: UTF-8 message
/// Last byte: XOR checksum of all preceding bytes
class DisasterMessagePacket {
  static const int _version = 2;
  static const int _maxMessageBytes = 243;

  final PriorityLevel priority;
  final int triageStatusBitmask; // 0=injured, 1=trapped, 2=safe
  final int severityNibble;      // 0–15
  final int injuryFlags;
  final int situationFlags;
  final int needsFlags;
  final int peopleFlags;
  final int adultCount;          // 0–15
  final int childCount;          // 0–15
  final int triageScore;         // 0–255
  final UserHealthProfile healthProfile;
  final String messageText;

  const DisasterMessagePacket({
    required this.priority,
    required this.triageStatusBitmask,
    required this.severityNibble,
    required this.injuryFlags,
    required this.situationFlags,
    required this.needsFlags,
    required this.peopleFlags,
    required this.adultCount,
    required this.childCount,
    required this.triageScore,
    required this.healthProfile,
    required this.messageText,
  });

  /// Convenience constructor that auto-derives priority from triageScore.
  factory DisasterMessagePacket.simple({
    required int triageScore,
    required int triageStatusBitmask,
    required int severityNibble,
    required int injuryFlags,
    required int situationFlags,
    required int needsFlags,
    required int peopleFlags,
    required int adultCount,
    required int childCount,
    required UserHealthProfile healthProfile,
    required String messageText,
  }) =>
      DisasterMessagePacket(
        priority: PriorityLevel.fromTriageScore(triageScore),
        triageScore: triageScore,
        triageStatusBitmask: triageStatusBitmask,
        severityNibble: severityNibble,
        injuryFlags: injuryFlags,
        situationFlags: situationFlags,
        needsFlags: needsFlags,
        peopleFlags: peopleFlags,
        adultCount: adultCount,
        childCount: childCount,
        healthProfile: healthProfile,
        messageText: messageText,
      );

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
    final msgBytes = _truncateUtf8ToMaxBytes(messageText, _maxMessageBytes);
    final totalLen = 13 + msgBytes.length + 1; // header(13) + msg + checksum
    final buf = Uint8List(totalLen);

    buf[0] = ((_version & 0x03) << 6) |
        ((priority.bitmask & 0x03) << 4) |
        ((triageStatusBitmask & 0x03) << 2) |
        ((severityNibble >> 2) & 0x03);
    buf[1] = ((severityNibble & 0x03) << 6);
    buf[2] = injuryFlags & 0xFF;
    buf[3] = situationFlags & 0xFF;
    buf[4] = needsFlags & 0xFF;
    buf[5] = peopleFlags & 0xFF;
    buf[6] = ((adultCount & 0x0F) << 4) | (childCount & 0x0F);
    buf[7] = triageScore & 0xFF;

    final healthBytes = healthProfile.toBytes();
    buf[8] = healthBytes[0];
    buf[9] = healthBytes[1];
    buf[10] = healthBytes[2];
    buf[11] = healthBytes[3];

    buf[12] = msgBytes.length;
    for (var i = 0; i < msgBytes.length; i++) {
      buf[13 + i] = msgBytes[i];
    }

    // XOR checksum of all preceding bytes
    int checksum = 0;
    for (var i = 0; i < totalLen - 1; i++) {
      checksum ^= buf[i];
    }
    buf[totalLen - 1] = checksum;
    return buf;
  }

  /// Returns null if checksum fails or buffer too short.
  static DisasterMessagePacket? decode(Uint8List bytes) {
    if (bytes.length < 14) return null; // minimum: 13 header + 0 msg + 1 checksum
    if (((bytes[0] >> 6) & 0x03) != _version) return null;

    // Validate checksum
    int checksum = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      checksum ^= bytes[i];
    }
    if (checksum != bytes[bytes.length - 1]) return null;

    final priority = PriorityLevel.fromBitmask((bytes[0] >> 4) & 0x03);
    final statusBitmask = (bytes[0] >> 2) & 0x03;
    final severityNibble =
        ((bytes[0] & 0x03) << 2) | ((bytes[1] >> 6) & 0x03);
    final msgLen = bytes[12];
    if (bytes.length < 13 + msgLen + 1) return null;

    final msgBytes = bytes.sublist(13, 13 + msgLen);
    final messageText = utf8.decode(msgBytes, allowMalformed: true);
    final healthProfile = UserHealthProfile.fromBytes(bytes.sublist(8, 12));

    return DisasterMessagePacket(
      priority: priority,
      triageStatusBitmask: statusBitmask,
      severityNibble: severityNibble,
      injuryFlags: bytes[2],
      situationFlags: bytes[3],
      needsFlags: bytes[4],
      peopleFlags: bytes[5],
      adultCount: (bytes[6] >> 4) & 0x0F,
      childCount: bytes[6] & 0x0F,
      triageScore: bytes[7],
      healthProfile: healthProfile,
      messageText: messageText,
    );
  }
}
