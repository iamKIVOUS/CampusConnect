import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/chat/conversation_model.dart';
import '../../models/chat/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat/chat_provider.dart';
import '../../providers/chat/conversation_provider.dart';
import '../../services/chat/chat_socket_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_field.dart';
import 'group_setting_screen.dart';
import 'personal_chat_settings_screen.dart';

class ChatScreen extends StatelessWidget {
  // --- FIX ---
  // The screen now robustly accepts either an existing conversation OR a target user.
  final Conversation? conversation;
  final ChatUser? targetUser;

  const ChatScreen({super.key, this.conversation, this.targetUser})
    : assert(
        conversation != null || targetUser != null,
        'Either a conversation or a targetUser must be provided.',
      );

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    final currentUser = ChatUser(
      enrollmentNumber: authProvider.user?['enrollment_number'] ?? '',
      name: authProvider.user?['name'] ?? 'Me',
      photoUrl: authProvider.user?['photo_url'],
    );

    // --- FIX ---
    // This logic now correctly constructs the initial state for both new and existing chats.
    final Conversation initialConversation;
    if (conversation != null) {
      initialConversation = conversation!;
    } else {
      // Create a temporary, client-side conversation object for the new chat.
      initialConversation = Conversation(
        id: 'new_direct_chat', // A special placeholder ID
        type: 'direct',
        members: [currentUser, targetUser!],
        unreadCount: 0,
        isArchived: false,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        initialConversation: initialConversation,
        currentUser: currentUser,
        conversationProvider: conversationProvider,
      ),
      child: _ChatScreenView(currentUserId: currentUser.enrollmentNumber),
    );
  }
}

class _ChatScreenView extends StatefulWidget {
  final String currentUserId;

  const _ChatScreenView({required this.currentUserId});

  @override
  State<_ChatScreenView> createState() => _ChatScreenViewState();
}

class _ChatScreenViewState extends State<_ChatScreenView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final _typingTimerDuration = const Duration(seconds: 2);
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.removeListener(_onTyping);
    _messageController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300.0) {
      context.read<ChatProvider>().fetchMoreMessages();
    }
  }

  void _onTyping() {
    final provider = context.read<ChatProvider>();
    if (!provider.conversation.isMember ||
        provider.conversation.id == 'new_direct_chat') {
      return;
    }

    ChatSocketService.instance.sendTypingStart(provider.conversation.id);
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimerDuration, () {
      ChatSocketService.instance.sendTypingStop(provider.conversation.id);
    });
  }

  void _sendMessage() {
    final provider = context.read<ChatProvider>();
    if (_messageController.text.trim().isNotEmpty) {
      provider.sendMessage(
        _messageController.text,
        isNewConversation: provider.conversation.id == 'new_direct_chat',
      );
      _messageController.clear();
      _typingTimer?.cancel();
      if (provider.conversation.id != 'new_direct_chat') {
        ChatSocketService.instance.sendTypingStop(provider.conversation.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final conv = provider.conversation;
        final bool isEffectivelyEmpty = !provider.messages.any(
          (m) => m.type == 'user',
        );

        return VisibilityDetector(
          key: Key('chat-screen-${conv.id}'),
          onVisibilityChanged: (visibilityInfo) {
            if (visibilityInfo.visibleFraction > 0.8) {
              provider.markMessagesAsRead();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(conv.displayTitle(widget.currentUserId)),
              actions: [
                if (conv.id != 'new_direct_chat' && conv.isMember)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      if (conv.type == 'group') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GroupSettingsScreen(conversation: conv),
                          ),
                        );
                      } else {
                        // --- FIX ---
                        // Use ChangeNotifierProvider.value to pass the *existing* provider
                        // instance to the new route, ensuring state is shared.
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: provider,
                              child: PersonalChatSettingsScreen(
                                conversation: conv,
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: provider.isLoading && provider.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : provider.error != null && provider.messages.isEmpty
                      ? Center(child: Text('Error: ${provider.error}'))
                      : isEffectivelyEmpty
                      ? const Center(
                          child: Text(
                            'Start the conversation! 👋',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: provider.messages.length,
                          itemBuilder: (context, index) {
                            final message = provider.messages[index];
                            final isMe =
                                message.sender?.enrollmentNumber ==
                                widget.currentUserId;
                            return MessageBubble(
                              message: message,
                              isMe: isMe,
                              onRetry: () {
                                final clientMsgId = message.clientMsgId;
                                if (clientMsgId != null) {
                                  provider.retrySendMessage(clientMsgId);
                                }
                              },
                            );
                          },
                        ),
                ),
                _buildTypingIndicator(provider),
                ChatInputField(
                  controller: _messageController,
                  isEnabled: conv.isMember,
                  onSendMessage: _sendMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(ChatProvider provider) {
    final typingUsers = provider.typingUsers
        .where((user) => user.enrollmentNumber != widget.currentUserId)
        .toList();

    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    String typingText = (typingUsers.length == 1)
        ? '${typingUsers.first.name} is typing...'
        : 'Several people are typing...';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 24.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          typingText,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
