// lib/widgets/chat/user_chip.dart

import 'package:flutter/material.dart';
import '../../models/chat/user_model.dart';

/// A reusable widget to display a single, selected user as a Chip.
///
/// This widget is designed for use in a horizontal list of selected users,
/// such as in the group creation or member addition screens.
class UserChip extends StatelessWidget {
  /// The user data to display.
  final ChatUser user;

  /// A callback function that is triggered when the user taps the delete icon.
  final VoidCallback onDelete;

  const UserChip({super.key, required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(user.name),
      avatar: CircleAvatar(
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? const Icon(Icons.person, size: 18)
            : null,
      ),
      onDeleted: onDelete,
      deleteIcon: const Icon(Icons.cancel),
    );
  }
}
