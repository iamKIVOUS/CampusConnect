import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../../models/chat/conversation_model.dart';
import '../../models/chat/message_model.dart';
import '../../models/chat/user_model.dart';
import '../../models/chat/message_status.dart';
import '../../services/api_client.dart';
import '../../services/chat/chat_api_service.dart';
import '../../services/chat/chat_socket_service.dart';
import './conversation_provider.dart';

class ChatProvider with ChangeNotifier {
  final ChatApiService _apiService = ChatApiService();
  final ChatSocketService _socketService = ChatSocketService.instance;
  final ConversationProvider _conversationProvider;

  StreamSubscription<Message?>? _messageSubscription;
  StreamSubscription<Conversation>? _conversationUpdateSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStatusUpdateSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;

  bool _isInitialized = false;

  Conversation _conversation;
  Conversation get conversation => _conversation;

  List<Message> _messages = [];
  UnmodifiableListView<Message> get messages => UnmodifiableListView(_messages);

  final Set<ChatUser> _typingUsers = {};
  UnmodifiableSetView<ChatUser> get typingUsers =>
      UnmodifiableSetView(_typingUsers);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMoreMessages = true;
  int? _cursor;

  String? _error;
  String? get error => _error;

  final ChatUser currentUser;

  ChatProvider({
    required Conversation initialConversation,
    required this.currentUser,
    // --- FIX: Require ConversationProvider in the constructor ---
    required ConversationProvider conversationProvider,
  }) : _conversation = initialConversation,
       _conversationProvider = conversationProvider {
    _initialize();
  }

  void _initialize() {
    if (_conversation.id != 'new_direct_chat') {
      _fetchInitialMessages();
      _listenToUpdates();
      _socketService.joinConversation(_conversation.id);
      _isInitialized = true;
    }
  }

  Future<void> _fetchInitialMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _apiService.getMessages(_conversation.id);
      _messages = result['messages'] as List<Message>;
      _cursor = result['nextCursor'] as int?;
      _hasMoreMessages = _cursor != null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToUpdates() {
    _messageSubscription = _socketService.messageStream.listen((newMessage) {
      if (newMessage == null || newMessage.conversationId != _conversation.id) {
        return;
      }

      final index = _messages.indexWhere(
        (m) => m.clientMsgId != null && m.clientMsgId == newMessage.clientMsgId,
      );
      if (index != -1) {
        _messages[index] = newMessage;
      } else if (!_messages.any((m) => m.id == newMessage.id)) {
        _messages.insert(0, newMessage);
      }

      // --- DEFINITIVE FIX: Instant Read Receipts ---
      // This is the correct logic. If a message arrives that isn't from us,
      // and we are on this screen, we immediately tell the server we've read it.
      if (newMessage.sender?.enrollmentNumber != currentUser.enrollmentNumber) {
        markMessagesAsRead();
      }

      notifyListeners();
    });

    _messageStatusUpdateSubscription = _socketService.messageStatusUpdateStream
        .listen((update) {
          if (update['conversationId'] == _conversation.id) {
            final newStatus = MessageStatus.values.firstWhere(
              (e) => e.name == update['status'],
              orElse: () => MessageStatus.sent,
            );
            final messageIds = List<int>.from(
              (update['messageIds'] ?? [update['messageId']]).map(
                (id) => int.parse(id.toString()),
              ),
            );
            bool wasUpdated = false;
            for (final messageId in messageIds) {
              final index = _messages.indexWhere((m) => m.id == messageId);
              if (index != -1 &&
                  _messages[index].status.index < newStatus.index) {
                _messages[index] = _messages[index].copyWith(status: newStatus);
                wasUpdated = true;
              }
            }
            if (wasUpdated) notifyListeners();
          }
        });

    _typingSubscription = _socketService.typingStream.listen((event) {
      final data = event['data'];
      if (data['conversationId'] == _conversation.id) {
        final user = ChatUser.fromJson(data['user'] as Map<String, dynamic>);
        if (event['status'] == 'start') {
          _typingUsers.add(user);
        } else {
          _typingUsers.remove(user);
        }
        notifyListeners();
      }
    });

    _conversationUpdateSubscription = _socketService.conversationUpdateStream
        .listen((updatedConversation) {
          if (updatedConversation.id == _conversation.id) {
            _conversation = updatedConversation;
            notifyListeners();
          }
        });
  }

