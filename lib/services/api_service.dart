import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:4000/api';

  // Login request
  static Future<Map<String, dynamic>> login({
    required String enrollmentNumber,
    required String password,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'enrollment_number': enrollmentNumber,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Invalid enrollment, password, or role.');
    } else {
      throw Exception('Login failed. Status: ${response.statusCode}');
    }
  }

  // Future logout API if needed in production
  static Future<void> logout(String token) async {
    final url = Uri.parse('$baseUrl/auth/logout');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Logout failed.');
    }
  }
}
