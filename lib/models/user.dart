class User {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String? tcNumber;
  final String role;
  final String? phoneNumber;
  final String? bloodType;
  final String? birthDate;
  final String? gender;
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> prosthetics;
  final Map<String, dynamic>? emergencyContact;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.tcNumber,
    this.role = 'user',
    this.phoneNumber,
    this.bloodType,
    this.birthDate,
    this.gender,
    this.medicalConditions = const [],
    this.medications = const [],
    this.prosthetics = const [],
    this.emergencyContact,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      surname: json['surname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      tcNumber: json['tcNumber'] as String?,
      role: json['role'] as String? ?? 'user',
      phoneNumber: json['phoneNumber'] as String?,
      bloodType: json['bloodType'] as String?,
      birthDate: json['birthDate'] as String?,
      gender: json['gender'] as String?,
      medicalConditions: (json['medicalConditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      prosthetics: (json['prosthetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      emergencyContact: json['emergencyContact'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'tcNumber': tcNumber,
      'phoneNumber': phoneNumber,
      'bloodType': bloodType,
      'birthDate': birthDate,
      'gender': gender,
      'medicalConditions': medicalConditions,
      'medications': medications,
      'prosthetics': prosthetics,
      'emergencyContact': emergencyContact,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? surname,
    String? email,
    String? tcNumber,
    String? role,
    String? phoneNumber,
    String? bloodType,
    String? birthDate,
    String? gender,
    List<String>? medicalConditions,
    List<String>? medications,
    List<String>? prosthetics,
    Map<String, dynamic>? emergencyContact,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      tcNumber: tcNumber ?? this.tcNumber,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodType: bloodType ?? this.bloodType,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      prosthetics: prosthetics ?? this.prosthetics,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  String get fullName => '$name $surname';
}
