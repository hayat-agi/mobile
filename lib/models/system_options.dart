class SystemOptions {
  final List<String> bloodTypes;
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> prosthetics;

  // Gender is stored as backend enum key ('male', 'female', ...) and shown to
  // the user with the matching label ('Erkek', 'Kadın', ...). Keeping the
  // mapping intact lets the dropdown display labels while sending keys to the
  // server, which is the value the schema actually validates against.
  final Map<String, String> genderLabels;

  SystemOptions({
    required this.bloodTypes,
    required this.medicalConditions,
    required this.medications,
    required this.prosthetics,
    required this.genderLabels,
  });

  List<String> get genderKeys => genderLabels.keys.toList();

  factory SystemOptions.fromJson(Map<String, dynamic> json) {
    final health = json['healthOptions'] as Map<String, dynamic>? ?? {};
    final genderMap = json['genderLabels'] as Map<String, dynamic>? ?? {};
    return SystemOptions(
      bloodTypes: _parseStringList(health['bloodGroups']),
      medicalConditions: _parseStringList(health['chronicConditions']),
      medications: _parseStringList(health['medications']),
      prosthetics: _parseStringList(health['prostheses']),
      genderLabels: genderMap.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  factory SystemOptions.defaults() {
    return SystemOptions(
      bloodTypes: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'],
      medicalConditions: ['Diyabet', 'Hipertansiyon', 'Astım', 'Kalp Hastalığı', 'Epilepsi'],
      medications: ['İnsülin', 'Ventolin', 'Aspirin'],
      prosthetics: ['Protez Bacak', 'Protez Kol', 'İşitme Cihazı', 'Gözlük'],
      // Must mirror backend GENDER_LABELS exactly — sending a label that
      // doesn't reverse-map to a key trips the schema enum validator.
      genderLabels: {
        'male': 'Erkek',
        'female': 'Kadın',
        'prefer_not_to_say': 'Belirtmek İstemiyorum',
      },
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
