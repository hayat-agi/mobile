import 'package:flutter/foundation.dart';
import '../../models/user.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/api_exception.dart';
import 'token_storage.dart';

enum AuthState { unknown, unauthenticated, authenticated }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.unknown);
  final ValueNotifier<User?> currentUser = ValueNotifier(null);

  final _apiClient = ApiClient();
  final _tokenStorage = TokenStorage();

  Future<void> initialize() async {
    try {
      final token = await _tokenStorage.getToken();
      if (token == null) {
        authState.value = AuthState.unauthenticated;
        return;
      }

      final response = await _apiClient.get(ApiConfig.me);
      final userData = response.data is Map<String, dynamic>
          ? response.data
          : response.data['user'];
      currentUser.value = User.fromJson(userData as Map<String, dynamic>);
      authState.value = AuthState.authenticated;
    } on UnauthorizedException {
      await _tokenStorage.deleteToken();
      authState.value = AuthState.unauthenticated;
    } catch (e) {
      // Network error — stay unknown, let app retry
      authState.value = AuthState.unauthenticated;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _apiClient.post(ApiConfig.login, data: {
      'email': email,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    await _tokenStorage.saveToken(token);

    final userData = data['user'] as Map<String, dynamic>?;
    if (userData != null) {
      currentUser.value = User.fromJson(userData);
    } else {
      // Fetch user data separately
      await _fetchCurrentUser();
    }

    authState.value = AuthState.authenticated;
  }

  Future<void> register({
    required String name,
    required String surname,
    required String tcNumber,
    required String email,
    required String password,
  }) async {
    // Register the user (backend returns user data but no token)
    await _apiClient.post(ApiConfig.register, data: {
      'name': name,
      'surname': surname,
      'tcNumber': tcNumber,
      'email': email,
      'password': password,
    });

    // Backend register doesn't return a token, so login immediately after
    await login(email, password);
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
    currentUser.value = null;
    authState.value = AuthState.unauthenticated;
  }

  Future<void> _fetchCurrentUser() async {
    final response = await _apiClient.get(ApiConfig.me);
    final data = response.data;
    final userData = data is Map<String, dynamic>
        ? (data['user'] as Map<String, dynamic>? ?? data)
        : data;
    currentUser.value = User.fromJson(userData as Map<String, dynamic>);
  }

  Future<void> refreshUser() async {
    await _fetchCurrentUser();
  }
}
