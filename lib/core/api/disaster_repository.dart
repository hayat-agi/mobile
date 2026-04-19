import '../network/api_client.dart';
import '../network/api_config.dart';

class DisasterRepository {
  final _apiClient = ApiClient();

  Future<void> reportDisasterEvent(
    String gatewayId,
    Map<String, dynamic> eventData,
  ) async {
    await _apiClient.post(ApiConfig.gatewayDisasterEvents(gatewayId), data: eventData);
  }

  Future<void> updateGatewayStats(
    String gatewayId, {
    int? deviceCount,
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    final body = <String, dynamic>{};
    if (deviceCount != null) body['deviceCount'] = deviceCount;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (locationAddress != null) body['locationAddress'] = locationAddress;
    if (body.isEmpty) return;
    await _apiClient.patch(ApiConfig.updateGateway(gatewayId), data: body);
  }
}
