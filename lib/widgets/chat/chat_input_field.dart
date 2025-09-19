// lib/widgets/chat/chat_input_field.dart

import 'package:flutter/material.dart';

/// A robust, self-contained widget for a chat input field.
///
/// This stateless widget manages its internal UI state and provides callbacks
/// to its parent for handling user actions like sending messages and typing.
class ChatInputField extends StatelessWidget {
  /// A controller to manage the text input state.
  final TextEditingController controller;

  /// A callback for when the user types.
  final VoidCallback? onTyping;

  /// A callback for when the user sends a message.
  final VoidCallback? onSendMessage;

  /// A flag to enable or disable the input field.
  final bool isEnabled;

  const ChatInputField({
    super.key,
    required this.controller,
    this.onTyping,
    this.onSendMessage,
    this.isEnabled = true,
  });

  /// Builds the view for a disabled chat input field.
  Widget _buildDisabledView(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(16.0),
        color: Theme.of(context).cardColor,
        child: Center(
          child: Text(
            'You cannot send messages to this group because you are no longer a member.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return _buildDisabledView(context);
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 2,
              color: Colors.grey.withAlpha(26),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) {
                  // Trigger the onTyping callback when text changes.
                  if (onTyping != null) {
                    onTyping!();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withAlpha(50),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) {
                  // Trigger the onSendMessage callback on submission.
                  if (onSendMessage != null &&
                      controller.text.trim().isNotEmpty) {
                    onSendMessage!();
                    controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: controller.text.trim().isNotEmpty
                  ? () {
                      if (onSendMessage != null) {
                        onSendMessage!();
                        controller.clear();
                      }
                    }
                  : null,
              color: controller.text.trim().isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
