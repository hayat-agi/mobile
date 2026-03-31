# BLE To-Do: Disaster Mode Extensions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 4 BLE/disaster-mode features: standardized v2 message packet, battery optimization service, PFA psychological support messages, and vulnerable-group auto-transmission.

**Architecture:** Dependency-aware parallel execution — Wave 1 runs 3 independent agents (Madde 2 packet protocol, Madde 3 battery, Madde 4 PFA) simultaneously; Wave 2 (Madde 1 vulnerable group) runs after Madde 2 completes because it consumes the new packet format. All features hook into the existing `DisasterController` / `BleService` / `EarthquakeDetectionService` singleton pattern.

**Tech Stack:** Flutter/Dart, GetX, flutter_blue_plus, sensors_plus, shared_preferences, battery_plus (new dep for Madde 3)

---

## File Map

### Madde 2 — Extended Packet Protocol (Wave 1A)
| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/features/disaster_mode/models/user_health_profile.dart` | UserHealthProfile model + enums (Gender, ChronicDisease, Medication, DisabilityStatus) |
| Create | `lib/features/disaster_mode/models/disaster_message_packet.dart` | DisasterMessagePacket v2 binary encoder/decoder |
| Modify | `lib/features/disaster_mode/models/disaster_enums.dart` | Add PriorityLevel enum + fromTriageScore() |
| Modify | `lib/features/disaster_mode/models/triage_payload.dart` | Keep v1 intact; add version detection helper |
| Modify | `lib/features/disaster_mode/controllers/disaster_controller.dart` | Use DisasterMessagePacket in sendStatus() / sendManualMessage() |
| Modify | `lib/features/ble/BLEConstants.dart` | Add protocol version constants |
| Create | `test/disaster_mode/models/user_health_profile_test.dart` | Unit tests |
| Create | `test/disaster_mode/models/disaster_message_packet_test.dart` | Encode/decode round-trip tests |

### Madde 3 — Battery Optimization (Wave 1B, independent)
| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/features/disaster_mode/config/power_config.dart` | Threshold constants (brightness, intervals, battery %) |
| Create | `lib/features/disaster_mode/services/battery_optimization_service.dart` | Apply/restore power settings, battery monitoring |
| Modify | `lib/app.dart` | Initialize BatteryOptimizationService; activate on earthquake detection |
| Modify | `pubspec.yaml` | Add battery_plus: ^1.0.0 |
| Create | `test/disaster_mode/services/battery_optimization_service_test.dart` | Unit tests |

### Madde 4 — PFA Messages (Wave 1C, independent)
| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/features/disaster_mode/data/pfa_messages.dart` | Full Turkish PFA message library (6 categories × 3-5 messages) |
| Create | `lib/features/disaster_mode/services/pfa_message_service.dart` | Trigger detection, message selection algorithm |
| Create | `lib/features/disaster_mode/widgets/pfa_support_overlay.dart` | Dismissible overlay widget |
| Modify | `lib/features/disaster_mode/disaster_home_page.dart` | Integrate PFA overlay trigger |
| Create | `test/disaster_mode/services/pfa_message_service_test.dart` | Trigger detection + selection tests |

### Madde 1 — Vulnerable Group Auto-Transmission (Wave 2, after Madde 2)
| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/features/user_profile/services/vulnerable_group_service.dart` | Store/load health profile, track last hourly location |
| Modify | `lib/features/settings/settings_page.dart` | Add vulnerable group toggle + health data form |
| Modify | `lib/features/disaster_mode/controllers/disaster_controller.dart` | Auto-send on disaster activation if isVulnerableGroup |
| Create | `test/user_profile/vulnerable_group_service_test.dart` | Unit tests |

---

## Wave 1A — Madde 2: Standardized Disaster Message Packet

### Task 1: PriorityLevel enum

**Files:**
- Modify: `lib/features/disaster_mode/models/disaster_enums.dart`

- [ ] **Step 1: Write failing test for PriorityLevel**

```dart
// test/disaster_mode/models/priority_level_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/disaster_enums.dart';

void main() {
  group('PriorityLevel.fromTriageScore', () {
    test('score 80+ is critical', () => expect(PriorityLevel.fromTriageScore(80), PriorityLevel.critical));
    test('score 50-79 is high',    () => expect(PriorityLevel.fromTriageScore(50), PriorityLevel.high));
    test('score 20-49 is medium',  () => expect(PriorityLevel.fromTriageScore(20), PriorityLevel.medium));
    test('score 0-19 is low',      () => expect(PriorityLevel.fromTriageScore(0),  PriorityLevel.low));
    test('bitmask round-trip',     () {
      for (final p in PriorityLevel.values) {
        expect(PriorityLevel.fromBitmask(p.bitmask), p);
      }
    });
  });
}
```

Run: `flutter test test/disaster_mode/models/priority_level_test.dart`
Expected: FAIL (PriorityLevel not defined yet)

- [ ] **Step 2: Add PriorityLevel enum at bottom of file**

```dart
enum PriorityLevel {
  critical, // triage score >= 80
  high,     // triage score >= 50
  medium,   // triage score >= 20
  low,      // triage score < 20
  ;

  static PriorityLevel fromTriageScore(int score) {
    if (score >= 80) return PriorityLevel.critical;
    if (score >= 50) return PriorityLevel.high;
    if (score >= 20) return PriorityLevel.medium;
    return PriorityLevel.low;
  }

  int get bitmask {
    switch (this) {
      case PriorityLevel.low:      return 0x00;
      case PriorityLevel.medium:   return 0x01;
      case PriorityLevel.high:     return 0x02;
      case PriorityLevel.critical: return 0x03;
    }
  }

  static PriorityLevel fromBitmask(int bits) {
    switch (bits & 0x03) {
      case 0x03: return PriorityLevel.critical;
      case 0x02: return PriorityLevel.high;
      case 0x01: return PriorityLevel.medium;
      default:   return PriorityLevel.low;
    }
  }
}
```

- [ ] **Step 3: Run test — expect PASS**
```bash
flutter test test/disaster_mode/models/priority_level_test.dart
```

- [ ] **Step 4: Commit**
```bash
git add lib/features/disaster_mode/models/disaster_enums.dart \
        test/disaster_mode/models/priority_level_test.dart
git commit -m "feat(packet): add PriorityLevel enum with triage score mapping"
```

---

### Task 2: UserHealthProfile model

