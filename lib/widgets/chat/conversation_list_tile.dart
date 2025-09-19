// lib/widgets/chat/conversation_list_tile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat/conversation_model.dart';
import '../../models/chat/message_status.dart';

/// A reusable widget to display a single conversation in a list.
///
/// This tile shows the conversation's avatar, title, a preview of the last
/// message, the timestamp, an unread count badge, and a real-time message
/// status icon. It is designed to be efficiently used inside a [ListView].
class ConversationListTile extends StatelessWidget {
  /// The conversation data to display.
  final Conversation conversation;

  /// The ID of the current user, used to determine message sender.
  final String currentUserId;

  /// The callback function that is executed when the tile is tapped.
  final VoidCallback onTap;

  const ConversationListTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.currentUserId,
  });

  /// Formats the timestamp for display.
  /// - Shows 'HH:mm' (e.g., "14:30") if the message was sent today.
  /// - Shows the day of the week (e.g., "Tue") if it was within the last week.
  /// - Shows the date (e.g., "24/08/25") for older messages.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate.isAtSameMomentAs(today)) {
      return DateFormat.Hm().format(timestamp); // e.g., 16:45
    } else if (today.difference(messageDate).inDays <= 6) {
      return DateFormat.E().format(timestamp); // e.g., Tue
    } else {
      return DateFormat('dd/MM/yy').format(timestamp); // e.g., 21/08/25
    }
  }

  /// Builds the widget to display either the unread count or the message status icon.
  Widget _buildStatusIndicator(BuildContext context) {
    // First, check for unread messages.
    if (conversation.unreadCount > 0) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          conversation.unreadCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final lastMessage = conversation.lastMessage;
    // Next, check if the last message was sent by the current user.
    if (lastMessage != null &&
        lastMessage.sender?.enrollmentNumber == currentUserId) {
      return Icon(
        _getIconForStatus(lastMessage.status),
        size: 16,
        color: _getColorForStatus(lastMessage.status, context),
      );
    }

    // Otherwise, return an empty placeholder.
    return const SizedBox.shrink();
  }

  IconData _getIconForStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.watch_later_outlined;
      case MessageStatus.sent:
        return Icons.done;
      case MessageStatus.delivered:
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getColorForStatus(MessageStatus status, BuildContext context) {
    switch (status) {
      case MessageStatus.read:
        return Theme.of(context).colorScheme.primary;
      case MessageStatus.failed:
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;

    String subtitleText = lastMessage?.body ?? '';
    if (lastMessage != null &&
        lastMessage.sender?.enrollmentNumber == currentUserId) {
      subtitleText = "You: ${lastMessage.body}";
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: conversation.displayPhotoUrl(currentUserId) != null
            ? NetworkImage(conversation.displayPhotoUrl(currentUserId)!)
            : null,
        child: conversation.displayPhotoUrl(currentUserId) == null
            ? Icon(
                conversation.type == 'group' ? Icons.group : Icons.person,
                size: 28,
              )
            : null,
      ),
      title: Text(
        conversation.displayTitle(currentUserId),
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: lastMessage != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(lastMessage.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                _buildStatusIndicator(context),
              ],
            )
          : null,
    );
  }
}
