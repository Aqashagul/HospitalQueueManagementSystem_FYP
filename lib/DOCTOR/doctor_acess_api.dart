import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _workerUrl = 'https://queue-notifier.hqms.workers.dev';

/// Admin actions on a doctor's access to the app. They all go through the
/// Cloudflare Worker, which checks that the caller is an admin and uses
/// Firebase's admin rights (the app itself is not allowed to do these).
///
/// Every method throws an Exception with a readable message when it fails.
class DoctorAccessApi {
  DoctorAccessApi._();

  /// Gives the doctor access: creates their login (with a random password that
  /// nobody sees) and emails them a link to choose their own password.
  /// Also used to invite a doctor AGAIN after their access was removed.
  ///
  /// Returns false when the access was set up but the email could not be sent
  /// (the doctor can tap "Forgot password?" on the login screen).
  static Future<bool> invite(String doctorId, String email) async {
    final body = await _post('/doctor-invite', {
      'doctorId': doctorId,
      'email': email.trim(),
    });
    return body['emailSent'] == true;
  }

  /// Cancels an invitation, or removes access from a doctor who already uses
  /// the app. The login is disabled and the doctor is logged out everywhere.
  static Future<void> revoke(String doctorId) async {
    await _post('/doctor-access', {'action': 'revoke', 'doctorId': doctorId});
  }

  /// Undoes [revoke]. A doctor who was using the app gets access back at once;
  /// for a cancelled invitation the status is cleared so a new invitation can
  /// be sent.
  static Future<void> restore(String doctorId) async {
    await _post('/doctor-access', {'action': 'restore', 'doctorId': doctorId});
  }

  /// Deletes the doctor's login completely (used when the doctor is deleted),
  /// so the same email can be used again.
  static Future<void> deleteLogin(String uid) async {
    await _post('/doctor-access', {'action': 'delete', 'uid': uid});
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
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
            Uri.parse('$_workerUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
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

    if (res.statusCode == 200 && body['ok'] == true) return body;

    switch (res.statusCode) {
      case 401:
        throw Exception('Your session has expired. Please sign in again.');
      case 403:
        throw Exception(
          body['message']?.toString() ?? 'You are not allowed to do this.',
        );
    }

    throw Exception(
      body['message']?.toString() ?? 'Something went wrong. Please try again.',
    );
  }
}