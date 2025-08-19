import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final photoPath = authProvider.photoPath;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data available.')),
      );
    }

    List<Widget> buildInfoFields() {
      final fields = <Widget>[];

      void addField(String label, dynamic value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          fields.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(value.toString())),
                ],
              ),
            ),
          );
        }
      }

      addField('Enrollment Number', user['enrollment_number']);
      addField('Registration Number', user['registration_number']);
      addField('Name', user['name']);
      addField('Email', user['email']);
      addField('Phone', user['phone']);
      addField('Course', user['course']);
      addField('Year', user['year']);
      addField('Stream', user['stream']);
      addField('Section', user['section']);
      addField('Roll Number', user['roll_number']);
      addField('Year of Joining', user['year_of_joining']);
      addField('Department', user['department']);
      addField('Role', user['role']);

      return fields;
    }

    Future<void> confirmLogout(BuildContext context) async {
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

      if (confirmed == true) {
        await authProvider.logout();
        if (context.mounted) {
          // Make login screen the new root so user cannot navigate back
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
    }

    // Safe photo check (works even if photoPath is null or invalid)
    Widget buildAvatar() {
      if (photoPath != null) {
        try {
          final file = File(photoPath);
          if (file.existsSync()) {
            return CircleAvatar(radius: 60, backgroundImage: FileImage(file));
          }
        } catch (_) {
          // ignore file errors and fall back to default avatar
        }
      }

      return const CircleAvatar(
        radius: 60,
        child: Icon(Icons.person, size: 50),
      );
    }

    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildAvatar(),
            const SizedBox(height: 24),
            ...buildInfoFields(),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
              ),
              onPressed: () => confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }
}