**Files:**
- Create: `lib/features/disaster_mode/models/user_health_profile.dart`
- Create: `test/disaster_mode/models/user_health_profile_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/disaster_mode/models/user_health_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';

void main() {
  group('UserHealthProfile', () {
    test('empty() produces safe defaults', () {
      final p = UserHealthProfile.empty();
      expect(p.age, AgeRange.unknown);
      expect(p.gender, Gender.unknown);
      expect(p.chronicDiseases, isEmpty);
      expect(p.medications, isEmpty);
      expect(p.disability, DisabilityStatus.none);
      expect(p.hasProfile, false);
    });

    test('toBytes() / fromBytes() round-trip', () {
      final original = UserHealthProfile(
        hasProfile: true,
        age: AgeRange.range45to59,
        gender: Gender.female,
        chronicDiseases: {ChronicDisease.diabetes, ChronicDisease.hypertension},
        medications: {Medication.insulin},
        disability: DisabilityStatus.mobility,
      );
      final bytes = original.toBytes();
      expect(bytes.length, 4);
      final restored = UserHealthProfile.fromBytes(bytes);
      expect(restored.hasProfile, true);
      expect(restored.age, AgeRange.range45to59);
      expect(restored.gender, Gender.female);
      expect(restored.chronicDiseases, contains(ChronicDisease.diabetes));
      expect(restored.chronicDiseases, contains(ChronicDisease.hypertension));
      expect(restored.medications, contains(Medication.insulin));
      expect(restored.disability, DisabilityStatus.mobility);
    });

    test('empty profile serializes to 4 zero-ish bytes with hasProfile=0', () {
      final bytes = UserHealthProfile.empty().toBytes();
      expect(bytes.length, 4);
      expect(bytes[0] & 0x80, 0); // hasProfile bit = 0
    });
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**
```bash
cd /Users/whis/Desktop/BitirmeProjesi/hayat-agi-mobile
flutter test test/disaster_mode/models/user_health_profile_test.dart
```
Expected: compilation error (file doesn't exist yet)

- [ ] **Step 3: Implement UserHealthProfile**

```dart
// lib/features/disaster_mode/models/user_health_profile.dart
import 'dart:typed_data';

enum Gender { unknown, male, female, other }

enum AgeRange {
  unknown,    // 0
  child0to9,  // 1
  teen10to17, // 2
  young18to29,// 3
  adult30to44,// 4
  range45to59,// 5
  senior60to74,//6
  elderly75plus,//7
}

enum ChronicDisease {
  heartDisease,  // bit 0
  diabetes,      // bit 1
  hypertension,  // bit 2
  asthma,        // bit 3
  epilepsy,      // bit 4
  renalDisease,  // bit 5
  cancer,        // bit 6
  other,         // bit 7
}

enum Medication {
  bloodThinner,      // bit 0
  insulin,           // bit 1
  heartMed,          // bit 2
  antiepileptic,     // bit 3
  immunosuppressant, // bit 4
  painKiller,        // bit 5
  other,             // bit 6
}

enum DisabilityStatus {
  none,      // 0
  mobility,  // 1
  visual,    // 2
  hearing,   // 3
  cognitive, // 4
  other,     // 5
}

class UserHealthProfile {
  final bool hasProfile;
  final AgeRange age;
  final Gender gender;
  final Set<ChronicDisease> chronicDiseases;
  final Set<Medication> medications;
  final DisabilityStatus disability;

  const UserHealthProfile({
    required this.hasProfile,
    required this.age,
    required this.gender,
    required this.chronicDiseases,
    required this.medications,
    required this.disability,
  });

  factory UserHealthProfile.empty() => const UserHealthProfile(
        hasProfile: false,
        age: AgeRange.unknown,
        gender: Gender.unknown,
        chronicDiseases: {},
        medications: {},
        disability: DisabilityStatus.none,
      );

  /// 4 bytes:
  /// Byte 0: [7]=hasProfile [6:5]=gender [4:2]=ageRange [1:0]=disability[2:1]
  /// Byte 1: [0]=disability[0]  [7:1]=reserved(0)
  /// Byte 2: chronic disease bitmask
  /// Byte 3: medication bitmask
  Uint8List toBytes() {
    final bytes = Uint8List(4);
    bytes[0] = (hasProfile ? 0x80 : 0x00) |
        ((gender.index & 0x03) << 5) |
        ((age.index & 0x07) << 2) |
        ((disability.index >> 1) & 0x03);
    bytes[1] = (disability.index & 0x01) << 7;
    bytes[2] = chronicDiseases.fold(0, (mask, d) => mask | (1 << d.index));
    bytes[3] = medications.fold(0, (mask, m) => mask | (1 << m.index));
    return bytes;
  }

  factory UserHealthProfile.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) return UserHealthProfile.empty();
    final hasProfile = (bytes[0] & 0x80) != 0;
    final gender = Gender.values[(bytes[0] >> 5) & 0x03];
    final age = AgeRange.values[(bytes[0] >> 2) & 0x07];
    final disabilityIndex = ((bytes[0] & 0x03) << 1) | ((bytes[1] >> 7) & 0x01);
    final disability = disabilityIndex < DisabilityStatus.values.length
        ? DisabilityStatus.values[disabilityIndex]
        : DisabilityStatus.none;
    final diseases = <ChronicDisease>{};
    for (var i = 0; i < ChronicDisease.values.length; i++) {
      if ((bytes[2] & (1 << i)) != 0) diseases.add(ChronicDisease.values[i]);
    }
    final meds = <Medication>{};
    for (var i = 0; i < Medication.values.length; i++) {
      if ((bytes[3] & (1 << i)) != 0) meds.add(Medication.values[i]);
    }
    return UserHealthProfile(
      hasProfile: hasProfile,
      age: age,
      gender: gender,
      chronicDiseases: diseases,
      medications: meds,
      disability: disability,
    );
  }

  UserHealthProfile copyWith({
    bool? hasProfile,
    AgeRange? age,
    Gender? gender,
    Set<ChronicDisease>? chronicDiseases,
    Set<Medication>? medications,
    DisabilityStatus? disability,
  }) =>
      UserHealthProfile(
        hasProfile: hasProfile ?? this.hasProfile,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        chronicDiseases: chronicDiseases ?? this.chronicDiseases,
        medications: medications ?? this.medications,
        disability: disability ?? this.disability,
      );
}
```

- [ ] **Step 4: Run tests — expect PASS**
```bash
flutter test test/disaster_mode/models/user_health_profile_test.dart
```
Expected: All tests pass.

- [ ] **Step 5: Commit**
```bash
git add lib/features/disaster_mode/models/user_health_profile.dart \
        test/disaster_mode/models/user_health_profile_test.dart
