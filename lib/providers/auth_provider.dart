import 'dart:convert';
import 'dart:io';
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

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userData = prefs.getString('user');
    final photoPath = prefs.getString('photoPath');

    if (token != null && userData != null) {
      _token = token;
      _user = jsonDecode(userData);
      _photoPath = photoPath;
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<bool> login(String enrollment, String password, String role) async {
    try {
      final response = await ApiService.login(
        enrollmentNumber: enrollment,
        password: password,
        role: role,
      );

      final user = response['user'];
      final token = response['token'];

      // Save profile photo locally if photo_url exists
      String? photoUrl = user['photo_url'];
      String? savedPhotoPath;

      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final savedPath = await _downloadAndSavePhoto(
            photoUrl,
            user['enrollment_number'],
          );
          savedPhotoPath = savedPath;
        } catch (e) {
          debugPrint('Failed to download profile photo: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(user));
      if (savedPhotoPath != null) {
        await prefs.setString('photoPath', savedPhotoPath);
      }

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

  Future<String> _downloadAndSavePhoto(
    String url,
    String filenamePrefix,
  ) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$filenamePrefix-profile.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception('Failed to download image');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await ApiService.logout(prefs.getString('token') ?? '');
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('photoPath');

    _isLoggedIn = false;
    _token = null;
    _user = null;
    _photoPath = null;

    notifyListeners();
  }
}
