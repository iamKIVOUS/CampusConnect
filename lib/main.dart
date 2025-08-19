// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './screens/login_screen.dart';
import './screens/dashboard_screen.dart';
import './providers/auth_provider.dart';
import './providers/routine_provider.dart';
import './providers/attendance_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create providers and initialize their persistent stores before runApp.
  final authProvider = AuthProvider();
  await authProvider.loadUserData();

  final routineProvider = RoutineProvider();
  try {
    await routineProvider.init();
  } catch (e, st) {
    // Initialization failures shouldn't crash the app at startup;
    // log and continue — the UI can surface the error via the provider.
    debugPrint('RoutineProvider.init failed: $e\n$st');
  }

  final attendanceProvider = AttendanceProvider();
  try {
    await attendanceProvider.init();
  } catch (e, st) {
    debugPrint('AttendanceProvider.init failed: $e\n$st');
  }

  runApp(
    MultiProvider(
      providers: [
        // AuthProvider preloaded above (value constructor avoids re-running load)
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        // Routine/Attendance providers created and already initialized
        ChangeNotifierProvider<RoutineProvider>.value(value: routineProvider),
        ChangeNotifierProvider<AttendanceProvider>.value(
          value: attendanceProvider,
        ),
      ],
      child: const CampusConnectApp(),
    ),
  );
}

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return authProvider.isLoggedIn
              ? const DashboardScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
