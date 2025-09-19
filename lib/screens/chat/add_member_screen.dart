import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat/user_model.dart';
import '../../providers/chat/chat_provider.dart';
import '../../services/chat/chat_api_service.dart';
import '../../widgets/chat/user_chip.dart';
import '../../widgets/chat/user_tile_list.dart';

/// A screen for a group admin to add new members to a group.
class AddMembersScreen extends StatefulWidget {
  /// The list of users who are already members of the conversation.
  final List<ChatUser> existingMembers;

  const AddMembersScreen({super.key, required this.existingMembers});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatApiService _chatApiService = ChatApiService();

  List<ChatUser> _searchResults = [];
  final List<ChatUser> _selectedUsers = [];
  bool _isSearching = false;
  bool _isAdding = false;
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

  /// Implements a debounce timer for the search input.
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

  /// Performs the user search API call and filters out existing members.
  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });
    try {
      final results = await _chatApiService.searchUsers(query);
      final existingMemberIds = widget.existingMembers
          .map((m) => m.enrollmentNumber)
          .toSet();
      if (mounted) {
        setState(() {
          _searchResults = results
              .where(
                (user) => !existingMemberIds.contains(user.enrollmentNumber),
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to search users: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// Adds or removes a user from the list of selected members.
  void _toggleSelection(ChatUser user) {
    setState(() {
      final isSelected = _selectedUsers.any(
        (u) => u.enrollmentNumber == user.enrollmentNumber,
      );
      if (isSelected) {
        _selectedUsers.removeWhere(
          (u) => u.enrollmentNumber == user.enrollmentNumber,
        );
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  /// Handles the API call to add the selected members to the group.
  Future<void> _addSelectedMembers() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isAdding = true);

    try {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      final memberIdsToAdd = _selectedUsers
          .map((u) => u.enrollmentNumber)
          .toList();

      await provider.addMembers(memberIdsToAdd);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add members: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Participants'),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isAdding ? null : _addSelectedMembers,
              child: _isAdding
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text('ADD (${_selectedUsers.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSelectedUsers(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'Search by name or enrollment number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  /// Builds the horizontal list of selected users.
  Widget _buildSelectedUsers() {
    if (_selectedUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedUsers.length,
        itemBuilder: (context, index) {
          final user = _selectedUsers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: UserChip(user: user, onDelete: () => _toggleSelection(user)),
          );
        },
      ),
    );
  }

  /// Builds the list of search results.
  Widget _buildSearchResults() {
    if (!_isSearching && _searchController.text.isEmpty) {
      return const Center(
        child: Text(
          'Start typing to find users.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    if (!_isSearching && _searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSelected = _selectedUsers.any(
          (u) => u.enrollmentNumber == user.enrollmentNumber,
        );

        return UserListTile(
          user: user,
          onTap: () => _toggleSelection(user),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (bool? value) => _toggleSelection(user),
          ),
        );
      },
    );
  }
}
