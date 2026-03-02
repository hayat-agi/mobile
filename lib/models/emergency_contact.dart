class EmergencyContact {
  final String name;
  final String phone;
  final String relationship; // e.g., "Eş", "Kardeş", "Arkadaş", etc.

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String,
    );
  }
}

