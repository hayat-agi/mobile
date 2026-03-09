import '../network/api_client.dart';
import '../network/api_config.dart';
import '../../models/user.dart';

class UserRepository {
  final _apiClient = ApiClient();

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiClient.put(ApiConfig.userProfile, data: data);
    final userData = response.data is Map<String, dynamic>
        ? (response.data['user'] as Map<String, dynamic>? ?? response.data)
        : response.data;
    return User.fromJson(userData as Map<String, dynamic>);
  }
}
