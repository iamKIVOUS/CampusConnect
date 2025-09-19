import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Local imports
import 'package:campus_connect/widgets/routine_view.dart';
import 'package:campus_connect/widgets/attendance_view.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/attendance_provider.dart';
// Note: We no longer need to import ConversationProvider here.
import 'chat/conversation_list_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // 0 = Routine, 1 = Attendance
  bool _isRoutineLoading = true;
  String? _routineError;

  // Attendance view state
  bool _isAttendanceLoading = false;
  String? _attendanceError;

  @override
  void initState() {
    super.initState();
    // Fetch initial data after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoutineData();
    });
  }

  Future<void> _fetchRoutineData() async {
    // This logic seems fine, but ensure your RoutineProvider does not
    // have the same initialization issues as ConversationProvider did.
    // For now, we assume it's correct.
    final routineProvider = Provider.of<RoutineProvider>(
      context,
      listen: false,
    );
    // Ensure provider is initialized before fetching
    if (!routineProvider.isReady) {
      await routineProvider.init();
    }
    final success = await routineProvider.refreshRoutine();
    if (mounted) {
      setState(() {
        _isRoutineLoading = false;
        if (!success) {
          _routineError = routineProvider.error ?? 'Failed to load routine.';
        }
      });
    }
  }

  Future<void> _fetchAttendanceData() async {
    // This logic also seems fine for now.
    setState(() {
      _isAttendanceLoading = true;
      _attendanceError = null;
    });
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    try {
      if (!attendanceProvider.isInitialized) {
        await attendanceProvider.init();
      }
      await attendanceProvider.fetchAttendanceSummary();
      if (mounted) {
        setState(() {
          _isAttendanceLoading = false;
          _attendanceError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAttendanceLoading = false;
          _attendanceError =
              attendanceProvider.error ??
              'Failed to load attendance: ${e.toString()}';
        });
      }
    }
  }

  /// --- FINAL FIX: Simplified Navigation ---
  /// This function now navigates directly to ChatListScreen.
  /// It no longer needs to provide ConversationProvider because it is already
  /// provided globally in main.dart and is listening for auth changes.
  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/chat-list'),
        // No ChangeNotifierProvider needed here. ChatListScreen will find
        // the global instance automatically.
        builder: (context) => const ChatListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final photoPath = authProvider.photoPath;
    final role = user?['role'] ?? 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _navigateToChat(context),
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
                  Flexible(
                    child: Text(
                      user?['name'] ?? 'User',
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
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
              onTap: () => _navigateToChat(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => confirmLogout(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (role == 'student')
              ToggleButtons(
                isSelected: [_selectedIndex == 0, _selectedIndex == 1],
                onPressed: (index) {
                  setState(() => _selectedIndex = index);
                  if (index == 1) {
                    _fetchAttendanceData();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Routine'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Attendance'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Expanded(child: _buildContentView(role)),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(String role) {
    if (role == 'student') {
      if (_selectedIndex == 0) {
        return _buildRoutineView();
      } else {
        return _buildAttendanceView();
      }
    } else {
      // Assuming non-students also see the routine view.
      return _buildRoutineView();
    }
  }

  Widget _buildRoutineView() {
    if (_isRoutineLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_routineError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_routineError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isRoutineLoading = true;
                  _routineError = null;
                });
                _fetchRoutineData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const RoutineView();
  }

  Widget _buildAttendanceView() {
    if (_isAttendanceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_attendanceError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_attendanceError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isAttendanceLoading = true;
                  _attendanceError = null;
                });
                _fetchAttendanceData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const AttendanceView();
  }
}

Future<void> confirmLogout(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
