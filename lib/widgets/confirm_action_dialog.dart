import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


/// A clean confirmation popup used before an action (call, complete, skip,
/// cancel, delete...). Returns true when the user confirms, false when they
/// cancel or tap outside.
///
/// The popup is narrow (max 380 px), with a coloured icon on top, a short
/// message, an optional info card, and two equal buttons.
///
/// The info card is built from [token] and [patientName], or pass your own
/// widget in [content] (for example a [DialogInfoCard]).
Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  String? token,
  String? patientName,
  Widget? content,
}) async {
  final Widget? card = content ??
      ((token != null || patientName != null)
          ? DialogInfoCard(badge: token, title: patientName)
          : null);

  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (dialogContext) {
      return _DialogShell(
        icon: icon,
        color: color,
        title: title,
        message: message,
        content: card,
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  cancelLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  return result == true;
}

/// The same style of popup, but only informs (one button). Used when an action
/// is not allowed, for example "Cannot delete this doctor".
Future<void> showNoticeDialog(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  String buttonLabel = 'Got it',
  Widget? content,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (dialogContext) {
      return _DialogShell(
        icon: icon,
        color: color,
        title: title,
        message: message,
        content: content,
        actions: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    },
  );
}

/// Popup shown when a patient could not be notified because their app was
/// deleted (or their phone is not set up for notifications). It shows the
/// patient's profile and number (with a copy button) and a Close button.
///
/// [actionText] says what happened to the patient, for example
/// "was called in".
Future<void> showPatientUnreachableDialog(
  BuildContext context, {
  required String patientName,
  required String token,
  required String phone,
  required String actionText,
  required bool appRemoved,
}) async {
  final String reason = appRemoved
      ? 'their app is no longer installed on their phone'
      : 'their phone is not set up for notifications';
  final String name = patientName.isEmpty ? 'The patient' : patientName;
  final Color color = Colors.orange.shade700;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (dialogContext) {
      return _DialogShell(
        icon: Icons.phonelink_erase_rounded,
        color: color,
        title: 'Patient Could Not Be Notified',
        message: '$name $actionText, but $reason, so they did not receive '
            'the notification. Please contact them by phone.',
        content: _PatientProfileCard(
          name: patientName,
          token: token,
          phone: phone,
        ),
        actions: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    },
  );
}

// The shared look of the popups: card, icon badge, title, message, an
// optional content block, and the buttons.
class _DialogShell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? content;
  final Widget actions;

  const _DialogShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actions,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coloured icon badge
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 29),
                ),
                const SizedBox(height: 18),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),

                if (content != null) ...[
                  const SizedBox(height: 16),
                  content!,
                ],

                const SizedBox(height: 24),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// The patient's profile inside the "could not be notified" popup: initials,
// name, token, and the phone number with a copy button.
class _PatientProfileCard extends StatefulWidget {
  final String name;
  final String token;
  final String phone;

  const _PatientProfileCard({
    required this.name,
    required this.token,
    required this.phone,
  });

  @override
  State<_PatientProfileCard> createState() => _PatientProfileCardState();
}

class _PatientProfileCardState extends State<_PatientProfileCard> {
  bool _copied = false;

  String get _initials {
    final words = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.phone));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhone = widget.phone.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Name and token
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4D9F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B46C1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name.isEmpty ? 'Unknown patient' : widget.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.token.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Token ${widget.token}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Phone number
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            child: Row(
              children: [
                Icon(Icons.phone_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    hasPhone ? widget.phone : 'No phone number on file',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasPhone ? null : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (hasPhone)
                  IconButton(
                    onPressed: _copy,
                    tooltip: _copied ? 'Copied' : 'Copy number',
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 18,
                      color: _copied
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small card for a popup: an optional badge (like a token or a department)
/// next to a title, with an optional line under it.
class DialogInfoCard extends StatelessWidget {
  final String? badge;
  final String? title;
  final String? subtitle;

  const DialogInfoCard({super.key, this.badge, this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final bool hasBadge = badge != null && badge!.isNotEmpty;
    final bool hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (hasBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          if (hasBadge && title != null) const SizedBox(width: 12),
          if (title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A small list card for a popup: one row per item, with the name on the left
/// and a value on the right (for example "Dr. Sana    2 patients").
class DialogListCard extends StatelessWidget {
  final List<MapEntry<String, String>> rows;

  const DialogListCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}