git commit -m "feat(packet): add UserHealthProfile model with binary serialization"
```

---

### Task 3: DisasterMessagePacket v2

**Files:**
- Create: `lib/features/disaster_mode/models/disaster_message_packet.dart`
- Create: `test/disaster_mode/models/disaster_message_packet_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/disaster_mode/models/disaster_message_packet_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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
        injuryFlags: 0b01000000, // fracture
        situationFlags: 0b10000000, // underRubble
        needsFlags: 0b10000000, // water
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
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**
```bash
flutter test test/disaster_mode/models/disaster_message_packet_test.dart
```
Expected: compilation errors (file doesn't exist)

- [ ] **Step 3: Implement DisasterMessagePacket**

```dart
// lib/features/disaster_mode/models/disaster_message_packet.dart
import 'dart:convert';
import 'dart:typed_data';
import 'disaster_enums.dart';
import 'user_health_profile.dart';

/// v2 binary protocol layout:
/// Byte 0:  [7:6]=version(0b10) [5:4]=priority [3:2]=statusBitmask [1:0]=severityNibble[3:2]
/// Byte 1:  [7:6]=severityNibble[1:0] [5:0]=reserved(0)
///          NOTE: simplified — severity packed into nibble across bytes 0-1
///          Actual layout keeps it simple: see encode() below
/// -------
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

  final PriorityLevel priority;
  final int triageStatusBitmask; // 0=injured,1=trapped,2=safe
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

  Uint8List encode() {
    final msgBytes = utf8.encode(messageText.length > 243
        ? messageText.substring(0, 243)
        : messageText);
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

    // XOR checksum
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

    // Validate checksum
    int checksum = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      checksum ^= bytes[i];
    }
    if (checksum != bytes[bytes.length - 1]) return null;

    final priority = PriorityLevel.fromBitmask((bytes[0] >> 4) & 0x03);
    final statusBitmask = (bytes[0] >> 2) & 0x03;
    final severityNibble = ((bytes[0] & 0x03) << 2) | ((bytes[1] >> 6) & 0x03);
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
```

- [ ] **Step 4: Run tests — expect PASS**
```bash
flutter test test/disaster_mode/models/disaster_message_packet_test.dart
```

- [ ] **Step 5: Add protocol version constants to BLEConstants**

In `lib/features/ble/BLEConstants.dart`, add inside the class body:
```dart
// Protocol versions
static const int protocolVersionV1 = 0x01;
static const int protocolVersionV2 = 0x02;
static const int currentProtocolVersion = protocolVersionV2;
```

- [ ] **Step 6: Commit**
```bash
git add lib/features/disaster_mode/models/disaster_message_packet.dart \
        lib/features/ble/BLEConstants.dart \
        test/disaster_mode/models/disaster_message_packet_test.dart
git commit -m "feat(packet): add DisasterMessagePacket v2 with binary encoder/decoder"
```

---

### Task 4: Wire DisasterController to use v2 packet

**Files:**
- Modify: `lib/features/disaster_mode/controllers/disaster_controller.dart`

- [ ] **Step 1: Add health profile field and update method**

Find the field declarations section (around line 30–50). Add:
```dart
UserHealthProfile _healthProfile = UserHealthProfile.empty();

void updateHealthProfile(UserHealthProfile profile) {
  _healthProfile = profile;
}
```

Add import at top:
```dart
import 'models/user_health_profile.dart';
import 'models/disaster_message_packet.dart';
```

- [ ] **Step 2: Update sendStatus() to build DisasterMessagePacket**

Find `sendStatus()`. Replace the `buildPayload()` / `sendBinaryQueued()` call with:
```dart
final packet = DisasterMessagePacket.simple(
  triageScore: triageScore.value,
  triageStatusBitmask: selectedStatus.value?.bitmaskValue ?? 0,
  severityNibble: (triageScore.value / 17).round().clamp(0, 15),
  injuryFlags: _buildInjuryFlags(),
  situationFlags: _buildSituationFlags(),
  needsFlags: _buildNeedsFlags(),
  peopleFlags: _buildPeopleFlags(),
  adultCount: adultCount.value,
  childCount: childCount.value,
  healthProfile: _healthProfile,
  messageText: '',
);
await _bleService.sendBinaryQueued(packet.encode());
```

Add private helpers that extract the bitmask logic (if not already separate methods):
```dart
int _buildInjuryFlags() =>
    selectedInjuries.fold(0, (m, c) => m | (1 << c.bitPosition));
int _buildSituationFlags() =>
    selectedSituations.fold(0, (m, c) => m | (1 << c.bitPosition));
int _buildNeedsFlags() =>
    selectedNeeds.fold(0, (m, c) => m | (1 << c.bitPosition));
int _buildPeopleFlags() =>
    selectedPeople.fold(0, (m, c) => m | (1 << c.bitPosition));
```

- [ ] **Step 3: Update sendManualMessage() to embed text in packet**

Find `sendManualMessage(String text)`. Replace its `sendMessage(text)` call:
```dart
final packet = DisasterMessagePacket.simple(
  triageScore: triageScore.value,
  triageStatusBitmask: selectedStatus.value?.bitmaskValue ?? 0,
  severityNibble: 0,
  injuryFlags: _buildInjuryFlags(),
  situationFlags: _buildSituationFlags(),
  needsFlags: 0,
  peopleFlags: 0,
  adultCount: 0,
  childCount: 0,
  healthProfile: _healthProfile,
  messageText: text,
);
await _bleService.sendBinaryQueued(packet.encode());
```

- [ ] **Step 4: Run all existing tests**
```bash
flutter test
```
Expected: All previously passing tests still pass.

- [ ] **Step 5: Commit**
```bash
git add lib/features/disaster_mode/controllers/disaster_controller.dart
git commit -m "feat(packet): wire DisasterController to DisasterMessagePacket v2"
```

---

## Wave 1B — Madde 3: Battery Optimization Service

### Task 5: PowerConfig constants

**Files:**
- Create: `lib/features/disaster_mode/config/power_config.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/disaster_mode/config/power_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/config/power_config.dart';

void main() {
  test('disaster brightness is less than normal brightness', () {
    expect(PowerConfig.disasterBrightness, lessThan(PowerConfig.normalBrightness));
  });
  test('aggressive threshold is below low-battery warning threshold', () {
    expect(PowerConfig.aggressiveSaveThreshold, lessThan(PowerConfig.lowBatteryWarningThreshold));
  });
}
```

Run: `flutter test test/disaster_mode/config/power_config_test.dart`
Expected: FAIL (file doesn't exist)

- [ ] **Step 2: Create config file**

```dart
// lib/features/disaster_mode/config/power_config.dart

/// Threshold values and settings for disaster mode power optimization.
/// These are the agreed technical parameters — change here to affect all behavior.
class PowerConfig {
  PowerConfig._();

  /// Screen brightness reduced to this fraction (0.0–1.0) when disaster mode is active.
  static const double disasterBrightness = 0.15;

  /// Normal brightness is restored to this fraction when leaving disaster mode.
  static const double normalBrightness = 1.0;

  /// Battery percentage below which we enter aggressive power-saving mode.
  static const int aggressiveSaveThreshold = 20; // percent

  /// Battery percentage below which a low-battery warning is shown to user.
  static const int lowBatteryWarningThreshold = 30; // percent

  /// Notification check interval in disaster mode (milliseconds).
  static const int disasterNotificationIntervalMs = 5 * 60 * 1000; // 5 minutes

  /// How often the battery level is polled (milliseconds).
  static const int batteryCheckIntervalMs = 60 * 1000; // 1 minute
}
```

- [ ] **Step 3: Run test — expect PASS**
```bash
flutter test test/disaster_mode/config/power_config_test.dart
```

- [ ] **Step 4: Commit**
```bash
git add lib/features/disaster_mode/config/power_config.dart \
        test/disaster_mode/config/power_config_test.dart
git commit -m "feat(battery): add PowerConfig constants for disaster mode power optimization"
```

---

### Task 6: BatteryOptimizationService

**Files:**
- Create: `lib/features/disaster_mode/services/battery_optimization_service.dart`
- Create: `test/disaster_mode/services/battery_optimization_service_test.dart`
- Modify: `pubspec.yaml` (add battery_plus, screen_brightness)

- [ ] **Step 1: Add dependencies to pubspec.yaml**

In `pubspec.yaml` under `dependencies:`, add:
```yaml
  battery_plus: ^6.0.0
  screen_brightness: ^0.2.1+1
```
Note: `screen_brightness ^0.2.x` uses the `ScreenBrightness()` instance API below. Do NOT use `^1.x` — that version changed to `ScreenBrightness.instance` with different method names.

Run:
```bash
flutter pub get
```

- [ ] **Step 2: Write failing tests**

```dart
// test/disaster_mode/services/battery_optimization_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/services/battery_optimization_service.dart';

void main() {
  group('BatteryOptimizationService', () {
    test('singleton instance always same object', () {
      final a = BatteryOptimizationService();
      final b = BatteryOptimizationService();
      expect(identical(a, b), true);
    });

    test('isActive starts false', () {
      expect(BatteryOptimizationService().isActive, false);
    });

    test('batteryLevel starts at -1 (not fetched yet)', () {
      expect(BatteryOptimizationService().batteryLevel, -1);
    });
  });
}
```

- [ ] **Step 3: Run tests — expect FAIL**
```bash
flutter test test/disaster_mode/services/battery_optimization_service_test.dart
```

- [ ] **Step 4: Implement BatteryOptimizationService**

```dart
// lib/features/disaster_mode/services/battery_optimization_service.dart
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../config/power_config.dart';

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  final _battery = Battery();
  Timer? _batteryTimer;
  bool _isActive = false;
  int _batteryLevel = -1;
  double? _previousBrightness;

  bool get isActive => _isActive;
  int get batteryLevel => _batteryLevel;

  /// Call when disaster mode activates.
  Future<void> activate() async {
    if (_isActive) return;
    _isActive = true;

    // Save current brightness and reduce it
    try {
      _previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(PowerConfig.disasterBrightness);
    } catch (_) {
      // Platform may not support brightness control — continue silently
    }

    // Start battery monitoring
    _batteryLevel = await _battery.batteryLevel;
    _batteryTimer = Timer.periodic(
      const Duration(milliseconds: PowerConfig.batteryCheckIntervalMs),
      (_) async {
        _batteryLevel = await _battery.batteryLevel;
      },
    );
  }

  /// Call when disaster mode deactivates.
  Future<void> deactivate() async {
    if (!_isActive) return;
    _isActive = false;

    _batteryTimer?.cancel();
    _batteryTimer = null;

    // Restore brightness
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (_) {}
    _previousBrightness = null;
  }

  bool get isBatteryCritical =>
      _batteryLevel >= 0 && _batteryLevel <= PowerConfig.aggressiveSaveThreshold;

  bool get isBatteryLow =>
      _batteryLevel >= 0 && _batteryLevel <= PowerConfig.lowBatteryWarningThreshold;
}
```

- [ ] **Step 5: Run tests — expect PASS**
```bash
flutter test test/disaster_mode/services/battery_optimization_service_test.dart
```

- [ ] **Step 6: Hook into app.dart**

In `lib/app.dart`, find `_earthquakeSub` listener. After the navigation to `DisasterHomePage`, add:
```dart
BatteryOptimizationService().activate();
```

Also add a way to deactivate when leaving disaster mode. In the same file, or wherever `DisasterHomePage` navigation happens, add a listener for when the user pops back:
```dart
// After navigating to DisasterHomePage, listen for the route to pop:
_navigatorKey.currentState?.push(route).then((_) {
  BatteryOptimizationService().deactivate();
});
```

Add import:
```dart
import 'features/disaster_mode/services/battery_optimization_service.dart';
```

- [ ] **Step 7: Run all tests**
```bash
flutter test
```

- [ ] **Step 8: Commit**
```bash
git add lib/features/disaster_mode/services/battery_optimization_service.dart \
        lib/features/disaster_mode/config/power_config.dart \
        lib/app.dart \
        pubspec.yaml pubspec.lock \
        test/disaster_mode/services/battery_optimization_service_test.dart
git commit -m "feat(battery): add BatteryOptimizationService with screen dimming and battery monitoring"
```

---

## Wave 1C — Madde 4: PFA Psychological Support Messages

### Task 7: PFA message library

**Files:**
- Create: `lib/features/disaster_mode/data/pfa_messages.dart`

- [ ] **Step 1: Create the full Turkish PFA message library**

```dart
// lib/features/disaster_mode/data/pfa_messages.dart
// Turkish PFA messages based on WHO PFA, NCTSN PFA Field Guide principles.
// Empathetic, realistic, non-judgmental, culturally neutral.
// No religious/political content, no definite rescue promises.

enum PfaCategory {
  firstContact,       // İlk temas / mesaj alındı
  panicBreathing,     // Yüksek panik ve nefes darlığı
  hopelessness,       // Umutsuzluk ve çaresizlik
  loneliness,         // Yalnızlık ve terk edilmişlik
  painTrapped,        // Şiddetli ağrı veya sıkışma
  uncertainty,        // Bilgi belirsizliği / dış dünyaya dair kaygı
}

class PfaMessage {
  final String text;
  final List<String> psychologicalFunctions;
  final String pfaComponent;
  final PfaCategory category;
  final int vulnerabilityPriority; // 0=all, 1=prefer for vulnerable groups

  const PfaMessage({
    required this.text,
    required this.psychologicalFunctions,
    required this.pfaComponent,
    required this.category,
    this.vulnerabilityPriority = 0,
  });
}

class PfaMessages {
  PfaMessages._();

  static const List<PfaMessage> all = [
    // ─── İlk Temas ───────────────────────────────────────────────────────
    PfaMessage(
      text: 'Mesajınız ulaştı. Nerede olduğunuz biliniyor, ekipler harekete geçti.',
      psychologicalFunctions: ['güvenlik ve görülme hissi', 'kaygı azaltma'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Sesinizi duyduk. Şu an için en önemli şey sakin kalmak ve enerji korumak.',
      psychologicalFunctions: ['güvenlik', 'öz-etkinlik'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Bilgileriniz kaydedildi. Yardım yolda, sizi unutmadık.',
      psychologicalFunctions: ['güvenlik ve görülme hissi', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Burada olduğunuzu biliyoruz. Durumunuzu düzenli olarak paylaşmaya devam edin.',
      psychologicalFunctions: ['öz-etkinlik', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Mesajınız alındı. Şu an yapabileceğiniz en iyi şey yavaş nefes alıp kendinizi korumak.',
      psychologicalFunctions: ['sakinleşme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.firstContact,
    ),

    // ─── Yüksek Panik ve Nefes Darlığı ──────────────────────────────────
    PfaMessage(
      text: 'Şu an çok zor bir anda olduğunuzu biliyoruz. Burnunuzdan yavaşça nefes alın, ağzınızdan verin.',
      psychologicalFunctions: ['panik azaltma', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text: '4 sayarak nefes alın, 4 tutun, 4 sayarak verin. Bu iki kez tekrar edin — bedeniniz yavaşlayacak.',
      psychologicalFunctions: ['panik azaltma', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text: 'Nefes darlığı hissediyorsanız bu normaldir; bedeniniz sizi korumaya çalışıyor. Yavaş nefes almak yardımcı olur.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text: 'Gözlerinizi kapatıp elinizi göğsünüze koyun. Nefes alırken elinizdeki hareketi hissedin. Tekrar edin.',
      psychologicalFunctions: ['panik azaltma', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text: 'Bu his geçici. Bedeniniz şu an alarm veriyor ama siz bu durumu atlatabilirsiniz.',
      psychologicalFunctions: ['duyguları normalleştirme', 'gerçekçi umut'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),

    // ─── Umutsuzluk ve Çaresizlik ────────────────────────────────────────
    PfaMessage(
      text: 'Bu kadar zor bir anda böyle hissetmek anlaşılır bir tepki. Sizin için endişelenen insanlar var.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Şu an sadece bir sonraki dakikayı düşünün. Küçük adımlar yeterli.',
      psychologicalFunctions: ['öz-etkinlik', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Hayatta olmanız ve mesaj atabilmeniz önemli. Bunu başarıyorsunuz.',
      psychologicalFunctions: ['öz-etkinlik', 'gerçekçi umut'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Böyle anlarda umutsuzluk hissi doğal bir tepkidir. Bu duygu geçer; şu an güçlüsünüz.',
      psychologicalFunctions: ['duyguları normalleştirme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Dışarıda ekipler çalışıyor. Durumunuz bilinmeye devam ediyor.',
      psychologicalFunctions: ['gerçekçi umut', 'güvenlik hissi'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.hopelessness,
    ),

    // ─── Yalnızlık ve Terk Edilmişlik ────────────────────────────────────
    PfaMessage(
      text: 'Yalnız değilsiniz. Bu mesajı okuyorsanız sisteme bağlısınız ve bilgileriniz iletildi.',
      psychologicalFunctions: ['sosyal bağlılık', 'güvenlik hissi'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text: 'Sizi düşünen insanlar var. Şu an ulaşamasalar da varlığınızı biliyorlar.',
      psychologicalFunctions: ['sosyal bağlılık', 'duyguları normalleştirme'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text: 'Bu sistem sayesinde sessiniz duyuluyor. Yalnız değilsiniz.',
      psychologicalFunctions: ['sosyal bağlılık', 'güvenlik ve görülme hissi'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text: 'Uzakta olsalar bile sevdikleriniz sizi arıyor. Sistemimiz konumunuzu paylaşıyor.',
      psychologicalFunctions: ['sosyal bağlılık', 'gerçekçi umut'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
      vulnerabilityPriority: 1,
    ),

    // ─── Şiddetli Ağrı veya Sıkışma ─────────────────────────────────────
    PfaMessage(
      text: 'Ağrıyı biliyoruz. Mümkünse sakin tutun kendinizi — hareketsiz kalmak enerji korur.',
      psychologicalFunctions: ['güvenlik', 'öz-etkinlik'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text: 'Sıkıştığınız yerde derin nefes almak oksijeni verimli kullanmanıza yardımcı olur.',
      psychologicalFunctions: ['öz-etkinlik', 'sakinleşme'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text: 'Durumunuz iletildi. Kurtarma ekipleri böyle durumlara hazırlıklı.',
      psychologicalFunctions: ['güvenlik hissi', 'gerçekçi umut'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text: 'Ağrı ve korku aynı anda çok ağır gelebilir. Bunu hissetmeniz normaldir. Sizi duyan biri var.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sosyal bağlılık'],
      pfaComponent: 'Calming',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text: 'Yanınızda biri varsa onun sesine odaklanın. Yalnızsanız nefesinize odaklanın.',
      psychologicalFunctions: ['sakinleşme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.painTrapped,
    ),

    // ─── Bilgi Belirsizliği / Dışarıda Neler Olduğuna Dair Kaygı ────────
    PfaMessage(
      text: 'Dışarıdaki durumu tam bilmemek zor. Şu an için en sağlıklısı güvenli kalmaya odaklanmak.',
      psychologicalFunctions: ['duyguları normalleştirme', 'öz-etkinlik'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Belirsizlik kaygı yaratır; bu doğal. Kontrol edebildiğinize — nefesinize, pozisyonunuza — odaklanın.',
      psychologicalFunctions: ['duyguları normalleştirme', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Bilgi geldikçe paylaşılacak. Şu an için konumunuz kayıt altında.',
      psychologicalFunctions: ['güvenlik hissi', 'gerçekçi umut'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Sevdikleriniz hakkında bilgi şu an ulaşmıyor olabilir. Bu onların güvende olmadığı anlamına gelmez.',
      psychologicalFunctions: ['duyguları normalleştirme', 'gerçekçi umut'],
      pfaComponent: 'Calming',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Dışarıda koordinasyon sürüyor. Sizi aramak için çalışan insanlar var.',
      psychologicalFunctions: ['gerçekçi umut', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.uncertainty,
    ),
  ];

  static List<PfaMessage> forCategory(PfaCategory category) =>
      all.where((m) => m.category == category).toList();
}
```

- [ ] **Step 2: Commit**
```bash
git add lib/features/disaster_mode/data/pfa_messages.dart
git commit -m "feat(pfa): add Turkish PFA message library (WHO/NCTSN-aligned, 6 categories)"
```

---

### Task 8: PFAMessageService (trigger detection + selection)

**Files:**
- Create: `lib/features/disaster_mode/services/pfa_message_service.dart`
- Create: `test/disaster_mode/services/pfa_message_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/disaster_mode/services/pfa_message_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/services/pfa_message_service.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/data/pfa_messages.dart';

void main() {
  group('PFAMessageService', () {
    late PFAMessageService svc;
    setUp(() => svc = PFAMessageService());

    test('detectCategory returns panicBreathing for panic keywords', () {
      expect(
        svc.detectCategory('nefes alamıyorum çok kötüyüm'),
        PfaCategory.panicBreathing,
      );
    });

    test('detectCategory returns hopelessness for hopelessness keywords', () {
      expect(
        svc.detectCategory('kurtulamayacağım her şey bitti umudum kalmadı'),
        PfaCategory.hopelessness,
      );
    });

    test('detectCategory returns loneliness for loneliness keywords', () {
      expect(
        svc.detectCategory('yalnızım kimse gelmiyor terk edildim'),
        PfaCategory.loneliness,
      );
    });

    test('detectCategory returns painTrapped for pain keywords', () {
      expect(
        svc.detectCategory('çok ağrı var sıkıştım çıkamıyorum'),
        PfaCategory.painTrapped,
      );
    });

    test('detectCategory returns null for neutral message', () {
      expect(svc.detectCategory('tamam bekliyorum'), isNull);
    });

    test('selectMessage returns a message for valid category', () {
      final msg = svc.selectMessage(PfaCategory.firstContact);
      expect(msg, isNotNull);
      expect(msg!.category, PfaCategory.firstContact);
    });

    test('no-response trigger fires after timeout', () async {
      bool triggered = false;
      svc.startNoResponseTimer(
        onTimeout: () => triggered = true,
        duration: const Duration(milliseconds: 50),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      expect(triggered, true);
      svc.cancelNoResponseTimer();
    });

    test('cancelNoResponseTimer prevents callback', () async {
      bool triggered = false;
      svc.startNoResponseTimer(
        onTimeout: () => triggered = true,
        duration: const Duration(milliseconds: 50),
      );
      svc.cancelNoResponseTimer();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(triggered, false);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**
```bash
flutter test test/disaster_mode/services/pfa_message_service_test.dart
```

- [ ] **Step 3: Implement PFAMessageService**

```dart
// lib/features/disaster_mode/services/pfa_message_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart'; // VoidCallback
import '../data/pfa_messages.dart';

class PFAMessageService {
  static final PFAMessageService _instance = PFAMessageService._internal();
  factory PFAMessageService() => _instance;
  PFAMessageService._internal();

  Timer? _noResponseTimer;
  final _rng = Random();

  // ── Keyword lists (Turkish, lowercase) ──────────────────────────────

  static const _panicKeywords = [
    'nefes', 'nefes alamıyorum', 'boğuluyorum', 'bayılacağım',
    'kalp', 'titriyor', 'titriyorum', 'çok kötü', 'panik',
    'korku', 'korkuyorum', 'dayanamıyorum',
  ];

  static const _hopelessnessKeywords = [
    'kurtulamam', 'kurtulamayacağım', 'bitti', 'her şey bitti',
    'umut', 'umudum kalmadı', 'fayda yok', 'boşuna',
    'ölüyorum', 'ölecek', 'anlamsız',
  ];

  static const _lonelinessKeywords = [
    'yalnız', 'yalnızım', 'kimse', 'kimse yok', 'gelmiyor',
    'terk', 'unutulduk', 'unutuldum', 'bana ne oldu',
  ];

  static const _painTrappedKeywords = [
    'ağrı', 'acı', 'sıkıştım', 'sıkışık', 'çıkamıyorum',
    'hareket edemiyorum', 'kırık', 'kan', 'ezildi',
  ];

  static const _uncertaintyKeywords = [
    'bilmiyorum', 'ne oluyor', 'dışarda', 'haber', 'haberim yok',
    'ne zaman', 'söyleyin', 'bilgi', 'bana söyleyin',
  ];

  /// Detects which PFA category a message belongs to.
  /// Returns null if no trigger keywords found.
  PfaCategory? detectCategory(String messageText) {
    final lower = messageText.toLowerCase();
    if (_containsAny(lower, _panicKeywords)) return PfaCategory.panicBreathing;
    if (_containsAny(lower, _hopelessnessKeywords)) return PfaCategory.hopelessness;
    if (_containsAny(lower, _lonelinessKeywords)) return PfaCategory.loneliness;
    if (_containsAny(lower, _painTrappedKeywords)) return PfaCategory.painTrapped;
    if (_containsAny(lower, _uncertaintyKeywords)) return PfaCategory.uncertainty;
    return null;
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  /// Selects a random PFA message for the given category.
  /// Prioritizes vulnerability-priority messages if isVulnerable=true.
  PfaMessage? selectMessage(PfaCategory category, {bool isVulnerable = false}) {
    final candidates = PfaMessages.forCategory(category);
    if (candidates.isEmpty) return null;
    if (isVulnerable) {
      final prioritized = candidates
          .where((m) => m.vulnerabilityPriority > 0)
          .toList();
      if (prioritized.isNotEmpty) {
        return prioritized[_rng.nextInt(prioritized.length)];
      }
    }
    return candidates[_rng.nextInt(candidates.length)];
  }

  /// Returns the first-contact message (used on initial disaster mode entry).
  PfaMessage firstContactMessage() =>
      selectMessage(PfaCategory.firstContact) ??
      PfaMessages.forCategory(PfaCategory.firstContact).first;

  /// Starts a timer that fires [onTimeout] if user hasn't responded in [duration].
  void startNoResponseTimer({
    required VoidCallback onTimeout,
    Duration duration = const Duration(minutes: 10),
  }) {
    _noResponseTimer?.cancel();
    _noResponseTimer = Timer(duration, onTimeout);
  }

  void cancelNoResponseTimer() {
    _noResponseTimer?.cancel();
    _noResponseTimer = null;
  }

  void resetNoResponseTimer({
    required VoidCallback onTimeout,
    Duration duration = const Duration(minutes: 10),
  }) {
    startNoResponseTimer(onTimeout: onTimeout, duration: duration);
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**
```bash
flutter test test/disaster_mode/services/pfa_message_service_test.dart
```

- [ ] **Step 5: Commit**
```bash
git add lib/features/disaster_mode/services/pfa_message_service.dart \
        test/disaster_mode/services/pfa_message_service_test.dart
git commit -m "feat(pfa): add PFAMessageService with Turkish keyword trigger detection"
```

---

### Task 9: PFASupportOverlay widget + DisasterHomePage integration

**Files:**
- Create: `lib/features/disaster_mode/widgets/pfa_support_overlay.dart`
- Modify: `lib/features/disaster_mode/disaster_home_page.dart`

- [ ] **Step 1: Create PFASupportOverlay widget**

```dart
// lib/features/disaster_mode/widgets/pfa_support_overlay.dart
import 'package:flutter/material.dart';
import '../data/pfa_messages.dart';

class PFASupportOverlay extends StatelessWidget {
  final PfaMessage message;
  final VoidCallback onDismiss;

  const PFASupportOverlay({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A2535),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_border,
                      color: Color(0xFF5BC8AF), size: 32),
                  const SizedBox(height: 16),
                  Text(
                    message.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Tamam',
                      style: TextStyle(color: Color(0xFF5BC8AF), fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Integrate into DisasterHomePage**

Read `lib/features/disaster_mode/disaster_home_page.dart` first to find the correct insertion points. Then:

a) Add state variable `PfaMessage? _pfaMessage` to the State class.

b) Add imports:
```dart
import 'services/pfa_message_service.dart';
import 'widgets/pfa_support_overlay.dart';
import 'data/pfa_messages.dart';
```

c) In `initState()`, show first-contact message on entry:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _showPfaMessage(PFAMessageService().firstContactMessage());
  _startNoResponseTimer();
});
```

d) Add helper methods:
```dart
void _showPfaMessage(PfaMessage message) {
  setState(() => _pfaMessage = message);
}

void _dismissPfa() {
  setState(() => _pfaMessage = null);
  _startNoResponseTimer(); // restart after dismiss
}

void _startNoResponseTimer() {
  PFAMessageService().startNoResponseTimer(
    onTimeout: () {
      if (mounted) {
        _showPfaMessage(
          PFAMessageService().selectMessage(PfaCategory.uncertainty) ??
              PFAMessageService().firstContactMessage(),
        );
      }
    },
  );
}

void _onUserMessageSent(String text) {
  PFAMessageService().cancelNoResponseTimer();
  final category = PFAMessageService().detectCategory(text);
  if (category != null) {
    final msg = PFAMessageService().selectMessage(category);
    if (msg != null) _showPfaMessage(msg);
  }
  _startNoResponseTimer();
}
```

e) In `dispose()`, cancel timer:
```dart
PFAMessageService().cancelNoResponseTimer();
```

f) In the `build()` method's widget tree, wrap the scaffold body in a `Stack`:
```dart
Stack(
  children: [
    // existing scaffold content here
    if (_pfaMessage != null)
      PFASupportOverlay(
        message: _pfaMessage!,
        onDismiss: _dismissPfa,
      ),
  ],
)
```

g) Find the manual message send callback. Run:
```bash
grep -n "sendManualMessage\|onPressed\|onSubmitted\|TextField\|_sendMessage" \
  lib/features/disaster_mode/disaster_home_page.dart | head -20
```
Locate the `onPressed:` of the send button or `onSubmitted:` of the text field that calls `controller.sendManualMessage(...)`. Wrap it:
```dart
// Before (example — actual code may differ, find actual line):
onPressed: () => controller.sendManualMessage(_textController.text),

// After:
onPressed: () {
  final text = _textController.text.trim();
  if (text.isEmpty) return;
  controller.sendManualMessage(text);
  _onUserMessageSent(text);
  _textController.clear();
},
```

- [ ] **Step 3: Run all tests**
```bash
flutter test
```

- [ ] **Step 4: Commit**
```bash
git add lib/features/disaster_mode/widgets/pfa_support_overlay.dart \
        lib/features/disaster_mode/disaster_home_page.dart
git commit -m "feat(pfa): integrate PFA overlay into DisasterHomePage with trigger detection"
```

---

## Wave 2 — Madde 1: Vulnerable Group Auto-Transmission
> **PREREQUISITE — HARD GATE:** Do NOT begin any task in Wave 2 until ALL of the following exist in the codebase:
> - `lib/features/disaster_mode/models/user_health_profile.dart` (Task 2)
> - `lib/features/disaster_mode/models/disaster_message_packet.dart` (Task 3)
> - `DisasterController.updateHealthProfile()` method (Task 4)
> - `DisasterController._buildInjuryFlags()` and sibling helpers (Task 4)
>
> Verify with: `grep -r "updateHealthProfile" lib/features/disaster_mode/controllers/disaster_controller.dart`
> If the grep returns no match, Wave 1A is not complete — wait before proceeding.

### Task 10: VulnerableGroupService

**Files:**
- Create: `lib/features/user_profile/services/vulnerable_group_service.dart`
- Create: `test/user_profile/vulnerable_group_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/user_profile/vulnerable_group_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hayat_agi_mobile/features/user_profile/services/vulnerable_group_service.dart';
import 'package:hayat_agi_mobile/features/disaster_mode/models/user_health_profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VulnerableGroupService', () {
    test('isVulnerableGroup defaults to false', () async {
      final svc = VulnerableGroupService();
      await svc.load();
      expect(svc.isVulnerableGroup, false);
    });

    test('save and load health profile round-trip', () async {
      final svc = VulnerableGroupService();
      final profile = UserHealthProfile(
        hasProfile: true,
        age: AgeRange.elderly75plus,
        gender: Gender.female,
        chronicDiseases: {ChronicDisease.heartDisease},
        medications: {Medication.bloodThinner},
        disability: DisabilityStatus.mobility,
      );
      await svc.saveProfile(profile: profile, isVulnerableGroup: true);
      await svc.load();
      expect(svc.isVulnerableGroup, true);
      expect(svc.profile.age, AgeRange.elderly75plus);
      expect(svc.profile.chronicDiseases, contains(ChronicDisease.heartDisease));
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**
```bash
flutter test test/user_profile/vulnerable_group_service_test.dart
```

- [ ] **Step 3: Implement VulnerableGroupService**

```dart
// lib/features/user_profile/services/vulnerable_group_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../disaster_mode/models/user_health_profile.dart'; // NOT ../../features/...

class VulnerableGroupService {
  static final VulnerableGroupService _instance =
      VulnerableGroupService._internal();
  factory VulnerableGroupService() => _instance;
  VulnerableGroupService._internal();

  static const _keyIsVulnerable = 'vg_is_vulnerable';
  static const _keyProfileBytes = 'vg_profile_bytes';
  static const _keyLastLat = 'vg_last_lat';
  static const _keyLastLng = 'vg_last_lng';
  static const _keyLastLocationTime = 'vg_last_location_time';

  bool _isVulnerableGroup = false;
  UserHealthProfile _profile = UserHealthProfile.empty();
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastLocationTime;

  bool get isVulnerableGroup => _isVulnerableGroup;
  UserHealthProfile get profile => _profile;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;
  DateTime? get lastLocationTime => _lastLocationTime;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isVulnerableGroup = prefs.getBool(_keyIsVulnerable) ?? false;
    final bytesJson = prefs.getString(_keyProfileBytes);
    if (bytesJson != null) {
      final list = (jsonDecode(bytesJson) as List).cast<int>();
      _profile = UserHealthProfile.fromBytes(
        Uint8List.fromList(list),
      );
    }
    _lastLat = prefs.getDouble(_keyLastLat);
    _lastLng = prefs.getDouble(_keyLastLng);
    final timeMs = prefs.getInt(_keyLastLocationTime);
    if (timeMs != null) {
      _lastLocationTime = DateTime.fromMillisecondsSinceEpoch(timeMs);
    }
  }

  Future<void> saveProfile({
    required UserHealthProfile profile,
    required bool isVulnerableGroup,
  }) async {
    _profile = profile;
    _isVulnerableGroup = isVulnerableGroup;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsVulnerable, isVulnerableGroup);
    await prefs.setString(
      _keyProfileBytes,
      jsonEncode(profile.toBytes().toList()),
    );
  }

  /// Call this every hour (or on app foreground) to update the cached location.
  Future<void> updateLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastLocationTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLastLat, pos.latitude);
      await prefs.setDouble(_keyLastLng, pos.longitude);
      await prefs.setInt(
          _keyLastLocationTime, _lastLocationTime!.millisecondsSinceEpoch);
    } catch (_) {
      // Location unavailable — use last known
    }
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**
```bash
flutter test test/user_profile/vulnerable_group_service_test.dart
```

