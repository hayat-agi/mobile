import 'dart:typed_data';

enum Gender { unknown, male, female, other }

enum AgeRange {
  unknown, // 0
  child0to9, // 1
  teen10to17, // 2
  young18to29, // 3
  adult30to44, // 4
  range45to59, // 5
  senior60to74, // 6
  elderly75plus, // 7
}

enum ChronicDisease {
  heartDisease, // bit 0
  diabetes, // bit 1
  hypertension, // bit 2
  asthma, // bit 3
  epilepsy, // bit 4
  renalDisease, // bit 5
  cancer, // bit 6
  other, // bit 7
}

enum Medication {
  bloodThinner, // bit 0
  insulin, // bit 1
  heartMed, // bit 2
  antiepileptic, // bit 3
  immunosuppressant, // bit 4
  painKiller, // bit 5
  other, // bit 6
}

/// Non-[none] values map to bits 0–4 in the disability bitmask (byte 1).
enum DisabilityStatus {
  none, // not stored in bitmask
  mobility, // bit 0
  visual, // bit 1
  hearing, // bit 2
  cognitive, // bit 3
  other, // bit 4
}

class UserHealthProfile {
  final bool hasProfile;
  final AgeRange age;
  final Gender gender;
  final Set<ChronicDisease> chronicDiseases;
  final Set<Medication> medications;
  /// Multiple disabilities supported; [DisabilityStatus.none] is never stored.
  final Set<DisabilityStatus> disabilities;

  const UserHealthProfile({
    required this.hasProfile,
    required this.age,
    required this.gender,
    required this.chronicDiseases,
    required this.medications,
    required this.disabilities,
  });

  factory UserHealthProfile.empty() => const UserHealthProfile(
        hasProfile: false,
        age: AgeRange.unknown,
        gender: Gender.unknown,
        chronicDiseases: {},
        medications: {},
        disabilities: {},
      );

  /// 4 bytes:
  /// Byte 0: [7]=hasProfile [6:5]=gender [4:2]=ageRange [1:0]=reserved (0 in new format)
  /// Byte 1: [4:0]=disability bitmask (mobility..other); [7:5]=reserved
  ///         Legacy: disability index was split across byte0 [1:0] and byte1 [7]
  /// Byte 2: chronic disease bitmask
  /// Byte 3: medication bitmask
  Uint8List toBytes() {
    final bytes = Uint8List(4);
    bytes[0] = (hasProfile ? 0x80 : 0x00) |
        ((gender.index & 0x03) << 5) |
        ((age.index & 0x07) << 2);
    // bitmask: bit i => DisabilityStatus.values[i+1]
    int dMask = 0;
    for (final d in disabilities) {
      if (d == DisabilityStatus.none) continue;
      final bit = d.index - 1;
      if (bit >= 0 && bit < 5) dMask |= 1 << bit;
    }
    bytes[1] = dMask & 0x1F;
    bytes[2] = chronicDiseases.fold(0, (mask, d) => mask | (1 << d.index));
    bytes[3] = medications.fold(0, (mask, m) => mask | (1 << m.index));
    return bytes;
  }

  factory UserHealthProfile.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) return UserHealthProfile.empty();
    final hasProfile = (bytes[0] & 0x80) != 0;
    final gender = Gender.values[(bytes[0] >> 5) & 0x03];
    final age = AgeRange.values[(bytes[0] >> 2) & 0x07];

    final disabilities = <DisabilityStatus>{};
    final newMask = bytes[1] & 0x1F;
    if (newMask != 0) {
      for (var i = 0; i < 5; i++) {
        if ((newMask & (1 << i)) != 0) {
          disabilities.add(DisabilityStatus.values[i + 1]);
        }
      }
    } else {
      // Legacy single disability (3-bit index in old layout)
      final idx =
          ((bytes[0] & 0x03) << 1) | ((bytes[1] >> 7) & 0x01);
      if (idx > 0 && idx < DisabilityStatus.values.length) {
        disabilities.add(DisabilityStatus.values[idx]);
      }
    }

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
      disabilities: disabilities,
    );
  }

  Map<String, dynamic> toJson() => {
        'hasProfile': hasProfile,
        'age': age.name,
        'gender': gender.name,
        'chronicDiseases': chronicDiseases.map((d) => d.name).toList(),
        'medications': medications.map((m) => m.name).toList(),
        'disabilities': disabilities.map((d) => d.name).toList(),
      };

  UserHealthProfile copyWith({
    bool? hasProfile,
    AgeRange? age,
    Gender? gender,
    Set<ChronicDisease>? chronicDiseases,
    Set<Medication>? medications,
    Set<DisabilityStatus>? disabilities,
  }) =>
      UserHealthProfile(
        hasProfile: hasProfile ?? this.hasProfile,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        chronicDiseases: chronicDiseases ?? this.chronicDiseases,
        medications: medications ?? this.medications,
        disabilities: disabilities ?? this.disabilities,
      );
}
