import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat/group_creation_provider.dart';
import '../../providers/chat/conversation_provider.dart';
import './chat_screen.dart';

// Enums for type-safe state management of policies
enum MessagingPolicy { allMembers, adminsOnly }

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();

  // State variable for messaging policy
  MessagingPolicy _messagingPolicy = MessagingPolicy.allMembers;

  // NOTE: We don't need a separate state for JoinPolicy as per the updated plan
  // and since the backend defaults to 'admin_approval'.

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  /// Helper to convert enums to the string values the API expects
  String _messagingPolicyToString(MessagingPolicy policy) {
    return policy == MessagingPolicy.allMembers ? 'all_members' : 'admins_only';
  }

  /// Finalizes the group creation process by calling the provider's method.
  Future<void> _createGroup() async {
    final groupProvider = Provider.of<GroupCreationProvider>(
      context,
      listen: false,
    );
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    // Call the provider method to create the group.
    final newConversation = await groupProvider.createGroup(
      title: _groupNameController.text.trim(),
      messagingPolicy: _messagingPolicyToString(_messagingPolicy),
    );

    if (mounted) {
      if (newConversation != null) {
        // Add the new conversation to the main list.
        conversationProvider.addOrUpdateConversation(newConversation);

        // Pop the three screens of the group creation flow off the stack.
        // We go back to the ConversationListScreen before pushing the new chat screen.
        Navigator.of(context)
          ..pop()
          ..pop();

        // Push the new ChatScreen.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: newConversation),
          ),
        );
      } else {
        // Show the error from the provider.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(groupProvider.error ?? 'An unknown error occurred.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer listens to the provider for state changes (like isLoading)
    return Consumer<GroupCreationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('New Group Details')),
          body: Stack(
            children: [
              ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const Divider(),
                  _buildSectionHeader('Members'),
                  _buildParticipantsGrid(provider),
                  const Divider(),
                  _buildSectionHeader('Who can send messages?'),
                  RadioListTile<MessagingPolicy>(
                    title: const Text('All Members'),
                    value: MessagingPolicy.allMembers,
                    groupValue: _messagingPolicy,
                    onChanged: (MessagingPolicy? value) {
                      if (value != null) {
                        setState(() => _messagingPolicy = value);
                      }
                    },
                  ),
                  RadioListTile<MessagingPolicy>(
                    title: const Text('Only Admins'),
                    value: MessagingPolicy.adminsOnly,
                    groupValue: _messagingPolicy,
                    onChanged: (MessagingPolicy? value) {
                      if (value != null) {
                        setState(() => _messagingPolicy = value);
                      }
                    },
                  ),
                ],
              ),
              if (provider.isLoading)
                Container(
                  color: Colors.black.withAlpha(128),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.isLoading ? null : _createGroup,
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(provider.isLoading ? 'Creating...' : 'Create Group'),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  /// Builds a header for a section.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Builds a grid of the selected participants.
  Widget _buildParticipantsGrid(GroupCreationProvider provider) {
    if (provider.selectedUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No participants selected.'),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: provider.selectedUsers.length,
      itemBuilder: (context, index) {
        final user = provider.selectedUsers[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(height: 4),
            Text(
              user.name.split(' ').first,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
