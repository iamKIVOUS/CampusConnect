import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/chat/chat_socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient.instance;
  final ChatSocketService _socketService = ChatSocketService.instance;

  bool _isLoggedIn = false;
  bool _wasLoggedIn = false;
  Map<String, dynamic>? _user;
  String? _token;
  String? _photoPath;

  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  String? get photoPath => _photoPath;

  // --- DEFINITIVE FIX: The provider listens to its own state changes ---
  AuthProvider() {
    // This listener is now the central authority for managing the socket lifecycle.
    addListener(_handleAuthStateChanged);
  }

  /// This private method is the ONLY place that manages the socket connection.
  /// It runs every time `notifyListeners()` is called.
  void _handleAuthStateChanged() {
    if (_wasLoggedIn != _isLoggedIn) {
      if (_isLoggedIn && _token != null) {
        // State changed from logged OUT to logged IN: connect the socket.
        debugPrint("Auth state changed to LOGGED IN. Connecting socket...");
        _socketService.connectAndListen(token: _token!);
      } else if (!_isLoggedIn) {
        // State changed from logged IN to logged OUT: disconnect the socket.
        debugPrint("Auth state changed to LOGGED OUT. Disconnecting socket...");
        _socketService.disconnect();
      }
      _wasLoggedIn = _isLoggedIn;
    }
  }

  @override
  void dispose() {
    removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  Future<void> loadUserData() async {
    final storedToken = await _apiClient.getToken();
    if (storedToken != null) {
      _token = storedToken;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user');
      if (userData != null) {
        _user = jsonDecode(userData);
      }
      _photoPath = prefs.getString('photoPath');
    }
    // We notify listeners here. The _handleAuthStateChanged listener will
    // be triggered automatically and connect the socket if necessary.
    notifyListeners();
  }

  Future<bool> login(String enrollment, String password, String role) async {
    try {
      final response = await _authService.login(
        enrollmentNumber: enrollment,
        password: password,
        role: role,
      );

      _user = response['user'];
      _token = response['token'];
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_user));

      final photoUrl = _user?['photo_url'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        _photoPath = await _downloadAndSavePhoto(photoUrl, enrollment);
        await prefs.setString('photoPath', _photoPath!);
      } else {
        _photoPath = null;
        await prefs.remove('photoPath');
      }

      // We ONLY notify listeners. Our _handleAuthStateChanged method will
      // be triggered automatically and will handle the socket connection.
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // It's still good practice to inform the backend of the logout.
      await _authService.logout();
    } catch (e) {
      debugPrint('Logout API call failed: $e');
    }

    _isLoggedIn = false;
    _user = null;
    _token = null;
    _photoPath = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _apiClient.deleteToken(); // Explicitly delete from secure storage

    // The listener will automatically call _socketService.disconnect()
    // because the login state has changed from true to false.
    notifyListeners();
  }

  Future<String> _downloadAndSavePhoto(
    String url,
    String filenamePrefix,
  ) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final safePrefix = filenamePrefix.replaceAll(
          RegExp(r'[^A-Za-z0-9_\-]'),
          '_',
        );
        final filePath = '${directory.path}/$safePrefix-profile.jpg';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error downloading photo: $e");
      rethrow;
    }
  }
}
