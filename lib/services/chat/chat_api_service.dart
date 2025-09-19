import '../api_client.dart';
import '../../models/chat/conversation_model.dart';
import '../../models/chat/message_model.dart';
import '../../models/chat/user_model.dart';

/// A service class dedicated to handling all chat-related REST API requests.
class ChatApiService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<List<Conversation>> getMyConversations() async {
    try {
      final response = await _apiClient.get('/protected/chat/conversations');
      final List<dynamic> conversationListJson = response['data'];
      return conversationListJson
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to fetch conversations: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> getConversationById(String conversationId) async {
    try {
      final response = await _apiClient.get(
        '/protected/chat/conversations/$conversationId',
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to fetch conversation details: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int? cursor,
  }) async {
    try {
      String endpoint =
          '/protected/chat/conversations/$conversationId/messages?limit=30';
      if (cursor != null) {
        endpoint += '&cursor=$cursor';
      }
      final response = await _apiClient.get(endpoint);
      final List<dynamic> messageListJson = response['messages'];

      // --- FIX ---
      // After mapping, we filter out any potential nulls that result from
      // parsing errors, ensuring a clean list of non-nullable Messages.
      final messages = messageListJson
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .whereType<
            Message
          >() // This filters out nulls and ensures type safety.
          .toList();

      final nextCursor = response['pagination']['nextCursor'];
      return {'messages': messages, 'nextCursor': nextCursor};
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to fetch messages: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<List<Message>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _apiClient.get(
        '/protected/chat/search?q=${Uri.encodeComponent(query)}',
      );
      final List<dynamic> messageListJson = response['data']['messages'];

      // --- FIX ---
      // We apply the same logic here to filter out any nulls from the mapped list,
      // which resolves the type mismatch error.
      return messageListJson
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .whereType<
            Message
          >() // This filters out nulls and ensures type safety.
          .toList();
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to search messages: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  // ... The rest of the file (searchUsers, createConversation, etc.) remains exactly the same ...
  Future<List<ChatUser>> searchUsers(String query) async {
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
        'Failed to search users: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> createConversation({
    required String type,
    required List<String> memberIds,
    String? title,
    String? joinPolicy,
    String? messagingPolicy,
  }) async {
    try {
      final body = {
        'type': type,
        'memberIds': memberIds,
        'title': title,
        'joinPolicy': joinPolicy,
        'messagingPolicy': messagingPolicy,
      };
      body.removeWhere((key, value) => value == null);
      final response = await _apiClient.post(
        '/protected/chat/conversations',
        body: body,
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to create conversation: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    try {
      await _apiClient.post(
        '/protected/chat/conversations/$conversationId/archive',
      );
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to archive conversation: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<void> unarchiveConversation(String conversationId) async {
    try {
      await _apiClient.delete(
        '/protected/chat/conversations/$conversationId/archive',
      );
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to un-archive conversation: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  /// --- FIX ---
  /// New function to delete an empty conversation.
  Future<void> deleteEmptyConversation(String conversationId) async {
    try {
      await _apiClient.delete('/protected/chat/conversations/$conversationId');
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to delete conversation: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> updateGroupDetails(
    String conversationId,
    Map<String, dynamic> details,
  ) async {
    try {
      final response = await _apiClient.patch(
        '/protected/chat/conversations/$conversationId',
        body: details,
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to update group details: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> addMembersToGroup(
    String conversationId,
    List<String> memberIds,
  ) async {
    try {
      final response = await _apiClient.post(
        '/protected/chat/conversations/$conversationId/members',
        body: {'memberIds': memberIds},
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to add members: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> removeMemberFromGroup(
    String conversationId,
    String memberToRemoveId,
  ) async {
    try {
      final response = await _apiClient.delete(
        '/protected/chat/conversations/$conversationId/members/$memberToRemoveId',
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to remove member: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> updateUserRoleInGroup(
    String conversationId,
    String targetUserId,
    String newRole,
  ) async {
    try {
      final response = await _apiClient.patch(
        '/protected/chat/conversations/$conversationId/members/$targetUserId/role',
        body: {'role': newRole},
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to update role: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  Future<Conversation> leaveGroup(String conversationId) async {
    try {
      final response = await _apiClient.post(
        '/protected/chat/conversations/$conversationId/leave',
      );
      return Conversation.fromJson(response['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw ApiException(
        'Failed to leave group: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }
}
