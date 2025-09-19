import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat/user_model.dart';
import '../../providers/chat/group_creation_provider.dart';
import '../../services/chat/chat_api_service.dart';
import '../../widgets/chat/user_chip.dart';
import '../../widgets/chat/user_tile_list.dart';
import './new_group_screen.dart';

/// A wrapper widget that provides the [GroupCreationProvider] to the screen.
class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupCreationProvider(),
      child: const _CreateGroupScreenView(),
    );
  }
}

/// The main view for selecting members for a new group.
class _CreateGroupScreenView extends StatefulWidget {
  const _CreateGroupScreenView();

  @override
  State<_CreateGroupScreenView> createState() => _CreateGroupScreenViewState();
}

class _CreateGroupScreenViewState extends State<_CreateGroupScreenView> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: Consumer<GroupCreationProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildSelectedUsers(provider),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users to add...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(child: _buildSearchResults(provider)),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<GroupCreationProvider>(
        builder: (context, provider, child) {
          return provider.selectedUsers.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // Pass the existing provider to the next screen
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const NewGroupScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.arrow_forward),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  /// Builds the horizontal list of selected user chips.
  Widget _buildSelectedUsers(GroupCreationProvider provider) {
    if (provider.selectedUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.selectedUsers.length,
        itemBuilder: (context, index) {
          final user = provider.selectedUsers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: UserChip(
              user: user,
              onDelete: () {
                provider.removeUser(user);
              },
            ),
          );
        },
      ),
    );
  }

  /// Builds the list of search results.
  Widget _buildSearchResults(GroupCreationProvider provider) {
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

    // Filter out users who are already selected.
    final filteredResults = _searchResults.where((user) {
      return !provider.selectedUsers.any(
        (selected) => selected.enrollmentNumber == user.enrollmentNumber,
      );
    }).toList();

    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final user = filteredResults[index];
        return UserListTile(
          user: user,
          onTap: () {
            provider.addUser(user);
          },
        );
      },
    );
  }
}
