import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './screens/login_screen.dart';
import './screens/profile_screen.dart';
import './providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure AuthProvider initializes saved user/token
  final authProvider = AuthProvider();
  await authProvider.loadUserData();

  runApp(
    ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
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
              ? const ProfileScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
