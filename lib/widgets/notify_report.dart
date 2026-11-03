import 'package:flutter/material.dart';
import 'package:queue_management_system/call_patient.dart';


// notifyAndReport: REPLACE the old function with this one, and DELETE the
// small `_actionText(String type)` function above it (it is not used any more).

/// Sends the notification and tells the admin what happened:
///  - sent: nothing to show.
///  - the patient cannot be reached through the app (app deleted, logged out,
///    phone not set up): nothing is shown at all. The queue action itself
///    already worked.
///  - no internet / server problem: an orange message with a Retry button.
///  - anything else: an orange message.
///
/// The queue action itself (call, complete...) has already happened by the
/// time this runs, so these messages are only about the notification.
Future<void> notifyAndReport(
  BuildContext context,
  String entryId,
  String type, {
  required String patientName,
  required String token,
  required String phone,
  String? patientId,
}) async {
  final result = await sendPatientNotification(
    entryId,
    type,
    patientId: patientId,
    token: token,
  );

  if (result.sent || !context.mounted) return;

  // App deleted / logged out / phone not set up for notifications: stay quiet.
  if (result.patientUnreachable) return;

  // Everything else: a message, with Retry when trying again can help.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 8),
        action: result.canRetry
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => notifyAndReport(
                  context,
                  entryId,
                  type,
                  patientName: patientName,
                  token: token,
                  phone: phone,
                  patientId: patientId,
                ),
              )
            : null,
      ),
    );
}