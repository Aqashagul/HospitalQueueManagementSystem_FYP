import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _workerUrl = 'https://queue-notifier.hqms.workers.dev';

/// Asks the Worker to send a push notification to the patient of this
/// queue entry. [type] is one of: 'called', 'completed', 'skipped',
/// 'cancelled'.
///
/// For 'cancelled' the queue entry is already deleted, so pass [patientId]
/// and [token] (taken before deleting) and the Worker uses those instead.
///
/// Returns null on success, otherwise a message to show to the admin.
Future<String?> notifyPatient(
  String entryId,
  String type, {
  String? patientId,
  String? token,
}) async {
  try {
    final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();

    final res = await http
        .post(
          Uri.parse(_workerUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'entryId': entryId,
            'type': type,
            if (patientId != null) 'patientId': patientId,
            if (token != null) 'token': token,
          }),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('Worker response ${res.statusCode}: ${res.body}');

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode != 200) {
      final detail = body['error'] ?? body['fcmError'] ?? '';
      return 'Could not send notification (${res.statusCode}) $detail'.trim();
    }

    if (body['ok'] == true) return null;

    // Phone number of the patient, so the admin can call them instead.
    final phone = body['phone']?.toString() ?? '';
    final callHint = phone.isEmpty ? '' : ' ($phone)';

    switch (body['reason']) {
      case 'unregistered':
        return "The patient's app is no longer installed on their phone, "
            'so they could not be notified. '
            'Please contact them by phone$callHint.';
      case 'no-fcm-token':
        return "The patient's phone is not set up for notifications, "
            'so they could not be notified. '
            'Please contact them by phone$callHint.';
      case 'no-patient-id':
        return 'This queue entry has no patientId.';
      default:
        return 'Could not send notification.';
    }
  } catch (e) {
    debugPrint('notifyPatient failed: $e');
    return 'Could not reach the notification server: $e';
  }
}

/// "It's your turn" notification (kept so older code keeps working).
Future<String?> notifyCalledPatient(String entryId) =>
    notifyPatient(entryId, 'called');