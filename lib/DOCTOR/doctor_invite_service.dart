import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _workerUrl = 'https://queue-notifier.hqms.workers.dev';

/// Asks the Cloudflare Worker to email a doctor an account setup link
/// (Firebase's "Reset your password" email, used to choose a password).
/// The Worker reads the doctor's name and email from Firestore, so only the
/// doctor id is sent.
///
/// The same call is used for the first setup link and for "Resend":
/// a new link replaces the old one, so the old link stops working.
class DoctorInviteService {
  DoctorInviteService._();

  /// Throws an Exception with a readable message when it fails.
  static Future<void> send(String doctorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    String? idToken;
    try {
      idToken = await user.getIdToken();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw Exception('No internet connection. Please try again.');
      }
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (idToken == null) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_workerUrl/invite-doctor'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'doctorId': doctorId}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception(
        'The server did not respond in time. Please check your internet connection.',
      );
    } on http.ClientException {
      throw Exception('No internet connection. Please try again.');
    }

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode == 200 && body['ok'] == true) return;

    if (res.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    throw Exception(
      body['message']?.toString() ?? 'Could not send the account setup link.',
    );
  }
}