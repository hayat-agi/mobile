class ApiConfig {
  // Backend API base URL.
  //
  // Override at build/run time with --dart-define=API_BASE_URL=https://...
  // Examples:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:5000/api
  //   flutter build apk --dart-define=API_BASE_URL=https://api.hayatagi.com/api
  //
  // The default points at a local-LAN dev backend so a freshly-cloned repo
  // boots without env wiring; override per machine when your IP differs.
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.10:5000/api',
  );

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
