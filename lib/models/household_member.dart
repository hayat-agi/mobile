class HouseholdMember {
  final String name;
  final String birthDate; // ISO date: YYYY-MM-DD
  final List<String> medicalConditions;
  final List<String> specialNeeds;

  final String? tcNumber;
  final String? gender;
  final String? bloodType;
  final List<String>? medications;
  final List<String>? prosthetics;

  // Daily typical locations for members without phones (elderly/children)
  final String? morningLocation;
  final String? noonLocation;
  final String? eveningLocation;

  HouseholdMember({
    required this.name,
    required this.birthDate,
    this.medicalConditions = const [],
    this.specialNeeds = const [],
    this.tcNumber,
    this.gender,
    this.bloodType,
    this.medications,
    this.prosthetics,
    this.morningLocation,
    this.noonLocation,
    this.eveningLocation,
  });

  int get age {
    final birth = DateTime.tryParse(birthDate);
    if (birth == null) return 0;
    final now = DateTime.now();
    int y = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      y--;
    }
    return y;
  }

  bool get isChild => age < 18;
  bool get isElderly => age >= 65;

  HouseholdMember copyWith({
    String? name,
    String? birthDate,
    List<String>? medicalConditions,
    List<String>? specialNeeds,
    String? tcNumber,
    String? gender,
    String? bloodType,
    List<String>? medications,
    List<String>? prosthetics,
    String? morningLocation,
    String? noonLocation,
    String? eveningLocation,
  }) {
    return HouseholdMember(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      tcNumber: tcNumber ?? this.tcNumber,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      medications: medications ?? this.medications,
      prosthetics: prosthetics ?? this.prosthetics,
      morningLocation: morningLocation ?? this.morningLocation,
      noonLocation: noonLocation ?? this.noonLocation,
      eveningLocation: eveningLocation ?? this.eveningLocation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'birthDate': birthDate,
      'age': age,
      'isElderly': isElderly,
      'isChild': isChild,
      'medicalConditions': medicalConditions,
      'specialNeeds': specialNeeds,
      if (tcNumber != null) 'tcNumber': tcNumber,
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'bloodType': bloodType,
      if (medications != null) 'medications': medications,
      if (prosthetics != null) 'prosthetics': prosthetics,
      if (morningLocation != null) 'morningLocation': morningLocation,
      if (noonLocation != null) 'noonLocation': noonLocation,
      if (eveningLocation != null) 'eveningLocation': eveningLocation,
    };
  }

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    // Backward compat: old data has age but no birthDate
    var birthDate = json['birthDate'] as String? ?? '';
    if (birthDate.isEmpty) {
      final age = json['age'] as int? ?? 0;
      birthDate = '${DateTime.now().year - age}-01-01';
    }
    return HouseholdMember(
      name: json['name'] as String,
      birthDate: birthDate,
      medicalConditions: (json['medicalConditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      specialNeeds: (json['specialNeeds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tcNumber: json['tcNumber'] as String?,
      gender: json['gender'] as String?,
      bloodType: json['bloodType'] as String?,
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      prosthetics: (json['prosthetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      morningLocation: json['morningLocation'] as String?,
      noonLocation: json['noonLocation'] as String?,
      eveningLocation: json['eveningLocation'] as String?,
    );
  }
}
