import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat/conversation_model.dart';
import '../../models/chat/user_model.dart';
import '../../providers/chat/chat_provider.dart';
import '../../providers/chat/conversation_provider.dart';
import '../profile_screen.dart';

class PersonalChatSettingsScreen extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;

  const PersonalChatSettingsScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
  });

  Future<void> _deleteEmptyConversation(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    // Confirm with the user before deleting.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await chatProvider.deleteEmptyConversation(conversation.id);

        // Remove the conversation from the global list and close the screen.
        if (context.mounted) {
          conversationProvider.removeConversation(conversation.id);
          Navigator.of(context)
            ..pop() // Pop the settings screen
            ..pop(); // Pop the chat screen
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete chat: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the `ChatProvider` instance from the widget tree.
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final otherUser = conversation.members.firstWhere(
      (member) => member.enrollmentNumber != currentUserId,
      orElse: () =>
          const ChatUser(enrollmentNumber: 'unknown', name: 'Unknown User'),
    );

    // Check if the conversation has any messages to determine if it can be deleted.
    final canDelete = chatProvider.messages.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation Info')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(chatUser: otherUser),
                ),
              );
            },
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: otherUser.photoUrl != null
                      ? NetworkImage(otherUser.photoUrl!)
                      : null,
                  child: otherUser.photoUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  otherUser.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  otherUser.enrollmentNumber,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_search),
            title: const Text('View Profile'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(chatUser: otherUser),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.block,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Block User',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Block user feature not implemented yet.'),
                ),
              );
            },
          ),
          if (canDelete)
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Conversation',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _deleteEmptyConversation(context),
            ),
        ],
      ),
    );
  }
}
