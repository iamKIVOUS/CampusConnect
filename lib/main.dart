import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './screens/login_screen.dart';
import './screens/dashboard_screen.dart';

import './providers/auth_provider.dart';
import './providers/routine_provider.dart';
import './providers/attendance_provider.dart';
import './providers/chat/conversation_provider.dart';
import './providers/chat/group_creation_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusConnectAppWithProviders());
}

// --- DEFINITIVE FIX: Encapsulate Providers ---
// This new root widget cleanly separates the provider setup from the app logic.
class CampusConnectAppWithProviders extends StatelessWidget {
  const CampusConnectAppWithProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),

        // This ProxyProvider is now the key to our state lifecycle.
        ChangeNotifierProxyProvider<AuthProvider, ConversationProvider>(
          create: (context) => ConversationProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previousConversationProvider) {
            // This is the crucial line. When AuthProvider notifies its
            // listeners, this `update` method is called, passing the
            // new auth state to our ConversationProvider.
            previousConversationProvider!.update(auth);
            return previousConversationProvider;
          },
        ),

        ChangeNotifierProvider(create: (_) => GroupCreationProvider()),
      ],
      child: const CampusConnectApp(),
    );
  }
}

class CampusConnectApp extends StatefulWidget {
  const CampusConnectApp({super.key});

  @override
  State<CampusConnectApp> createState() => _CampusConnectAppState();
}

class _CampusConnectAppState extends State<CampusConnectApp> {
  // --- DEFINITIVE FIX: Simplify Initialization ---
  // The FutureBuilder pattern handles the async loading of user data gracefully.
  // This avoids managing an `_isInitializing` flag in the state.
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    // The initialization logic is now tied to a Future.
    _initFuture = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          // While the initial user data is loading, show a splash screen.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          // After loading, use the Consumer to listen for login/logout changes.
          return Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isLoggedIn) {
                return const DashboardScreen();
              } else {
                return const LoginScreen();
              }
            },
          );
        },
      ),
      routes: {
        '/dashboard': (ctx) => const DashboardScreen(),
        '/login': (ctx) => const LoginScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