- [ ] **Step 5: Commit**
```bash
git add lib/features/user_profile/services/vulnerable_group_service.dart \
        test/user_profile/vulnerable_group_service_test.dart
git commit -m "feat(vulnerable): add VulnerableGroupService with profile persistence and location cache"
```

---

### Task 11: Settings UI for vulnerable group profile

**Files:**
- Modify: `lib/features/settings/settings_page.dart`

- [ ] **Step 1: Read settings_page.dart to find insertion point**

```bash
# Look for existing sections / list tiles
grep -n "ListTile\|Section\|Card\|Column" lib/features/settings/settings_page.dart | head -30
```

- [ ] **Step 2: Add vulnerable group section**

Add imports:
```dart
import '../user_profile/services/vulnerable_group_service.dart';
import '../disaster_mode/models/user_health_profile.dart';
```

Add a new settings section (after existing sections, before closing of the settings list):

```dart
// Kırılgan Grup Ayarları
_SettingsSection(
  title: 'Kırılgan Grup Profili',
  children: [
    SwitchListTile(
      title: const Text('Kırılgan grup olarak işaretle'),
      subtitle: const Text('Yaşlı, çocuk veya kronik hastalık durumu'),
      value: _isVulnerableGroup,
      onChanged: (val) async {
        setState(() => _isVulnerableGroup = val);
        await VulnerableGroupService().saveProfile(
          profile: VulnerableGroupService().profile,
          isVulnerableGroup: val,
        );
      },
    ),
    if (_isVulnerableGroup) ...[
      ListTile(
        title: const Text('Yaş grubu'),
        trailing: DropdownButton<AgeRange>(
          value: _selectedAge,
          items: AgeRange.values.map((a) => DropdownMenuItem(
            value: a,
            child: Text(_ageLabel(a)),
          )).toList(),
          onChanged: (val) => setState(() => _selectedAge = val ?? AgeRange.unknown),
        ),
      ),
      ListTile(
        title: const Text('Kronik hastalıklar'),
        subtitle: Text(_selectedDiseases.isEmpty
            ? 'Belirtilmedi'
            : _selectedDiseases.map(_diseaseLabel).join(', ')),
        onTap: _showDiseaseSelector,
      ),
      ListTile(
        title: const Text('Düzenli ilaçlar'),
        subtitle: Text(_selectedMeds.isEmpty
            ? 'Belirtilmedi'
            : _selectedMeds.map(_medLabel).join(', ')),
        onTap: _showMedSelector,
      ),
      ListTile(
        title: const Text('Engellilik durumu'),
        trailing: DropdownButton<DisabilityStatus>(
          value: _selectedDisability,
          items: DisabilityStatus.values.map((d) => DropdownMenuItem(
            value: d,
            child: Text(_disabilityLabel(d)),
          )).toList(),
          onChanged: (val) => setState(() =>
              _selectedDisability = val ?? DisabilityStatus.none),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton(
          onPressed: _saveHealthProfile,
          child: const Text('Profili Kaydet'),
        ),
      ),
    ],
  ],
),
```

