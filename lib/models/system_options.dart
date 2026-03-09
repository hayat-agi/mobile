class SystemOptions {
  final List<String> bloodTypes;
  final List<String> medicalConditions;
  final List<String> medications;
  final List<String> prosthetics;
  final List<String> genderOptions;

  SystemOptions({
    required this.bloodTypes,
    required this.medicalConditions,
    required this.medications,
    required this.prosthetics,
    required this.genderOptions,
  });

  factory SystemOptions.fromJson(Map<String, dynamic> json) {
    return SystemOptions(
      bloodTypes: _parseStringList(json['bloodTypes']),
      medicalConditions: _parseStringList(json['medicalConditions']),
      medications: _parseStringList(json['medications']),
      prosthetics: _parseStringList(json['prosthetics']),
      genderOptions: _parseStringList(json['genderOptions']),
    );
  }

  factory SystemOptions.defaults() {
    return SystemOptions(
      bloodTypes: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'],
      medicalConditions: ['Diyabet', 'Hipertansiyon', 'Astım', 'Kalp Hastalığı', 'Epilepsi'],
      medications: ['İnsülin', 'Ventolin', 'Aspirin'],
      prosthetics: ['Protez Bacak', 'Protez Kol', 'İşitme Cihazı', 'Gözlük'],
      genderOptions: ['Erkek', 'Kadın', 'Diğer'],
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
