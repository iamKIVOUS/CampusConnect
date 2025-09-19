// lib/widgets/chat/user_list_tile.dart

import 'package:flutter/material.dart';
import '../../models/chat/user_model.dart';

/// A reusable widget to display a single user in a list.
///
/// This tile shows the user's avatar, name, and enrollment number. It is
/// designed to be used in various screens for user selection or display.
class UserListTile extends StatelessWidget {
  /// The user data to display.
  final ChatUser user;

  /// An optional callback function for when the tile is tapped.
  final VoidCallback? onTap;

  /// An optional widget to display at the end of the tile (e.g., a Checkbox).
  final Widget? trailing;

  const UserListTile({
    super.key,
    required this.user,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? const Icon(Icons.person, size: 28)
            : null,
      ),
      title: Text(user.name),
      subtitle: Text(user.enrollmentNumber),
      trailing: trailing,
    );
  }
}
