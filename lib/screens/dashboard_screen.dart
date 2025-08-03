//import "package:campus_connect/screens/profile_screen.dart";
import "dart:io";

import "package:campus_connect/screens/login_screen.dart";
import "package:campus_connect/screens/profile_screen.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import '../providers/auth_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final photoPath = authProvider.photoPath;
    Future<void> confirmLogout(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout"),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await authProvider.logout();
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (photoPath != null && File(photoPath).existsSync())
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: FileImage(File(photoPath)),
                    )
                  else
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person, size: 30),
                    ),
                  const SizedBox(width: 16),
                  Text(
                    user?['name'] ?? 'User',
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                // Navigate to Profile Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat'),
              onTap: () {
                // Navigate to About Screen (if implemented)
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                confirmLogout(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
