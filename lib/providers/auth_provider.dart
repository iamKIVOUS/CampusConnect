import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;
  String? _photoPath;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get photoPath => _photoPath;

  /// Load cached user/token/routine from secure storage + SharedPreferences.
  /// Uses ApiService.instance.getStoredToken() to read the JWT from secure storage.
  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Token is stored in secure storage by ApiService; read it from there
      final storedToken = await ApiService.instance.getStoredToken();

      final userData = prefs.getString('user');
      final photoPath = prefs.getString('photoPath');

      _token = storedToken;
      if (userData != null) {
        try {
          _user = jsonDecode(userData) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error decoding saved user JSON: $e');
          _user = null;
        }
      } else {
        _user = null;
      }
      _photoPath = photoPath;

      // Consider the user logged in if a token exists (even if cached user is missing).
      _isLoggedIn = (_token != null);

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  /// Login using the ApiService. On success, ApiService stores the token in secure storage.
  Future<bool> login(String enrollment, String password, String role) async {
    try {
      final response = await ApiService.instance.login(
        enrollmentNumber: enrollment,
        password: password,
        role: role,
      );

      // Expected shape: { "token": "...", "user": { ... } }
      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;

      if (token == null || user == null) {
        debugPrint('Login response missing token or user');
        return false;
      }

      // Optionally download profile photo (non-blocking for login)
      String? savedPhotoPath;
      final photoUrl =
          user['photo_url'] as String? ?? user['photoUrl'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final savedPath = await _downloadAndSavePhoto(
            photoUrl,
            user['enrollment_number']?.toString() ?? enrollment,
          );
          savedPhotoPath = savedPath;
        } catch (e) {
          debugPrint('Failed to download profile photo: $e');
        }
      }

      // Persist non-sensitive parts in SharedPreferences (token is stored securely by ApiService)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(user));
      if (savedPhotoPath != null) {
        await prefs.setString('photoPath', savedPhotoPath);
      } else {
        await prefs.remove('photoPath');
      }

      // Update provider state
      _token = token;
      _user = user;

      _photoPath = savedPhotoPath;
      _isLoggedIn = true;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      return false;
    }
  }

  /// Download profile photo and store it in application documents directory
  Future<String> _downloadAndSavePhoto(
    String url,
    String filenamePrefix,
  ) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final safePrefix = filenamePrefix.replaceAll(
        RegExp(r'[^A-Za-z0-9_\-]'),
        '_',
      );
      final filePath = '${dir.path}/$safePrefix-profile.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception(
        'Failed to download image (status ${response.statusCode})',
      );
    }
  }

  /// Logout - call API to invalidate token and clear local caches
  Future<void> logout() async {
    try {
      await ApiService.instance.logout();
    } catch (e) {
      debugPrint('Logout API failed: $e');
      // proceed to clear local state anyway
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('photoPath');

    _isLoggedIn = false;
    _token = null;
    _user = null;
    _photoPath = null;

    notifyListeners();
  }
}
