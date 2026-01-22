import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/auth_service.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CheffyApp());
}

class CheffyApp extends StatelessWidget {
  const CheffyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheffy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that listens to auth state and shows appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return _OnboardingCheck(
            user: snapshot.data!,
            authService: authService,
          );
        }

        // User is not logged in
        return LoginScreen(authService: authService);
      },
    );
  }
}

/// Check if user has completed onboarding
class _OnboardingCheck extends StatefulWidget {
  final User user;
  final AuthService authService;

  const _OnboardingCheck({required this.user, required this.authService});

  @override
  State<_OnboardingCheck> createState() => _OnboardingCheckState();
}

class _OnboardingCheckState extends State<_OnboardingCheck> {
  final _preferencesService = PreferencesService();
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await _preferencesService.hasCompletedOnboarding(
      widget.user.uid,
    );
    if (mounted) {
      setState(() {
        _needsOnboarding = !completed;
        _isLoading = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _needsOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LoadingScreen();
    }

    if (_needsOnboarding) {
      return OnboardingScreen(
        odUserId: widget.user.uid,
        onComplete: _onOnboardingComplete,
      );
    }

    return HomeScreen(authService: widget.authService);
  }
}

/// Loading screen
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F8E9)],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
