class BackendGateway {
  final String id;
  final String? name;
  final String? macAddress;
  final String? status;
  final List<BackendCitizen> citizens;
  final List<BackendPet> pets;
  final Map<String, dynamic>? address;

  BackendGateway({
    required this.id,
    this.name,
    this.macAddress,
    this.status,
    this.citizens = const [],
    this.pets = const [],
    this.address,
  });

  factory BackendGateway.fromJson(Map<String, dynamic> json) {
    return BackendGateway(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String?,
      macAddress: json['macAddress'] as String?,
      status: json['status'] as String?,
      citizens: (json['registered_users'] as List<dynamic>? ?? json['citizens'] as List<dynamic>?)
              ?.map((e) => BackendCitizen.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      pets: (json['registered_animals'] as List<dynamic>? ?? json['pets'] as List<dynamic>?)
              ?.map((e) => BackendPet.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      address: json['address'] as Map<String, dynamic>?,
    );
  }
}

class BackendCitizen {
  final String? id;
  final String fullname;
  final String? tcNumber;
  final String? birthDate;
  final String? gender;
  final String? bloodType;
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> prosthetics;

  BackendCitizen({
    this.id,
    required this.fullname,
    this.tcNumber,
    this.birthDate,
    this.gender,
    this.bloodType,
    this.medicalConditions = const [],
    this.medications = const [],
    this.prosthetics = const [],
  });

  factory BackendCitizen.fromJson(Map<String, dynamic> json) {
    return BackendCitizen(
      id: json['_id'] as String?,
      fullname: json['fullname'] as String? ?? '',
      tcNumber: json['tcNumber'] as String?,
      birthDate: json['birthDate'] as String?,
      gender: json['gender'] as String?,
      bloodType: json['bloodType'] as String?,
      medicalConditions: (json['medicalConditions'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      prosthetics: (json['prosthetics'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullname': fullname,
      if (tcNumber != null) 'tcNumber': tcNumber,
      if (birthDate != null) 'birthDate': birthDate,
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'bloodType': bloodType,
      'medicalConditions': medicalConditions,
      'medications': medications,
      'prosthetics': prosthetics,
    };
  }
}

class BackendPet {
  final String? id;
  final String name;
  final String species;
  final String? breed;
  final String? microchipId;
  final String? specialNeeds;

  BackendPet({
    this.id,
    required this.name,
    required this.species,
    this.breed,
    this.microchipId,
    this.specialNeeds,
  });

  factory BackendPet.fromJson(Map<String, dynamic> json) {
    return BackendPet(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      breed: json['breed'] as String?,
      microchipId: json['microchipId'] as String?,
      specialNeeds: json['specialNeeds'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (microchipId != null) 'microchipId': microchipId,
      if (specialNeeds != null) 'specialNeeds': specialNeeds,
    };
  }
}
