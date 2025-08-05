import 'dart:convert';
import 'package:http/http.dart' as http;
import 'Package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  static Future<String> getBaseUrl() async {
    if (kIsWeb) {
      // Web: localhost
      return 'http://localhost:4000/api';
    } else if (Platform.isAndroid) {
      // Android emulator or device
      final isEmulator = await _isAndroidEmulator();
      if (isEmulator) {
        return 'http://10.0.2.2:4000/api';
      } else {
        // Replace with your PC's IP (serve from PC accessible in LAN)
        return 'http://192.168.1.10:4000/api'; // <- Update to your actual IP
      }
    } else if (Platform.isIOS) {
      // iOS simulator or device
      return 'http://localhost:4000/api'; // Use localhost for iOS simulator
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static Future<bool> _isAndroidEmulator() async {
    try {
      final result = await Process.run('getprop', ['ro.kernel.qemu']);
      return result.stdout.toString().trim() == '1';
    } catch (_) {
      return false;
    }
  }

  // Login request
  static Future<Map<String, dynamic>> login({
    required String enrollmentNumber,
    required String password,
    required String role,
  }) async {
    final baseUrl = await getBaseUrl();
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
    final baseUrl = await getBaseUrl();
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
