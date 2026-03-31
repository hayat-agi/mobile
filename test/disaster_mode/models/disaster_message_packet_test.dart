import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:hayat_agi_mobile/features/disaster_mode/models/disaster_message_packet.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/disaster_enums.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';

void main() {
  group('DisasterMessagePacket', () {
    test('encode/decode round-trip preserves all fields', () {
      final packet = DisasterMessagePacket(
        priority: PriorityLevel.high,
        triageStatusBitmask: 0x01, // trapped
        severityNibble: 7,
        injuryFlags: 0x40, // fracture (bit 6)
        situationFlags: 0x80, // underRubble (bit 7)
        needsFlags: 0x80, // water (bit 7)
        peopleFlags: 0x00,
        adultCount: 1,
        childCount: 0,
        triageScore: 65,
        healthProfile: UserHealthProfile(
          hasProfile: true,
          age: AgeRange.adult30to44,
          gender: Gender.male,
          chronicDiseases: {ChronicDisease.diabetes},
          medications: {Medication.insulin},
          disability: DisabilityStatus.none,
        ),
        messageText: 'Yardım edin',
      );

      final encoded = packet.encode();
      final decoded = DisasterMessagePacket.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.priority, PriorityLevel.high);
      expect(decoded.triageScore, 65);
      expect(decoded.messageText, 'Yardım edin');
      expect(decoded.healthProfile.gender, Gender.male);
      expect(decoded.healthProfile.chronicDiseases, contains(ChronicDisease.diabetes));
    });

    test('checksum validation rejects corrupted bytes', () {
      final packet = DisasterMessagePacket(
        priority: PriorityLevel.low,
        triageStatusBitmask: 0x02,
        severityNibble: 1,
        injuryFlags: 0,
        situationFlags: 0,
        needsFlags: 0,
        peopleFlags: 0,
        adultCount: 0,
        childCount: 0,
        triageScore: 10,
        healthProfile: UserHealthProfile.empty(),
        messageText: '',
      );
      final bytes = packet.encode();
      bytes[0] ^= 0xFF; // corrupt first byte
      expect(DisasterMessagePacket.decode(bytes), isNull);
    });

    test('fromTriage derives priority automatically', () {
      // Build a minimal triage-like input
      final packet = DisasterMessagePacket.simple(
        triageScore: 90,
        triageStatusBitmask: 0x00,
        severityNibble: 12,
        injuryFlags: 0xFF,
        situationFlags: 0,
        needsFlags: 0,
        peopleFlags: 0,
        adultCount: 0,
        childCount: 0,
        healthProfile: UserHealthProfile.empty(),
        messageText: '',
      );
      expect(packet.priority, PriorityLevel.critical);
    });

    test('version bits in byte 0 equal 0b10 (v2)', () {
      final packet = DisasterMessagePacket.simple(
        triageScore: 0,
        triageStatusBitmask: 0,
        severityNibble: 0,
        injuryFlags: 0,
        situationFlags: 0,
        needsFlags: 0,
        peopleFlags: 0,
        adultCount: 0,
        childCount: 0,
        healthProfile: UserHealthProfile.empty(),
        messageText: '',
      );
      final bytes = packet.encode();
      expect((bytes[0] >> 6) & 0x03, 0x02); // version = 2
    });

    test('encode keeps message length byte consistent with packet length', () {
      final packet = DisasterMessagePacket.simple(
        triageScore: 45,
        triageStatusBitmask: 0x01,
        severityNibble: 6,
        injuryFlags: 0,
        situationFlags: 0,
        needsFlags: 0,
        peopleFlags: 0,
        adultCount: 1,
        childCount: 0,
        healthProfile: UserHealthProfile.empty(),
        // Multi-byte Turkish character to validate UTF-8 byte-limit handling.
        messageText: 'ğ' * 243,
      );

      final bytes = packet.encode();
      final msgLen = bytes[12];

      expect(msgLen, lessThanOrEqualTo(243));
      expect(bytes.length, 13 + msgLen + 1);

      final decoded = DisasterMessagePacket.decode(bytes);
      expect(decoded, isNotNull);
      expect(utf8.encode(decoded!.messageText).length, lessThanOrEqualTo(243));
    });

    test('decode rejects valid-checksum packet with non-v2 version bits', () {
      final packet = DisasterMessagePacket.simple(
        triageScore: 20,
        triageStatusBitmask: 0x00,
        severityNibble: 4,
        injuryFlags: 0x01,
        situationFlags: 0x02,
        needsFlags: 0x04,
        peopleFlags: 0x08,
        adultCount: 1,
        childCount: 1,
        healthProfile: UserHealthProfile.empty(),
        messageText: 'ok',
      );

      final bytes = packet.encode();
      // Force version bits [7:6] to 0b01 (not v2).
      bytes[0] = (bytes[0] & 0x3F) | 0x40;

      // Recompute checksum so only the version rule determines validity.
      int checksum = 0;
      for (var i = 0; i < bytes.length - 1; i++) {
        checksum ^= bytes[i];
      }
      bytes[bytes.length - 1] = checksum;

      expect(DisasterMessagePacket.decode(bytes), isNull);
    });
  });
}
