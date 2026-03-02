class Pet {
  final String name;
  final String type; // e.g., "Köpek", "Kedi", "Kuş", etc.
  final String? specialNeeds; // e.g., "İlaç gerekiyor", "Özel diyet"

  Pet({
    required this.name,
    required this.type,
    this.specialNeeds,
  });

  Pet copyWith({
    String? name,
    String? type,
    String? specialNeeds,
  }) {
    return Pet(
      name: name ?? this.name,
      type: type ?? this.type,
      specialNeeds: specialNeeds ?? this.specialNeeds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'specialNeeds': specialNeeds,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      name: json['name'] as String,
      type: json['type'] as String,
      specialNeeds: json['specialNeeds'] as String?,
    );
  }
}

