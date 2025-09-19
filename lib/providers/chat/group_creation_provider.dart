import 'dart:collection';
import 'package:campus_connect/services/api_client.dart';
import 'package:flutter/foundation.dart';
import '../../models/chat/conversation_model.dart';
import '../../models/chat/user_model.dart';
import '../../services/chat/chat_api_service.dart';

/// Manages the UI state for the multi-step group creation process.
///
/// This provider's sole responsibility is to manage the temporary list of users
/// selected for a new group and to handle the final API call to create that group.
class GroupCreationProvider with ChangeNotifier {
  final ChatApiService _apiService = ChatApiService();
  final Set<ChatUser> _selectedUsers = {};

  // --- State Variables ---
  bool _isLoading = false;
  String? _error;

  // --- Public Getters ---
  UnmodifiableListView<ChatUser> get selectedUsers =>
      UnmodifiableListView(_selectedUsers.toList());
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Adds a user to the selection list.
  void addUser(ChatUser user) {
    final wasAdded = _selectedUsers.add(user);
    if (wasAdded) {
      notifyListeners();
    }
  }

  /// Removes a user from the selection list.
  void removeUser(ChatUser user) {
    final wasRemoved = _selectedUsers.remove(user);
    if (wasRemoved) {
      notifyListeners();
    }
  }

  /// Clears the selection list, resetting the state.
  void clear() {
    if (_selectedUsers.isNotEmpty) {
      _selectedUsers.clear();
      notifyListeners();
    }
  }

  /// Calls the API to create a new group with the selected users and details.
  Future<Conversation?> createGroup({
    required String title,
    String? joinPolicy,
    String? messagingPolicy,
  }) async {
    if (title.trim().isEmpty) {
      _error = 'Group name cannot be empty.';
      notifyListeners();
      return null;
    }
    if (_selectedUsers.isEmpty) {
      _error = 'Please select at least one member.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final memberIds = _selectedUsers.map((u) => u.enrollmentNumber).toList();

      final newConversation = await _apiService.createConversation(
        memberIds: memberIds,
        type: 'group',
        title: title,
        joinPolicy: joinPolicy,
        messagingPolicy: messagingPolicy,
      );

      // Clear the state on success before returning
      clear();
      return newConversation;
    } on ApiException catch (e) {
      _error = "Failed to create group: ${e.message}";
      return null;
    } catch (e) {
      _error = "An unexpected error occurred.";
      return null;
    } finally {
      _isLoading = false;
      // This final notifyListeners updates the UI to hide the loading indicator
      // and show a potential error message.
      notifyListeners();
    }
  }
}
