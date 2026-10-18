import 'package:flutter/material.dart';
import 'package:queue_management_system/call_patient.dart';
import 'confirm_action_dialog.dart';

// What happened to the patient, in words, for the popup.
String _actionText(String type) {
  switch (type) {
    case 'called':
      return 'was called in';
    case 'completed':
      return 'was marked as completed';
    case 'skipped':
      return 'was moved down the queue';
    case 'cancelled':
      return 'was removed from the queue';
    default:
      return 'was updated';
  }
}

/// Sends the notification and tells the admin what happened:
///  - sent: nothing to show.
///  - the patient cannot be reached through the app (app deleted, phone not
///    set up): a popup with the patient's details and a Call Now button.
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

  // The patient cannot be reached through the app: show who they are and
  // how to call them.
  if (result.patientUnreachable) {
    await showPatientUnreachableDialog(
      context,
      patientName: patientName,
      token: token,
      phone: phone.isNotEmpty ? phone : (result.phone ?? ''),
      actionText: _actionText(type),
      appRemoved: result.status == NotifyStatus.appRemoved,
    );
    return;
  }

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