class HouseholdMember {
  final String name;
  final int age;
  final bool isElderly; // 65+ years old
  final bool isChild; // Under 18 years old
  final List<String> medicalConditions;
  final List<String> specialNeeds;

  // Optional backend-sync fields (nullable for backward compatibility)
  final String? tcNumber;
  final String? gender;
  final String? birthDate;
  final String? bloodType;
  final List<String>? medications;
  final List<String>? prosthetics;

  HouseholdMember({
    required this.name,
    required this.age,
    this.isElderly = false,
    this.isChild = false,
    this.medicalConditions = const [],
    this.specialNeeds = const [],
    this.tcNumber,
    this.gender,
    this.birthDate,
    this.bloodType,
    this.medications,
    this.prosthetics,
  });

  HouseholdMember copyWith({
    String? name,
    int? age,
    bool? isElderly,
    bool? isChild,
    List<String>? medicalConditions,
    List<String>? specialNeeds,
    String? tcNumber,
    String? gender,
    String? birthDate,
    String? bloodType,
    List<String>? medications,
    List<String>? prosthetics,
  }) {
    return HouseholdMember(
      name: name ?? this.name,
      age: age ?? this.age,
      isElderly: isElderly ?? this.isElderly,
      isChild: isChild ?? this.isChild,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      tcNumber: tcNumber ?? this.tcNumber,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      bloodType: bloodType ?? this.bloodType,
      medications: medications ?? this.medications,
      prosthetics: prosthetics ?? this.prosthetics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'isElderly': isElderly,
      'isChild': isChild,
      'medicalConditions': medicalConditions,
      'specialNeeds': specialNeeds,
      if (tcNumber != null) 'tcNumber': tcNumber,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate,
      if (bloodType != null) 'bloodType': bloodType,
      if (medications != null) 'medications': medications,
      if (prosthetics != null) 'prosthetics': prosthetics,
    };
  }

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      name: json['name'] as String,
      age: json['age'] as int,
      isElderly: json['isElderly'] as bool? ?? false,
      isChild: json['isChild'] as bool? ?? false,
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
      birthDate: json['birthDate'] as String?,
      bloodType: json['bloodType'] as String?,
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      prosthetics: (json['prosthetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );
  }
}

