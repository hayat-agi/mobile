import 'dart:typed_data';

enum Gender { unknown, male, female, other }

enum AgeRange {
  unknown,      // 0
  child0to9,    // 1
  teen10to17,   // 2
  young18to29,  // 3
  adult30to44,  // 4
  range45to59,  // 5
  senior60to74, // 6
  elderly75plus,// 7
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
  /// Byte 1: [7]=disability[0]  [6:0]=reserved(0)
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
    final disabilityIndex =
        ((bytes[0] & 0x03) << 1) | ((bytes[1] >> 7) & 0x01);
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
