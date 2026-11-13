import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // MVP: silent account, no form. Reuses the existing user if there is one.
  Future<void> signInAnonymously() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  // Kept for the final week (email sign-in).
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> createAccount(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();
}