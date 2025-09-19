import './api_client.dart';
import '../models/chat/user_model.dart';

/// A service class dedicated to handling all user-related API requests.
///
/// This creates a clean separation of concerns, moving user-related logic
/// out of the chat service.
class UserApiService {
  final ApiClient _apiClient = ApiClient.instance;

  /// Searches for users by name or enrollment number.
  /// Calls `GET /api/protected/users/search`.
  Future<List<ChatUser>> searchUsers(String query) async {
    // Avoid unnecessary API calls for empty queries.
    if (query.trim().isEmpty) return [];

    try {
      final response = await _apiClient.get(
        '/protected/users/search?q=${Uri.encodeComponent(query)}',
      );
      final List<dynamic> userListJson = response['data'];
      return userListJson
          .map((json) => ChatUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to search for users: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  /// Fetches the full public profile for a specific user.
  /// Calls `GET /api/protected/users/:enrollmentNumber`.
  Future<ChatUser> getUserProfile(String enrollmentNumber) async {
    try {
      final response = await _apiClient.get(
        '/protected/users/$enrollmentNumber',
      );
      return ChatUser.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to fetch user profile: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }
}
