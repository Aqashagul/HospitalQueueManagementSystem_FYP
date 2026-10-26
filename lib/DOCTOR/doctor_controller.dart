import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_user.dart';


/// Doctor login / logout / availability.
/// The queue itself is NOT handled here: the doctor screen reuses your
/// existing DoctorQueueDetailPage + QueueAdminService.
class DoctorController {
  DoctorController._();

  /// Signs in and verifies the Firestore role. If the account is not a
  /// doctor, or the admin has removed its access, the user is signed out and
  /// an exception is thrown.
  static Future<AppUser> signIn(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      final uid = cred.user!.uid;
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final user = snap.exists ? AppUser.fromMap(uid, snap.data()!) : null;

      if (user == null ||
          user.role != UserRole.doctor ||
          user.doctorId == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not registered as a doctor.');
      }
      if (user.disabled) {
        await FirebaseAuth.instance.signOut();
        throw Exception(
          'Your access has been removed by the admin. '
          'Please contact the hospital.',
        );
      }

      await markActive(user.doctorId!);
      return user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Incorrect email or password.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'too-many-requests':
          throw Exception('Too many attempts. Please try again later.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    }
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  /// The first successful login turns an "invited" doctor into an "active"
  /// one, so the admin can see that the invitation was used. Never blocks the
  /// login if it fails.
  static Future<void> markActive(String doctorId) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('doctors').doc(doctorId);
      final snap = await ref.get();
      final status = snap.data()?['loginStatus'];
      if (status == null || status == 'invited') {
        await ref.update({
          'loginStatus': 'active',
          'activatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  /// Uses the existing doctors/{id}.status field ("Available" / "Unavailable"),
  /// the same one the admin form edits. Only this one field is written.
  static Future<void> setAvailable(String doctorId, bool value) {
    return FirebaseFirestore.instance
        .collection('doctors')
        .doc(doctorId)
        .update({'status': value ? 'Available' : 'Unavailable'});
  }
}