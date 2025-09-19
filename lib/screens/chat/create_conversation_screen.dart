import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/chat/user_model.dart';
import '../../services/chat/chat_api_service.dart';
import './create_group_screen.dart';
import './chat_screen.dart';
import '../../widgets/chat/user_tile_list.dart';

/// A screen for creating a new personal chat or a new group chat.
class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({super.key});

  @override
  State<CreateConversationScreen> createState() =>
      _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatApiService _chatApiService = ChatApiService();

  List<ChatUser> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounces the search input to prevent excessive API calls.
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
          });
        }
      }
    });
  }

  /// Performs the user search API call and updates the UI state.
  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _chatApiService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// --- FIX: Defer conversation creation until the first message is sent. ---
  /// Now, this function only navigates to the ChatScreen with the target user.
  Future<void> _navigateToDirectChat(ChatUser user) async {
    if (!mounted) return;

    // Pop the current screen.
    Navigator.of(context).pop();
    // Push the new ChatScreen with the target user.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(targetUser: user)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Conversation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or enrollment number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group_add)),
            title: const Text('Create a new group'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
            },
          ),
          const Divider(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  /// Builds the view for the search results section.
  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('No users found.'));
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('Start typing to find users.'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return UserListTile(
          user: user,
          onTap: () => _navigateToDirectChat(user),
        );
      },
    );
  }
}
