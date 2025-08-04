import "dart:io";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:campus_connect/screens/chat_screen.dart";
import "package:campus_connect/screens/login_screen.dart";
import "package:campus_connect/screens/profile_screen.dart";
import '../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late String selectedDay;

  final List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final Map<int, String> periodTimings = {
    1: '9:30 - 10:30',
    2: '10:30 - 11:30',
    3: '11:30 - 12:30',
    4: '13:30 - 14:20',
    5: '14:20 - 15:10',
    6: '15:10 - 16:00',
  };

  @override
  void initState() {
    super.initState();
    final currentDay = DateTime.now().weekday;
    selectedDay = weekdays[(currentDay - 1).clamp(0, weekdays.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final photoPath = authProvider.photoPath;
    final routine = authProvider.routine;

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

    final todayRoutine =
        (routine as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((item) => item['day'] == selectedDay)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: Row(
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => confirmLogout(context),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekdays.length,
              itemBuilder: (context, index) {
                final day = weekdays[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: selectedDay == day,
                    onSelected: (_) => setState(() => selectedDay = day),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                final periodNumber = index + 1;
                Map<String, dynamic>? routineEntry = todayRoutine
                    .cast<Map<String, dynamic>?>()
                    .firstWhere(
                      (r) => r?['period'] == periodNumber,
                      orElse: () => null,
                    );

                return Card(
                  margin: const EdgeInsets.all(8),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      "Period $periodNumber - ${periodTimings[periodNumber] ?? ''}",
                    ),
                    subtitle: routineEntry != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Subject: ${routineEntry['subject'] ?? 'N/A'}",
                              ),
                              Text(
                                "Professor: ${routineEntry['substitute_id'] ?? routineEntry['professor_id']}",
                              ),
                            ],
                          )
                        : const Text("No class scheduled."),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
