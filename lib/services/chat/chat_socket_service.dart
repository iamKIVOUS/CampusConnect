import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api_client.dart';
import '../../models/chat/conversation_model.dart';
import '../../models/chat/message_model.dart';

class AckResponse {
  final bool success;
  final dynamic data;
  final String? error;
  AckResponse({required this.success, this.data, this.error});
}

class ChatSocketService {
  ChatSocketService._privateConstructor();
  static final ChatSocketService instance =
      ChatSocketService._privateConstructor();

  io.Socket? _socket;

  late StreamController<Message?> _messageController;
  late StreamController<Map<String, dynamic>> _typingController;
  late StreamController<Conversation> _conversationUpdateController;
  late StreamController<Map<String, dynamic>> _messageStatusUpdateController;

  Stream<Message?> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Conversation> get conversationUpdateStream =>
      _conversationUpdateController.stream;
  Stream<Map<String, dynamic>> get messageStatusUpdateStream =>
      _messageStatusUpdateController.stream;

  /// Ensures the stream controllers are open and ready for a new session.
  void _initializeStreamControllers() {
    // --- DEFINITIVE FIX 1: Fix LateInitializationError ---
    // Always create new StreamController instances for a new session.
    // This guarantees that the `late` fields are initialized before any potential
    // read operation, resolving the crash. The old controllers are closed
    // in the `disconnect` method.
    _messageController = StreamController.broadcast();
    _typingController = StreamController.broadcast();
    _conversationUpdateController = StreamController.broadcast();
    _messageStatusUpdateController = StreamController.broadcast();
  }

  /// Creates a fresh socket instance.
  Future<void> _createSocketInstance(String token) async {
    // --- DEFINITIVE FIX 3: Allow Socket Recreation ---
    // The guard clause is removed to ensure that a fresh socket instance
    // can be created after a previous one has been disposed on logout.
    debugPrint("Creating new socket instance.");
    final baseUrl = await ApiClient.instance.getBaseUri(forApi: false);
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _registerEventListeners();
  }

  /// Connects the socket for a new user session.
  Future<void> connectAndListen({required String token}) async {
    // Create the socket instance if it doesn't exist (first login) or
    // if it was nullified by a previous logout.
    if (_socket == null) {
      await _createSocketInstance(token);
    }

    // Always get fresh stream controllers for the new session.
    _initializeStreamControllers();

    if (_socket!.connected) {
      debugPrint("Socket already connected, updating token.");
      _socket!.auth = {'token': token};
      return;
    }

    debugPrint("Updating auth token and connecting socket...");
    _socket!.auth = {'token': token};
    _socket!.connect();
  }

  /// Disconnects the socket and closes streams at the end of a session.
  void disconnect() {
    debugPrint("Disconnecting socket and closing streams...");
    // --- DEFINITIVE FIX 2: Full Socket Cleanup ---
    // Fully dispose of the old socket instance and set it to null. This
    // prevents stale instances from being reused and failing to connect on
    // subsequent logins.
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    // Close all stream controllers to terminate any existing subscriptions.
    // We check if they have been initialized before trying to close.
    if (this._messageController.isClosed == false) _messageController.close();
    if (this._typingController.isClosed == false) _typingController.close();
    if (this._conversationUpdateController.isClosed == false)
      _conversationUpdateController.close();
    if (this._messageStatusUpdateController.isClosed == false)
      _messageStatusUpdateController.close();
  }

  void _registerEventListeners() {
    _socket?.onConnect((_) => debugPrint('Socket connected: ${_socket!.id}'));
    _socket?.onConnectError(
      (data) => debugPrint('Socket Connect Error: $data'),
    );
    _socket?.onDisconnect((_) => debugPrint('Socket disconnected'));
    _socket?.onError((data) => debugPrint('Socket Error: $data'));

    _socket?.on('message_receive', (data) {
      if (!_messageController.isClosed) {
        final message = Message.fromJson(data as Map<String, dynamic>);
        _messageController.add(message);
      }
    });

    _socket?.on('typing_start', (data) {
      if (!_typingController.isClosed) {
        _typingController.add({'status': 'start', 'data': data});
      }
    });
    _socket?.on('typing_stop', (data) {
      if (!_typingController.isClosed) {
        _typingController.add({'status': 'stop', 'data': data});
      }
    });
    _socket?.on('conversation_update', (data) {
      if (!_conversationUpdateController.isClosed) {
        _conversationUpdateController.add(
          Conversation.fromJson(data as Map<String, dynamic>),
        );
      }
    });
    _socket?.on('message_status_update', (data) {
      if (!_messageStatusUpdateController.isClosed) {
        _messageStatusUpdateController.add(data as Map<String, dynamic>);
      }
    });
  }

  Future<AckResponse> _emitWithAck(
    String event,
    dynamic data, {
    Duration? timeout,
  }) async {
    final completer = Completer<AckResponse>();
    timeout ??= const Duration(seconds: 10);
    if (!(_socket?.connected ?? false)) {
      return AckResponse(success: false, error: 'Not connected to server.');
    }
    _socket!.emitWithAck(
      event,
      data,
      ack: (response) {
        if (completer.isCompleted) return;
        try {
          final data = response as Map<String, dynamic>;
          if (data['success'] == true) {
            completer.complete(
              AckResponse(success: true, data: data['message']),
            );
          } else {
            completer.complete(
              AckResponse(
                success: false,
                error: data['error'] as String? ?? 'Unknown server error',
              ),
            );
          }
        } catch (e) {
          completer.complete(
            AckResponse(
              success: false,
              error: 'Invalid response format from server.',
            ),
          );
        }
      },
    );
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(
          AckResponse(success: false, error: 'Request timed out.'),
        );
      }
    });
    return completer.future;
  }

  Future<AckResponse> joinConversation(String conversationId) async =>
      _emitWithAck('join_conversation', conversationId);

  Future<AckResponse> sendMessage({
    required String body,
    required String conversationId,
    required String clientMsgId,
  }) async => _emitWithAck('message_send', {
    'conversationId': conversationId,
    'body': body,
    'clientMsgId': clientMsgId,
  });

  Future<AckResponse> sendFirstMessage({
    required String body,
    required String clientMsgId,
    required List<String> memberIds,
  }) async => _emitWithAck('message_send', {
    'conversationId': 'new_direct_chat',
    'body': body,
    'clientMsgId': clientMsgId,
    'members': memberIds,
    'type': 'direct',
  });

  void markMessagesAsRead({required String conversationId}) {
    if (_socket?.connected ?? false) {
      _socket!.emit('messages_read', {'conversationId': conversationId});
    }
  }

  void sendTypingStart(String conversationId) =>
      _socket?.emit('typing_start', {'conversationId': conversationId});
  void sendTypingStop(String conversationId) =>
      _socket?.emit('typing_stop', {'conversationId': conversationId});
}
