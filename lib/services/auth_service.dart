// lib/services/auth_service.dart
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> login({
    required String enrollmentNumber,
    required String password,
    required String role,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'enrollment_number': enrollmentNumber,
        'password': password,
        'role': role,
      },
    );
    if (response['token'] != null) {
      await _apiClient.saveToken(response['token']);
    }
    return response;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } finally {
      await _apiClient.deleteToken(); // Always clear the token locally
    }
  }
}
