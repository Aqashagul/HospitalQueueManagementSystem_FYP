import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _workerUrl = 'https://queue-notifier.hqms.workers.dev';

/// Lets the admin change an EXISTING doctor's login (email and/or password).
///
/// This cannot be done from the app itself (Firebase only allows it with
/// admin rights), so the request goes to the Cloudflare Worker, which checks
/// that the caller is an admin and that the account belongs to a doctor.
class DoctorLoginAdmin {
  DoctorLoginAdmin._();

  /// Changes the login of the doctor with Firebase Auth id [uid].
  /// Throws an Exception with a readable message when it fails.
  static Future<void> update(
    String uid, {
    String? email,
    String? password,
  }) async {
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
            Uri.parse('$_workerUrl/doctor-login'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'uid': uid,
              'email': ?email,
              'password': ?password,
            }),
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

    switch (res.statusCode) {
      case 401:
        throw Exception('Your session has expired. Please sign in again.');
      case 403:
        throw Exception(
          body['message']?.toString() ??
              'You are not allowed to change this login.',
        );
    }

    throw Exception(
      body['message']?.toString() ?? 'Could not update the doctor login.',
    );
  }
}