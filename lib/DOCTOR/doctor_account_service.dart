import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
/// Creates Firebase Auth accounts for doctors.
///
/// Problem: calling createUserWithEmailAndPassword on the normal FirebaseAuth
/// instance signs the NEW user in and logs the admin out.
/// Fix: the account is created through a temporary second Firebase app, so
/// the admin's own session is never touched.
class DoctorAccountService {
  DoctorAccountService._();

  /// Creates the login. Throws an Exception with a readable message on
  /// failure (email already used, weak password, no internet, ...).
  static Future<DoctorAccount> create(String email, String password) async {
    final FirebaseApp secondary = await Firebase.initializeApp(
      name: 'doctorCreator${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return DoctorAccount._(cred.user!.uid, secondary, auth);
    } on FirebaseAuthException catch (e) {
      await secondary.delete();
      throw Exception(_readable(e));
    } catch (_) {
      await secondary.delete();
      rethrow;
    }
  }

  /// Sends Firebase's "reset your password" email to a doctor's login email.
  /// The doctor chooses the new password, so the admin never sees it.
  static Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-not-found':
          throw Exception('No login account exists for this email.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        case 'too-many-requests':
          throw Exception('Too many attempts. Please try again later.');
        default:
          throw Exception('Could not send the reset email: ${e.message}');
      }
    }
  }

  static String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Could not create the doctor account: ${e.message}';
    }
  }
}

/// A freshly created doctor login. Call [close] when everything succeeded,
/// or [rollback] if saving to Firestore failed afterwards.
class DoctorAccount {
  DoctorAccount._(this.uid, this._app, this._auth);

  final String uid;
  final FirebaseApp _app;
  final FirebaseAuth _auth;

  /// Normal finish: sign out of the temporary app and remove it.
  Future<void> close() async {
    await _auth.signOut();
    await _app.delete();
  }

  /// Undo: delete the account that was just created (the temporary app is
  /// still signed in as that user, so it is allowed to delete it).
  Future<void> rollback() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
    await close();
  }
}