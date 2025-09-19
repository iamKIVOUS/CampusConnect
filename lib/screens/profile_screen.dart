// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

/// A screen that displays a user's profile.
///
/// This screen is versatile:
/// - If a [chatUser] is provided, it will fetch and display that user's profile.
/// - If no [chatUser] is provided, it defaults to showing the currently
///   logged-in user's profile from the [AuthProvider].
class ProfileScreen extends StatefulWidget {
  final ChatUser? chatUser;

  const ProfileScreen({super.key, this.chatUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<ChatUser?>? _profileFuture;
  final UserApiService _userApiService = UserApiService();

  bool get _isViewingOtherUser => widget.chatUser != null;

  @override
  void initState() {
    super.initState();
    if (_isViewingOtherUser) {
      // If we are viewing another user, trigger an API call to fetch their full profile.
      _profileFuture = _userApiService.getUserProfile(
        widget.chatUser!.enrollmentNumber,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which user data to display.
    if (_isViewingOtherUser) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.chatUser!.name)),
        body: FutureBuilder<ChatUser?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Failed to load profile: ${snapshot.error}'),
              );
            }
            final user = snapshot.data;
            if (user == null) {
              return const Center(child: Text('User profile not found.'));
            }
            // Once data is fetched, build the profile view.
            return _ProfileView(user: user, isCurrentUser: false);
          },
        ),
      );
    } else {
      final authProvider = Provider.of<AuthProvider>(context);
      final userData = authProvider.user;

      // Ensure user data is available before building the view.
      if (userData == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('My Profile')),
          body: const Center(child: Text('No user data available.')),
        );
      }

      final currentUser = ChatUser(
        enrollmentNumber: userData['enrollment_number'] ?? '',
        name: userData['name'] ?? '',
        photoUrl: userData['photo_url'],
        role: userData['role'],
      );

      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context, authProvider),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _ProfileView(
          user: currentUser,
          photoPath: authProvider.photoPath,
          isCurrentUser: true,
          onLogout: () => _confirmLogout(context, authProvider),
        ),
      );
    }
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

/// The reusable widget that renders the actual profile UI.
class _ProfileView extends StatelessWidget {
  final ChatUser user;
  final String? photoPath;
  final bool isCurrentUser;
  final VoidCallback? onLogout;

  const _ProfileView({
    required this.user,
    this.photoPath,
    required this.isCurrentUser,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 24),
          _buildInfoFields(),
          if (isCurrentUser && onLogout != null) ...[
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: onLogout,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // For the current user, try to load the local file.
    if (isCurrentUser && photoPath != null) {
      final file = File(photoPath!);
      if (file.existsSync()) {
        return CircleAvatar(radius: 60, backgroundImage: FileImage(file));
      }
    }
    // For other users, use the photo URL from the API data.
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(user.photoUrl!),
      );
    }
    // Fallback icon if no image is available.
    return const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60));
  }

  Widget _buildInfoFields() {
    final fields = <Widget>[];
    void addField(String label, dynamic value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        fields.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    value.toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    addField('Name', user.name);
    addField('Enrollment Number', user.enrollmentNumber);
    addField('Role', user.role);

    return Column(children: fields);
  }
}
