import '../network/api_client.dart';
import '../network/api_config.dart';
import '../../models/backend_gateway.dart';

class GatewayRepository {
  final _apiClient = ApiClient();

  Future<List<BackendGateway>> fetchUserGateways() async {
    final response = await _apiClient.get(ApiConfig.userGateways);
    final list = response.data as List<dynamic>? ?? [];
    return list.map((e) => BackendGateway.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BackendGateway> createGateway(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConfig.gateways, data: data);
    return BackendGateway.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> addCitizen(String gatewayId, Map<String, dynamic> citizenData) async {
    await _apiClient.post(ApiConfig.gatewayCitizens(gatewayId), data: citizenData);
  }

  Future<void> removeCitizen(String gatewayId, String personId) async {
    await _apiClient.delete(ApiConfig.removeCitizen(gatewayId, personId));
  }

  Future<void> addPet(String gatewayId, Map<String, dynamic> petData) async {
    await _apiClient.post(ApiConfig.gatewayPets(gatewayId), data: petData);
  }

  Future<void> removePet(String gatewayId, String petId) async {
    await _apiClient.delete(ApiConfig.removePet(gatewayId, petId));
  }
}
