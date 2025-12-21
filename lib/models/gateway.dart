class Gateway {
  final String id;
  final String name;
  final String? macAddress;
  final GatewayStatus status;
  final int batteryLevel; // 0-100
  final int? signalStrength; // RSSI
  final DateTime? lastSeen;
  final DateTime? connectedAt;
  final int messagesSent;
  final int messagesReceived;
  
  // Address fields
  final BuildingType? buildingType;
  final String? street;
  final String? buildingNumber;
  final String? doorNumber;
  final String? district;
  final String? city;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  Gateway({
    required this.id,
    required this.name,
    this.macAddress,
    required this.status,
    this.batteryLevel = 100,
    this.signalStrength,
    this.lastSeen,
    this.connectedAt,
    this.messagesSent = 0,
    this.messagesReceived = 0,
    this.buildingType,
    this.street,
    this.buildingNumber,
    this.doorNumber,
    this.district,
    this.city,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  bool get isConnected => status == GatewayStatus.connected;
  bool get isLowBattery => batteryLevel < 20;
  bool get hasGoodSignal => signalStrength != null && signalStrength! > -70;

  Gateway copyWith({
    String? id,
    String? name,
    String? macAddress,
    GatewayStatus? status,
    int? batteryLevel,
    int? signalStrength,
    DateTime? lastSeen,
    DateTime? connectedAt,
    int? messagesSent,
    int? messagesReceived,
    BuildingType? buildingType,
    String? street,
    String? buildingNumber,
    String? doorNumber,
    String? district,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
  }) {
    return Gateway(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      lastSeen: lastSeen ?? this.lastSeen,
      connectedAt: connectedAt ?? this.connectedAt,
      messagesSent: messagesSent ?? this.messagesSent,
      messagesReceived: messagesReceived ?? this.messagesReceived,
      buildingType: buildingType ?? this.buildingType,
      street: street ?? this.street,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      doorNumber: doorNumber ?? this.doorNumber,
      district: district ?? this.district,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
  
  // Helper to check if address is complete
  bool get hasCompleteAddress {
    return buildingType != null &&
        street != null &&
        street!.isNotEmpty &&
        buildingNumber != null &&
        buildingNumber!.isNotEmpty &&
        district != null &&
        district!.isNotEmpty &&
        city != null &&
        city!.isNotEmpty &&
        postalCode != null &&
        postalCode!.isNotEmpty;
  }
  
  // Get formatted address string
  String get formattedAddress {
    if (!hasCompleteAddress) return 'Adres girilmemiş';
    
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (buildingNumber != null && buildingNumber!.isNotEmpty) {
      parts.add('No: $buildingNumber');
    }
    if (doorNumber != null && doorNumber!.isNotEmpty) {
      parts.add('Daire: $doorNumber');
    }
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (postalCode != null && postalCode!.isNotEmpty) {
      parts.add('Posta Kodu: $postalCode');
    }
    
    return parts.join(', ');
  }
}

enum GatewayStatus {
  connected,
  disconnected,
  scanning,
  connecting,
  error,
}

extension GatewayStatusExtension on GatewayStatus {
  String get displayName {
    switch (this) {
      case GatewayStatus.connected:
        return 'Bağlı';
      case GatewayStatus.disconnected:
        return 'Bağlantı Kesildi';
      case GatewayStatus.scanning:
        return 'Taranıyor';
      case GatewayStatus.connecting:
        return 'Bağlanıyor';
      case GatewayStatus.error:
        return 'Hata';
    }
  }
}

enum BuildingType {
  houseSingleFamily,
  houseMultiFamily,
  apartment,
  officeCommercial,
  schoolResidence,
  assistedLivingFacility,
  homelessTransient,
  other,
}

extension BuildingTypeExtension on BuildingType {
  String get displayName {
    switch (this) {
      case BuildingType.houseSingleFamily:
        return 'Ev - Tek Aile';
      case BuildingType.houseMultiFamily:
        return 'Ev - Çoklu Aile';
      case BuildingType.apartment:
        return 'Apartman';
      case BuildingType.officeCommercial:
        return 'Ofis / Ticari';
      case BuildingType.schoolResidence:
        return 'Okul Yurdu';
      case BuildingType.assistedLivingFacility:
        return 'Bakım Evi';
      case BuildingType.homelessTransient:
        return 'Geçici Barınma';
      case BuildingType.other:
        return 'Diğer';
    }
  }
}

