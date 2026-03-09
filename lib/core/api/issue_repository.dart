import '../network/api_client.dart';
import '../network/api_config.dart';

class IssueRepository {
  final _apiClient = ApiClient();

  Future<void> reportIssue({
    required String title,
    required String description,
  }) async {
    await _apiClient.post(ApiConfig.reportIssue, data: {
      'title': title,
      'description': description,
    });
  }
}
