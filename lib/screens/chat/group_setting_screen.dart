import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/chat/conversation_model.dart';
import '../../models/chat/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat/chat_provider.dart';
import '../../providers/chat/conversation_provider.dart';
import 'add_member_screen.dart';

/// A wrapper widget that provides the [ChatProvider] to the settings view.
class GroupSettingsScreen extends StatelessWidget {
  final Conversation conversation;

  const GroupSettingsScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    // Get the authenticated user from the AuthProvider
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

    return ChangeNotifierProvider(
      // The settings screen uses its own instance of ChatProvider
      // to manage its local state and interact with the API.
      create: (_) => ChatProvider(
        initialConversation: conversation,
        currentUser: currentUser,
        conversationProvider: conversationProvider,
      ),
      child: const _GroupSettingsView(),
    );
  }
}

/// The main view for managing group settings.
class _GroupSettingsView extends StatefulWidget {
  const _GroupSettingsView();

  @override
  State<_GroupSettingsView> createState() => _GroupSettingsViewState();
}

class _GroupSettingsViewState extends State<_GroupSettingsView> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      _titleController.text = provider.conversation.title ?? '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Builds a header section with the group's photo and title.
  Widget _buildGroupHeader(BuildContext context, Conversation conversation) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: conversation.photoUrl != null
                ? NetworkImage(conversation.photoUrl!)
                : null,
            child: conversation.photoUrl == null
                ? const Icon(Icons.group, size: 50)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            conversation.title ?? 'Group Chat',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('${conversation.members.length} members'),
        ],
      ),
    );
  }

  /// Builds the section for admins to edit group settings.
  Widget _buildSettingsSection(
    BuildContext context,
    ChatProvider provider,
    bool isAdmin,
  ) {
    if (!isAdmin) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Group Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                onSubmitted: (value) async {
                  if (value.trim().isNotEmpty &&
                      value.trim() != provider.conversation.title) {
                    await provider.updateGroupDetails({'title': value.trim()});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the section that lists all group members.
  Widget _buildMemberSection(
    BuildContext context,
    ChatProvider provider,
    bool isAdmin,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.conversation.members.length} Members',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isAdmin)
                  TextButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            // --- FIX ---
                            // The AddMembersScreen now correctly receives the list of
                            // existing members. This prevents it from showing users
                            // who are already in the group in the search results.
                            child: AddMembersScreen(
                              existingMembers: provider.conversation.members,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.conversation.members.length,
            itemBuilder: (context, index) {
              final member = provider.conversation.members[index];
              return _buildMemberTile(context, provider, member, isAdmin);
            },
          ),
        ],
      ),
    );
  }

  /// Builds a single member tile with a popup menu for admin actions.
  Widget _buildMemberTile(
    BuildContext context,
    ChatProvider provider,
    ChatUser member,
    bool isAdmin,
  ) {
    final bool isSelf =
        member.enrollmentNumber == provider.currentUser.enrollmentNumber;
    final roleText = toBeginningOfSentenceCase(member.role ?? 'member');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: member.photoUrl != null
            ? NetworkImage(member.photoUrl!)
            : null,
        child: member.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(member.name + (isSelf ? ' (You)' : '')),
      subtitle: Text(roleText),
      trailing: isAdmin && !isSelf
          ? PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'make_admin':
                    await provider.updateUserRole(
                      member.enrollmentNumber,
                      'admin',
                    );
                    break;
                  case 'demote_member':
                    await provider.updateUserRole(
                      member.enrollmentNumber,
                      'member',
                    );
                    break;
                  case 'remove':
                    await provider.removeMember(member.enrollmentNumber);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (member.role != 'admin')
                  const PopupMenuItem(
                    value: 'make_admin',
                    child: Text('Make Admin'),
                  ),
                if (member.role == 'admin')
                  const PopupMenuItem(
                    value: 'demote_member',
                    child: Text('Demote to Member'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from Group'),
                ),
              ],
            )
          : null,
      onTap: () {
        // Navigate to the member's profile page
        // Note: ProfileScreen is not part of this chat feature.
      },
    );
  }

  /// Builds the 'Danger Zone' section with the 'Leave Group' button.
  Widget _buildDangerZone(BuildContext context, ChatProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.exit_to_app,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'Leave Group',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onTap: () async {
          await provider.leaveGroup();
          if (mounted) {
            // Pop back to the chat screen
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final bool isCurrentUserAdmin = provider.conversation.members.any(
          (m) =>
              m.enrollmentNumber == provider.currentUser.enrollmentNumber &&
              m.role == 'admin',
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Group Info')),
          body: Stack(
            children: [
              ListView(
                children: [
                  _buildGroupHeader(context, provider.conversation),
                  const SizedBox(height: 8),
                  _buildSettingsSection(context, provider, isCurrentUserAdmin),
                  _buildMemberSection(context, provider, isCurrentUserAdmin),
                  _buildDangerZone(context, provider),
                ],
              ),
              if (provider.isLoading)
                Container(
                  color: Colors.black.withAlpha(128),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
