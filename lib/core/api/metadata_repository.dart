import '../network/api_client.dart';
import '../network/api_config.dart';
import '../../models/system_options.dart';

class MetadataRepository {
  final _apiClient = ApiClient();
  SystemOptions? _cachedOptions;

  Future<SystemOptions> fetchSystemOptions() async {
    if (_cachedOptions != null) return _cachedOptions!;

    try {
      final response = await _apiClient.get(ApiConfig.systemOptions);
      _cachedOptions = SystemOptions.fromJson(response.data as Map<String, dynamic>);
      return _cachedOptions!;
    } catch (e) {
      return SystemOptions.defaults();
    }
  }

  void clearCache() {
    _cachedOptions = null;
  }
}
