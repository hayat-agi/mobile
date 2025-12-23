class HouseholdMember {
  final String name;
  final int age;
  final bool isElderly; // 65+ years old
  final bool isChild; // Under 18 years old
  final List<String> medicalConditions;
  final List<String> specialNeeds;

  HouseholdMember({
    required this.name,
    required this.age,
    this.isElderly = false,
    this.isChild = false,
    this.medicalConditions = const [],
    this.specialNeeds = const [],
  });

  HouseholdMember copyWith({
    String? name,
    int? age,
    bool? isElderly,
    bool? isChild,
    List<String>? medicalConditions,
    List<String>? specialNeeds,
  }) {
    return HouseholdMember(
      name: name ?? this.name,
      age: age ?? this.age,
      isElderly: isElderly ?? this.isElderly,
      isChild: isChild ?? this.isChild,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      specialNeeds: specialNeeds ?? this.specialNeeds,
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
    );
  }
}

