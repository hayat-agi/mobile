class Pet {
  final String name;
  final String type; // e.g., "Köpek", "Kedi", "Kuş", etc.
  final String? specialNeeds; // e.g., "İlaç gerekiyor", "Özel diyet"

  // Optional backend-sync fields (nullable for backward compatibility)
  final String? breed;
  final String? microchipId;

  Pet({
    required this.name,
    required this.type,
    this.specialNeeds,
    this.breed,
    this.microchipId,
  });

  Pet copyWith({
    String? name,
    String? type,
    String? specialNeeds,
    String? breed,
    String? microchipId,
  }) {
    return Pet(
      name: name ?? this.name,
      type: type ?? this.type,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      breed: breed ?? this.breed,
      microchipId: microchipId ?? this.microchipId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      if (specialNeeds != null) 'specialNeeds': specialNeeds,
      if (breed != null) 'breed': breed,
      if (microchipId != null) 'microchipId': microchipId,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      name: json['name'] as String,
      type: json['type'] as String,
      specialNeeds: json['specialNeeds'] as String?,
      breed: json['breed'] as String?,
      microchipId: json['microchipId'] as String?,
    );
  }
}