Add state variables to the State class:
```dart
bool _isVulnerableGroup = false;
AgeRange _selectedAge = AgeRange.unknown;
Set<ChronicDisease> _selectedDiseases = {};
Set<Medication> _selectedMeds = {};
DisabilityStatus _selectedDisability = DisabilityStatus.none;
```

Add `_saveHealthProfile()`:
```dart
Future<void> _saveHealthProfile() async {
  final profile = UserHealthProfile(
    hasProfile: true,
    age: _selectedAge,
    gender: Gender.unknown, // not collected in this form
    chronicDiseases: _selectedDiseases,
    medications: _selectedMeds,
    disability: _selectedDisability,
  );
  await VulnerableGroupService().saveProfile(
    profile: profile,
    isVulnerableGroup: _isVulnerableGroup,
  );
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil kaydedildi.')),
    );
  }
}
```

Add label helpers:
```dart
String _ageLabel(AgeRange a) => const {
  AgeRange.unknown: 'Belirtilmedi',
  AgeRange.child0to9: '0–9',
  AgeRange.teen10to17: '10–17',
  AgeRange.young18to29: '18–29',
  AgeRange.adult30to44: '30–44',
  AgeRange.range45to59: '45–59',
  AgeRange.senior60to74: '60–74',
  AgeRange.elderly75plus: '75+',
}[a]!;

String _diseaseLabel(ChronicDisease d) => const {
  ChronicDisease.heartDisease: 'Kalp hastalığı',
  ChronicDisease.diabetes: 'Diyabet',
  ChronicDisease.hypertension: 'Hipertansiyon',
  ChronicDisease.asthma: 'Astım',
  ChronicDisease.epilepsy: 'Epilepsi',
  ChronicDisease.renalDisease: 'Böbrek hastalığı',
  ChronicDisease.cancer: 'Kanser',
  ChronicDisease.other: 'Diğer',
}[d]!;

String _medLabel(Medication m) => const {
  Medication.bloodThinner: 'Kan sulandırıcı',
  Medication.insulin: 'İnsülin',
  Medication.heartMed: 'Kalp ilacı',
  Medication.antiepileptic: 'Epilepsi ilacı',
  Medication.immunosuppressant: 'Bağışıklık ilacı',
  Medication.painKiller: 'Ağrı kesici',
  Medication.other: 'Diğer',
}[m]!;

String _disabilityLabel(DisabilityStatus d) => const {
  DisabilityStatus.none: 'Yok',
  DisabilityStatus.mobility: 'Hareket kısıtlılığı',
  DisabilityStatus.visual: 'Görme engeli',
  DisabilityStatus.hearing: 'İşitme engeli',
  DisabilityStatus.cognitive: 'Bilişsel engel',
  DisabilityStatus.other: 'Diğer',
}[d]!;
```

