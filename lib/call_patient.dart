import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _workerUrl = 'https://queue-notifier.hqms.workers.dev';

/// What happened when we tried to notify a patient.
enum NotifyStatus {
  /// The notification was sent.
  sent,

  /// The patient deleted the app (or cleared its data), so the phone cannot
  /// receive notifications any more.
  appRemoved,

  /// The patient's phone never registered for notifications (the app was
  /// never opened on a phone, or notifications were refused).
  notRegistered,

  /// No internet, or the notification server did not answer in time.
  noInternet,

  /// The admin's login expired, or the account is not allowed to do this.
  notAllowed,

  /// The notification service had a problem. Trying again usually works.
  serviceError,

  /// Anything else.
  failed,
}

/// The outcome of [sendPatientNotification].
class NotifyResult {
  final NotifyStatus status;

  /// A short message the admin can read.
  final String message;

  /// The patient's phone number, when the server knows it.
  final String? phone;

  const NotifyResult(this.status, this.message, {this.phone});

  bool get sent => status == NotifyStatus.sent;

  /// True when the patient cannot be reached through the app, so the admin
  /// should contact them by phone.
  bool get patientUnreachable =>
      status == NotifyStatus.appRemoved || status == NotifyStatus.notRegistered;

  /// True when trying again can help.
  bool get canRetry =>
      status == NotifyStatus.noInternet || status == NotifyStatus.serviceError;
}

/// Asks the Worker to send a push notification to the patient of this queue
/// entry. [type] is one of: 'called', 'completed', 'skipped', 'cancelled'.
///
/// For 'cancelled' the queue entry is already deleted, so pass [patientId]
/// and [token] (taken before deleting) and the Worker uses those instead.
///
/// Never throws: every problem comes back as a [NotifyResult].
Future<NotifyResult> sendPatientNotification(
  String entryId,
  String type, {
  String? patientId,
  String? token,
}) async {
  // 1) The admin's login token.
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const NotifyResult(
      NotifyStatus.notAllowed,
      'Your session has expired. Please sign in again.',
    );
  }

  String? idToken;
  try {
    idToken = await user.getIdToken();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'network-request-failed') {
      return const NotifyResult(
        NotifyStatus.noInternet,
        'No internet connection, so the patient could not be notified.',
      );
    }
    return const NotifyResult(
      NotifyStatus.notAllowed,
      'Your session has expired. Please sign in again.',
    );
  } catch (_) {
    return const NotifyResult(
      NotifyStatus.failed,
      'Could not start sending the notification.',
    );
  }
  if (idToken == null) {
    return const NotifyResult(
      NotifyStatus.notAllowed,
      'Your session has expired. Please sign in again.',
    );
  }

  // 2) Ask the Worker.
  http.Response res;
  try {
    res = await http
        .post(
          Uri.parse(_workerUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'entryId': entryId,
            'type': type,
            'patientId': ?patientId,
            'token': ?token,
          }),
        )
        .timeout(const Duration(seconds: 15));
  } on TimeoutException {
    return const NotifyResult(
      NotifyStatus.noInternet,
      'The notification server did not respond in time. '
      'Please check your internet connection.',
    );
  } on http.ClientException {
    return const NotifyResult(
      NotifyStatus.noInternet,
      'No internet connection, so the patient could not be notified.',
    );
  } catch (e) {
    debugPrint('sendPatientNotification failed: $e');
    return const NotifyResult(
      NotifyStatus.failed,
      'Could not reach the notification server.',
    );
  }

  debugPrint('Worker response ${res.statusCode}: ${res.body}');

  Map<String, dynamic> body = {};
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {}

  // 3) Understand the answer.
  switch (res.statusCode) {
    case 200:
      break;
    case 401:
      return const NotifyResult(
        NotifyStatus.notAllowed,
        'Your session has expired. Please sign in again.',
      );
    case 403:
      return const NotifyResult(
        NotifyStatus.notAllowed,
        'Only an admin can send notifications to patients.',
      );
    case 404:
      return const NotifyResult(
        NotifyStatus.failed,
        'This queue entry no longer exists, so no notification was sent.',
      );
    default:
      if (res.statusCode >= 500) {
        return const NotifyResult(
          NotifyStatus.serviceError,
          'The notification service had a problem. Please try again.',
        );
      }
      final detail = body['error'] ?? '';
      return NotifyResult(
        NotifyStatus.failed,
        'Could not send notification (${res.statusCode}) $detail'.trim(),
      );
  }

  if (body['ok'] == true) {
    return const NotifyResult(NotifyStatus.sent, '');
  }

  final String? phone = body['phone']?.toString();
  final String callHint = (phone == null || phone.isEmpty) ? '' : ' ($phone)';

  switch (body['reason']) {
    case 'unregistered':
      return NotifyResult(
        NotifyStatus.appRemoved,
        "The patient's app is no longer installed on their phone, so they "
        'could not be notified. Please contact them by phone$callHint.',
        phone: phone,
      );
    case 'no-fcm-token':
      return NotifyResult(
        NotifyStatus.notRegistered,
        "The patient's phone is not set up for notifications, so they "
        'could not be notified. Please contact them by phone$callHint.',
        phone: phone,
      );
    case 'no-patient-id':
      return const NotifyResult(
        NotifyStatus.failed,
        'This queue entry has no patient attached, so no notification was sent.',
      );
  }

  // The Worker answered 200 but FCM refused for another reason.
  if (body['fcmError'] != null) {
    return const NotifyResult(
      NotifyStatus.serviceError,
      'The notification service could not deliver the message. '
      'Please try again.',
    );
  }

  return const NotifyResult(
    NotifyStatus.failed,
    'Could not send notification.',
  );
}

/// Older helper, kept so existing code keeps working: returns null when the
/// notification was sent, otherwise a message.
Future<String?> notifyPatient(
  String entryId,
  String type, {
  String? patientId,
  String? token,
}) async {
  final result = await sendPatientNotification(
    entryId,
    type,
    patientId: patientId,
    token: token,
  );
  return result.sent ? null : result.message;
}

/// "It's your turn" notification (kept so older code keeps working).
Future<String?> notifyCalledPatient(String entryId) =>
    notifyPatient(entryId, 'called');