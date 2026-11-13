import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MealPlannerApp());
}

class MealPlannerApp extends StatefulWidget {
  const MealPlannerApp({super.key});
  @override
  State<MealPlannerApp> createState() => _MealPlannerAppState();
}

class _MealPlannerAppState extends State<MealPlannerApp> {
  final _auth = AuthService();
  String? _error;

  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Planner',
      theme: AppTheme.light,
      // Never smaller than 115% text, but still follows a larger phone setting.
      builder: (context, child) {
        final scaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 1.15, maxScaleFactor: 1.6);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
      home: _error != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.oxblood),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _signIn,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: _auth.authChanges,
              builder: (context, snapshot) => snapshot.hasData
                  ? const HomeScreen()
                  : const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
            ),
    );
  }
}
