// lib/services/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A custom exception class to handle API-related errors uniformly.
/// It includes the error message and the HTTP status code.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

/// A singleton class that handles all HTTP requests for the application.
/// It manages token-based authentication, request headers, and centralized
/// error handling for a clean and maintainable service layer.
class ApiClient {
  // --- Singleton Setup ---
  ApiClient._privateConstructor();
  static final ApiClient instance = ApiClient._privateConstructor();

  // --- Dependencies ---
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  // --- Token Management ---

  /// Saves the authentication token securely on the device.
  Future<void> saveToken(String token) async =>
      await _storage.write(key: _tokenKey, value: token);

  /// Retrieves the authentication token from secure storage.
  Future<String?> getToken() async => await _storage.read(key: _tokenKey);

  /// Deletes the authentication token from secure storage (e.g., on logout).
  Future<void> deleteToken() async => await _storage.delete(key: _tokenKey);

  // --- Core Networking ---

  /// Determines the base URI for the API server based on the platform.
  /// Uses '10.0.2.2' for Android emulators to connect to the host machine's localhost.
  Future<String> getBaseUri({bool forApi = true}) async {
    // Use 'final' as kIsWeb is determined at runtime.
    final String host = kIsWeb || Platform.isIOS ? 'localhost' : '10.0.2.2';
    const int port = 4000;
    return forApi ? 'http://$host:$port/api' : 'http://$host:$port';
  }

  /// Constructs the standard headers for API requests, including the
  /// content type and the authorization token if it exists.
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// A generic GET request handler.
  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${await getBaseUri()}$endpoint');
    return _request(() async => http.get(url, headers: await _getHeaders()));
  }

  /// A generic POST request handler.
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${await getBaseUri()}$endpoint');
    return _request(
      () async => http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  /// A generic PUT request handler.
  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${await getBaseUri()}$endpoint');
    return _request(
      () async => http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  /// A generic PATCH request handler.
  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${await getBaseUri()}$endpoint');
    return _request(
      () async => http.patch(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  /// A generic DELETE request handler.
  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('${await getBaseUri()}$endpoint');
    return _request(() async => http.delete(url, headers: await _getHeaders()));
  }

  /// The core request handler that all other methods use.
  /// It wraps the HTTP call in error handling logic.
  Future<dynamic> _request(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn().timeout(const Duration(seconds: 20));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('No internet connection or server not reachable.');
    } on TimeoutException {
      throw ApiException('The request timed out. Please try again.');
    } catch (e) {
      // Rethrow known API exceptions, otherwise wrap in a generic one.
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Processes the HTTP response, parsing the body and handling status codes.
  dynamic _processResponse(http.Response response) {
    // Handle cases where the response body might be empty (e.g., on a 204 No Content).
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': 'Operation successful'};
      } else {
        throw ApiException(
          'Request failed with status code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }

    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      // Use the 'error' or 'message' field from the server's JSON response if available.
      final errorMessage =
          body['error'] ?? body['message'] ?? 'An unknown error occurred';
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}
