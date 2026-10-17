import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Currently logged-in user (null if nobody is logged in).
  User? get currentUser => _auth.currentUser;

  /// Emits a new value on every login/logout, so the UI can update itself.
  Stream<User?> get authChanges => _auth.authStateChanges();

  /// Signs in with email and password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // null means success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        default:
          return 'Login failed: ${e.message}';
      }
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Logs out the current user.
  Future<void> signOut() => _auth.signOut();
}