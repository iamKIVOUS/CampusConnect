import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat/conversation_provider.dart';
import '../../widgets/chat/conversation_list_tile.dart';
import '../../models/chat/conversation_model.dart';
import './create_conversation_screen.dart';
import './chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    // --- FIX ---
    // All initialization logic is removed from here. The ConversationProvider
    // is now managed by a ChangeNotifierProxyProvider, which automatically
    // fetches data when the auth state changes. This is the correct, robust pattern.
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final provider = context.read<ConversationProvider>();
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        provider.searchConversationsAndMessages(query);
      } else {
        provider.clearSearch();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        context.read<ConversationProvider>().clearSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              )
            : const Text('Chats'),
        actions: [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.refreshConversations,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final bool hasSearchQuery = _searchController.text.trim().isNotEmpty;
          final List<Conversation> listToShow = hasSearchQuery
              ? provider.searchResults
              : provider.conversations;

          if (listToShow.isEmpty) {
            return Center(
              child: Text(
                hasSearchQuery
                    ? 'No results found.'
                    : 'No conversations yet.\nTap + to start chatting!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refreshConversations,
            child: _buildConversationList(listToShow, provider),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? conversationCreated = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateConversationScreen()),
          );
          if (conversationCreated == true && mounted) {
            context.read<ConversationProvider>().refreshConversations();
          }
        },
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Widget _buildConversationList(
    List<Conversation> conversations,
    ConversationProvider provider,
  ) {
    final currentUserId = context
        .watch<AuthProvider>()
        .user?['enrollment_number'];

    if (currentUserId == null) {
      return const Center(child: Text('Not authenticated.'));
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return ConversationListTile(
          conversation: conversation,
          currentUserId: currentUserId,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(conversation: conversation),
              ),
            );
          },
        );
      },
    );
  }
}