  Future<void> fetchMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _cursor == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final result = await _apiService.getMessages(
        _conversation.id,
        cursor: _cursor,
      );
      _messages.addAll(result['messages'] as List<Message>);
      _cursor = result['nextCursor'] as int?;
      _hasMoreMessages = _cursor != null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    String body, {
    bool isNewConversation = false,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return;

    if (isNewConversation) {
      _isLoading = true;
      notifyListeners();
      try {
        final newConv = await _apiService.createConversation(
          type: 'direct',
          memberIds: _conversation.members
              .map((u) => u.enrollmentNumber)
              .where((id) => id != currentUser.enrollmentNumber)
              .toList(),
        );
        _conversation = newConv;
        _conversationProvider.addOrUpdateConversation(newConv);
        if (!_isInitialized) {
          _listenToUpdates();
          _socketService.joinConversation(_conversation.id);
          _isInitialized = true;
        }
      } on ApiException catch (e) {
        _error = e.message;
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    _isLoading = false;
    final clientMsgId = 'client_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: _conversation.id,
      sender: currentUser,
      body: trimmedBody,
      createdAt: DateTime.now(),
      type: 'user',
      clientMsgId: clientMsgId,
      status: MessageStatus.sending,
    );
    _messages.insert(0, optimisticMessage);
    notifyListeners();

    final ack = await _socketService.sendMessage(
      body: trimmedBody,
      conversationId: _conversation.id,
      clientMsgId: clientMsgId,
    );

    if (!ack.success) {
      final index = _messages.indexWhere((m) => m.clientMsgId == clientMsgId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.failed,
        );
        notifyListeners();
      }
    }
  }

  Future<void> retrySendMessage(String clientMsgId) async {
    final index = _messages.indexWhere((m) => m.clientMsgId == clientMsgId);
    if (index == -1 || _messages[index].body == null) return;

    final messageToRetry = _messages[index];
    _messages[index] = messageToRetry.copyWith(status: MessageStatus.sending);
    notifyListeners();

    final ack = await _socketService.sendMessage(
      body: messageToRetry.body!,
      conversationId: messageToRetry.conversationId,
      clientMsgId: clientMsgId,
    );

    if (!ack.success) {
      _messages[index] = messageToRetry.copyWith(status: MessageStatus.failed);
      notifyListeners();
    }
  }

  void markMessagesAsRead() {
    if (_conversation.id != 'new_direct_chat') {
      _socketService.markMessagesAsRead(conversationId: _conversation.id);
    }
  }

  Future<void> _executeGroupAction(
    Future<Conversation> Function() action,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      _conversation = await action();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEmptyConversation(String conversationId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.deleteEmptyConversation(conversationId);
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMembers(List<String> memberIds) => _executeGroupAction(
    () => _apiService.addMembersToGroup(_conversation.id, memberIds),
  );

  Future<void> removeMember(String memberId) => _executeGroupAction(
    () => _apiService.removeMemberFromGroup(_conversation.id, memberId),
  );

  Future<void> updateUserRole(String memberId, String newRole) =>
      _executeGroupAction(
        () => _apiService.updateUserRoleInGroup(
          _conversation.id,
          memberId,
          newRole,
        ),
      );

  Future<void> updateGroupDetails(Map<String, dynamic> details) =>
      _executeGroupAction(
        () => _apiService.updateGroupDetails(_conversation.id, details),
      );

  Future<void> leaveGroup() =>
      _executeGroupAction(() => _apiService.leaveGroup(_conversation.id));

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _conversationUpdateSubscription?.cancel();
    _messageStatusUpdateSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }
}
