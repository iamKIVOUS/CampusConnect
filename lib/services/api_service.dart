import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exception class for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  static const _storage = FlutterSecureStorage();

  // Token keys for secure storage
  static const String _tokenKey = 'auth_token';

  /// Save token securely
  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieve token securely
  Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Public getter for token (if other parts need it)
  Future<String?> getStoredToken() => _getToken();

  /// Delete token from storage
  Future<void> _deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Base URL configuration depending on platform
  Future<String> _baseUri() async {
    const int port = 4000; // Change if needed

    // Note: baseUri returns a string that already includes '/api' suffix.
    if (kIsWeb) {
      return 'http://localhost:$port/api';
    }
    if (Platform.isAndroid) {
      // For production, you would use a real domain.
      // For development, 10.0.2.2 maps to the host machine's localhost.
      return 'http://10.0.2.2:$port/api';
    }
    if (Platform.isIOS) {
      // iOS simulator can use localhost directly
      return 'http://localhost:$port/api';
    }
    // Default for desktop platforms
    return 'http://localhost:$port/api';
  }

  /// Universal request handler with error handling
  Future<http.Response> _request(
    Future<http.Response> Function() requestFn,
  ) async {
    try {
      final response = await requestFn().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw ApiException('Request timed out'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      // Try to parse a JSON error message from the body
      String errorMessage = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map && parsed['message'] != null) {
          errorMessage = parsed['message'];
        }
      } catch (_) {
        // Ignore JSON parsing errors, use the raw body
      }

      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on SocketException {
      throw ApiException('No internet connection or server not reachable.');
    } on ApiException {
      rethrow; // Re-throw exceptions we've already handled
    } catch (e) {
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Build standard headers (includes Authorization if token available)
  Future<Map<String, String>> _defaultHeaders() async {
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Login API
  Future<Map<String, dynamic>> login({
    required String enrollmentNumber,
    required String password,
    required String role,
  }) async {
    final baseUrl = await _baseUri();
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await _request(() {
      return http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'enrollment_number': enrollmentNumber,
          'password': password,
          'role': role,
        }),
      );
    });

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['token'] != null && data['token'] is String) {
      await _saveToken(data['token'] as String);
    }
    return data;
  }

  /// Logout API
  Future<void> logout() async {
    final token = await _getToken();
    if (token == null) return; // No token, nothing to do

    final baseUrl = await _baseUri();
    final url = Uri.parse('$baseUrl/auth/logout');

    try {
      await _request(() {
        return http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      });
    } catch (e) {
      // Log error but don't prevent local token deletion
      debugPrint(
        "Logout API call failed, but proceeding with local logout: $e",
      );
    }

    await _deleteToken();
  }

  /// Fetch routine (protected endpoint)
  Future<List<dynamic>> fetchRoutine() async {
    final baseUrl = await _baseUri();
    final url = Uri.parse('$baseUrl/protected/routine');

    final headers = await _defaultHeaders();
    final response = await _request(() => http.get(url, headers: headers));

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (data.containsKey('routine') && data['routine'] is List) {
      return data['routine'] as List<dynamic>;
    }
    return [];
  }

  /// Fetch class list for attendance
  Future<List<dynamic>> getClassList({
    required String course,
    required String stream,
    required int year,
    required String section,
  }) async {
    final baseUrl = await _baseUri();
    final uri = Uri.parse(
      '$baseUrl/protected/attendance/class-list'
      '?course=${Uri.encodeComponent(course)}'
      '&stream=${Uri.encodeComponent(stream)}'
      '&year=${Uri.encodeComponent(year.toString())}'
      '&section=${Uri.encodeComponent(section)}',
    );

    final headers = await _defaultHeaders();
    final response = await _request(() => http.get(uri, headers: headers));

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (data.containsKey('students') && data['students'] is List) {
      return data['students'] as List<dynamic>;
    }
    return [];
  }

  /// Submit attendance
  Future<Map<String, dynamic>> submitAttendance(
    Map<String, dynamic> attendanceData,
  ) async {
    final baseUrl = await _baseUri();
    final url = Uri.parse('$baseUrl/protected/attendance/submit');

    final headers = await _defaultHeaders();
    final response = await _request(() {
      // CORRECTED: Was http.get, now it's http.post
      return http.post(url, headers: headers, body: jsonEncode(attendanceData));
    });

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetch attendance summary (protected endpoint)
  Future<List<dynamic>> fetchAttendanceSummary() async {
    final baseUrl = await _baseUri();
    final url = Uri.parse('$baseUrl/protected/attendance');

    final headers = await _defaultHeaders();
    final response = await _request(() => http.get(url, headers: headers));

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (data.containsKey('summary') && data['summary'] is List) {
      return data['summary'] as List<dynamic>;
    }
    return [];
  }
}
