import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/official_accounts.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/officer_access_screen.dart';
import 'features/home/screens/main_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/dm_screen.dart';
import 'features/chat/screens/create_group_screen.dart';
import 'features/p_questions/screens/past_questions_screen.dart';
import 'features/ai_bot/screens/regent_ai_screen.dart';
import 'features/status/screens/status_screen.dart';
import 'features/alumni/screens/alumni_hub_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/info/screens/regent_university_info_screen.dart';
import 'features/users/screens/users_screen.dart';
import 'services/auth_service.dart';
import 'services/official_office_service.dart';
import 'features/broadcast/screens/broadcast_screen.dart';
import 'widgets/incoming_call_overlay.dart';
import 'core/student_progress.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const AppBootstrap(),
    ),
  );
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<FirebaseApp> _firebaseInitialization;

  @override
  void initState() {
    super.initState();
    _firebaseInitialization = _initializeFirebase();
  }

  Future<FirebaseApp> _initializeFirebase() {
    Future<FirebaseApp> initialize() async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      const useEmulators =
          bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);
      if (useEmulators) {
        FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
        FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
      }

      return Firebase.app();
    }

    return initialize();
  }

  void _retry() {
    setState(() {
      _firebaseInitialization = _initializeFirebase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            title: 'Regent Connect',
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Starting Regent Connect...'),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Regent Connect',
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Regent Connect could not reach Firebase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check your internet connection, then try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const MyApp();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Regent Connect',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const IncomingCallOverlay(
            child: AuthWrapper(),
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/officer-access': (context) => const OfficerAccessScreen(),
            '/home': (context) => const MainScreen(),
            '/chat': (context) {
              final arguments = ModalRoute.of(context)?.settings.arguments;
              if (arguments is Map) {
                final recipientId = arguments['userId']?.toString();
                if (recipientId != null && recipientId.isNotEmpty) {
                  return DMScreen(
                    recipientId: recipientId,
                    recipientName:
                        arguments['userName']?.toString() ?? 'Regent user',
                    recipientPhoto: arguments['userPhoto']?.toString(),
                  );
                }
              }
              return const ChatScreen();
            },
            '/users': (context) => const UsersScreen(),
            '/broadcast': (context) => const BroadcastScreen(),
            '/create-group': (context) => const CreateGroupScreen(),
            '/past-questions': (context) => const PastQuestionsScreen(),
            '/ai-bot': (context) => const RegentAIScreen(),
            '/status': (context) => const StatusScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/alumni': (context) => const AlumniHubScreen(),
            '/regent-info': (context) => const RegentUniversityInfoScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.idTokenChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return _AuthenticatedHome(user: user);
        }

        return const LoginScreen();
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({required this.user});

  final User user;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<_HomeDestination> _accessCheck;

  @override
  void initState() {
    super.initState();
    _accessCheck = _checkAccess();
  }

  Future<_HomeDestination> _checkAccess() async {
    final office = OfficialAccounts.byEmail(widget.user.email);
    if (office == null) {
      try {
        await AuthService()
            .syncCurrentUserBackend()
            .timeout(const Duration(seconds: 4));
      } catch (error) {
        debugPrint('User profile synchronization was deferred: $error');
        return _HomeDestination.home;
      }
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        final isAlumni = StudentProgress.isAlumniProfile(userDoc.data());
        return isAlumni ? _HomeDestination.alumni : _HomeDestination.home;
      } catch (error) {
        debugPrint('User access check fell back to the home screen: $error');
        return _HomeDestination.home;
      }
    }
    final service = OfficialOfficeService();
    try {
      await service
          .syncCurrentOfficerBackend()
          .timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('Officer backend sync was deferred: $error');
    }
    return _HomeDestination.home;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeDestination>(
      future: _accessCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == _HomeDestination.alumni) {
          return const AlumniHubScreen();
        }
        if (snapshot.data == _HomeDestination.home) {
          return const MainScreen();
        }

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 64,
                      color: RegentColors.violet,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Officer account awaiting activation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.user.email ?? 'This account'} must be provisioned by the Regent Connect administrator before it can open an official inbox.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OfficerAccessScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View officer access guide'),
                    ),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _HomeDestination {
  home,
  alumni,
}
