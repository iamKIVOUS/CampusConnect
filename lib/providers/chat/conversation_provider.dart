import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../auth_provider.dart';
import '../../models/chat/conversation_model.dart';
import '../../models/chat/message_model.dart';
import '../../models/chat/message_status.dart';
import '../../services/api_client.dart';
import '../../services/chat/chat_api_service.dart';
import '../../services/chat/chat_socket_service.dart';

class ConversationProvider with ChangeNotifier {
  final ChatApiService _chatApiService = ChatApiService();
  final ChatSocketService _socketService = ChatSocketService.instance;
  AuthProvider _authProvider;

  StreamSubscription<Conversation>? _conversationUpdateSubscription;
  StreamSubscription<Message?>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStatusUpdateSubscription;

  List<Conversation> _conversations = [];
  List<Conversation> _searchResults = [];

  UnmodifiableListView<Conversation> get conversations =>
      UnmodifiableListView(_conversations);
  UnmodifiableListView<Conversation> get searchResults =>
      UnmodifiableListView(_searchResults);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _currentUserId;

  ConversationProvider({required AuthProvider authProvider})
    : _authProvider = authProvider {
    if (_authProvider.isLoggedIn) {
      _initializeUser(_authProvider.user?['enrollment_number']);
    }
  }

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
    final newUserId = _authProvider.user?['enrollment_number'];

    if (_authProvider.isLoggedIn && newUserId != _currentUserId) {
      _initializeUser(newUserId);
    } else if (!_authProvider.isLoggedIn && _currentUserId != null) {
      _clearUserData();
    }
  }

  void _initializeUser(String? userId) {
    if (userId == null || userId.isEmpty) return;
    _currentUserId = userId;
    _listenToUpdates();
    fetchConversations();
  }

  void _clearUserData() {
    _cancelSubscriptions();
    _currentUserId = null;
    _conversations = [];
    _searchResults = [];
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _conversationUpdateSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageStatusUpdateSubscription?.cancel();
  }

  Future<void> fetchConversations() async {
    if (_currentUserId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await _chatApiService.getMyConversations();
      _sortConversations();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversations() async => await fetchConversations();

  void addOrUpdateConversation(Conversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
    } else {
      _conversations.add(conversation);
    }
    _sortConversations();
    notifyListeners();
  }

  void removeConversation(String conversationId) {
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  void _listenToUpdates() {
    // --- DEFINITIVE FIX ---
    // This is now the ONLY listener responsible for adding or updating conversations.
    _conversationUpdateSubscription = _socketService.conversationUpdateStream
        .listen((updatedConversation) {
          addOrUpdateConversation(updatedConversation);
        });

    // --- DEFINITIVE FIX ---
    // The message subscription is now drastically simplified. It has one job:
    // if it sees a message for a conversation it doesn't know about, it asks
    // the server for the full details. That's it. This prevents all race conditions.
    _messageSubscription = _socketService.messageStream.listen((newMessage) {
      if (newMessage == null) return;
      final index = _conversations.indexWhere(
        (c) => c.id == newMessage.conversationId,
      );
      if (index == -1) {
        _fetchAndAddConversation(newMessage.conversationId);
      }
    });

    _messageStatusUpdateSubscription ??= _socketService
        .messageStatusUpdateStream
        .listen((update) {
          final conversationId = update['conversationId'];
          final messageIdsDynamic =
              update['messageIds'] ?? [update['messageId']];
          final messageIds = (messageIdsDynamic as List)
              .map((id) => id is int ? id : int.parse(id.toString()))
              .toList();

          if (messageIds.isEmpty) return;

          final statusString = update['status'] as String?;
          final newStatus = statusString == 'read'
              ? MessageStatus.read
              : MessageStatus.delivered;

          final index = _conversations.indexWhere(
            (c) => c.id == conversationId,
          );
          if (index != -1) {
            final conversation = _conversations[index];
            final lastMessage = conversation.lastMessage;
            if (lastMessage != null &&
                messageIds.contains(lastMessage.id) &&
                newStatus.index > lastMessage.status.index) {
              _conversations[index] = conversation.copyWith(
                lastMessage: lastMessage.copyWith(status: newStatus),
              );
              notifyListeners();
            }
          }
        });
  }

  Future<void> _fetchAndAddConversation(String conversationId) async {
    if (_conversations.any((c) => c.id == conversationId)) return;
    try {
      final conversation = await _chatApiService.getConversationById(
        conversationId,
      );
      addOrUpdateConversation(conversation);
    } catch (e) {
      debugPrint("Failed to fetch new conversation $conversationId: $e");
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      final aDate = a.lastMessage?.createdAt ?? DateTime(2000);
      final bDate = b.lastMessage?.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }

  @override
  void dispose() {
    _conversationUpdateSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageStatusUpdateSubscription?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }

  // All other methods (search, clearSearch) remain the same.
  Future<void> searchConversationsAndMessages(String query) async {
    if (_currentUserId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final messages = await _chatApiService.searchMessages(query);
      final conversationIds = messages.map((m) => m.conversationId).toSet();
      _searchResults = _conversations
          .where((c) => conversationIds.contains(c.id))
          .toList();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    if (_searchResults.isNotEmpty) {
      _searchResults = [];
      notifyListeners();
    }
  }
}
