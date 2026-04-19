class ApiConfig {
  // Default to local machine IP for dev. Change for production.
  static String baseUrl = 'http://192.168.1.10:5000/api'; // Local machine IP for physical phone

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';

  // User endpoints
  static const String userProfile = '/users/profile';

  // Gateway endpoints
  static const String userGateways = '/gateways/user';
  static const String gateways = '/gateways';
  static String gatewayCitizens(String id) => '/gateways/$id/citizens';
  static String gatewayPets(String id) => '/gateways/$id/pets';
  static String removeCitizen(String gatewayId, String personId) =>
      '/gateways/$gatewayId/citizens/$personId';
  static String removePet(String gatewayId, String petId) =>
      '/gateways/$gatewayId/pets/$petId';
  static String gatewayDisasterEvents(String id) => '/gateways/$id/disaster-events';
  static String updateGateway(String id) => '/gateways/$id';

  // Metadata
  static const String systemOptions = '/metadata/system-options';

  // Issues
  static const String reportIssue = '/issues/report';
}