In `initState()`, load values:
```dart
VulnerableGroupService().load().then((_) {
  if (mounted) {
    setState(() {
      _isVulnerableGroup = VulnerableGroupService().isVulnerableGroup;
      final p = VulnerableGroupService().profile;
      _selectedAge = p.age;
      _selectedDiseases = Set.from(p.chronicDiseases);
      _selectedMeds = Set.from(p.medications);
      _selectedDisability = p.disability;
    });
  }
});
```

- [ ] **Step 3: Run all tests**
```bash
flutter test
```

- [ ] **Step 4: Commit**
```bash
git add lib/features/settings/settings_page.dart
git commit -m "feat(vulnerable): add vulnerable group health profile settings UI"
```

---

### Task 12: Auto-send on disaster activation

**Files:**
- Modify: `lib/features/disaster_mode/controllers/disaster_controller.dart`

- [ ] **Step 1: Add auto-send logic**

In `DisasterController`, add a method `onDisasterActivated()`:
```dart
/// Call this when disaster mode first activates.
/// If user is marked as vulnerable group, auto-sends their health profile.
Future<void> onDisasterActivated() async {
  final vgs = VulnerableGroupService();
  await vgs.load();

  if (!vgs.isVulnerableGroup) return;

  // Update the health profile so it's included in the next send
  updateHealthProfile(vgs.profile);

  // Build and send the vulnerable group packet immediately
  final packet = DisasterMessagePacket.simple(
    triageScore: triageScore.value,
    triageStatusBitmask: selectedStatus.value?.bitmaskValue ?? 0,
    severityNibble: 0,
    injuryFlags: _buildInjuryFlags(),
    situationFlags: _buildSituationFlags(),
    needsFlags: _buildNeedsFlags(),
    peopleFlags: _buildPeopleFlags(),
    adultCount: adultCount.value,
    childCount: childCount.value,
    healthProfile: vgs.profile,
    messageText: '[KIRILGAN GRUP] Otomatik sağlık profili iletimi',
  );

  await _bleService.sendBinaryQueued(packet.encode());
}
```

Add import:
```dart
import '../../user_profile/services/vulnerable_group_service.dart';
```

- [ ] **Step 2: Call onDisasterActivated from DisasterHomePage**

In `disaster_home_page.dart`, in `initState()`, after the controller is initialized:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await Get.find<DisasterController>().onDisasterActivated();
});
```

- [ ] **Step 3: Run all tests**
```bash
flutter test
```

- [ ] **Step 4: Final commit**
```bash
git add lib/features/disaster_mode/controllers/disaster_controller.dart \
        lib/features/disaster_mode/disaster_home_page.dart
git commit -m "feat(vulnerable): auto-send vulnerable group health profile on disaster activation"
```

---

## Final Verification

- [ ] Run full test suite: `flutter test`
- [ ] Run static analysis: `flutter analyze`
- [ ] Verify no regressions in BLE constants: `grep -n "protocolVersion" lib/features/ble/BLEConstants.dart`
- [ ] Verify all 4 features are wired end-to-end
