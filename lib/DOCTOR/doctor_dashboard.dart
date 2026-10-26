import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/screens/doctor_queue_page.dart';
import 'doctor_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';



/// The doctor's home screen. It reuses your existing DoctorQueueDetailPage,
/// so a doctor gets exactly the same queue, actions, confirm dialogs and
/// patient notifications that the admin already has, for their own queue.
///
/// It also watches the doctor's own users/{uid} document: if the admin removes
/// their access while the app is open, the doctor is logged out at once.
///
/// NEW: a top bar ("Dr. Raza's Queue") with a profile button. The profile
/// sheet has Change email, Change password and Log out (with a confirmation).
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({
    super.key,
    required this.doctorId,
    required this.onLogout,
  });

  final String doctorId;
  final VoidCallback onLogout;

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSub;
  bool _revokedHandled = false;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    // Loads doctors/departments into AppdataStore. Safe to call twice.
    AppdataStore().startListening();
    _watchAccess();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _accessSub?.cancel();
    super.dispose();
  }

  // The admin screen shows "Doctor is managing this queue" while this app is
  // open. For that, doctor_presence/{doctorId}.lastSeen is refreshed every
  // minute. It lives in its own small collection, so it does not wake up
  // everyone who listens to the doctors list.
  void _startHeartbeat() {
    _beat();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => _beat());
  }

  Future<void> _beat() async {
    try {
      await FirebaseFirestore.instance
          .collection('doctor_presence')
          .doc(widget.doctorId)
          .set({'lastSeen': FieldValue.serverTimestamp()});
    } catch (_) {
      // Best effort: the queue itself must never depend on this.
    }
  }

  // On logout the badge should disappear straight away.
  Future<void> _clearPresence() async {
    _heartbeat?.cancel();
    try {
      await FirebaseFirestore.instance
          .collection('doctor_presence')
          .doc(widget.doctorId)
          .delete();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _beat();
  }

  void _watchAccess() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _accessSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      // A missing document from the local cache is not proof of removal.
      if (!snap.exists && snap.metadata.isFromCache) return;

      final bool revoked = !snap.exists || snap.data()?['disabled'] == true;
      if (revoked && !_revokedHandled) {
        _revokedHandled = true;
        _onAccessRemoved();
      }
    }, onError: (_) {});
  }

  Future<void> _onAccessRemoved() async {
    final onLogout = widget.onLogout;

    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Access removed'),
          content: const Text(
            'The admin has removed your access to MediQueue. '
            'Please contact the hospital if you think this is a mistake.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    await DoctorController.signOut();
    if (kIsWeb) await AppdataStore().stopListening();
    onLogout();
  }

  void _snack(String message, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : const Color(0xFF2E7D32),
        ),
      );
  }

  Future<void> _setAvailable(bool value) async {
    try {
      await DoctorController.setAvailable(widget.doctorId, value);
    } catch (_) {
      _snack('Could not change availability. Please try again.');
    }
  }

  // Asks for confirmation, then logs the doctor out.
  Future<void> _logout() async {
    final onLogout = widget.onLogout;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of MediQueue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Log out',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _clearPresence();
    await DoctorController.signOut();
    // On web the admin app starts its own listeners after the next login.
    if (kIsWeb) await AppdataStore().stopListening();
    onLogout();
  }

  // ---------------------------------------------------------------------
  // Top bar + profile sheet
  // ---------------------------------------------------------------------

  static final RegExp _drPrefix =
      RegExp(r'^dr(\.\s*|\s+)', caseSensitive: false);

  // "Dr.Sana" / "Sana" / "Dr. Sana"  ->  "Dr. Sana's Queue"
  String _queueTitle(String name) {
    final n = name.trim();
    final bare = n.replaceFirst(_drPrefix, '');
    return "Dr. $bare's Queue";
  }

  String _initialOf(String name) {
    final bare = name.trim().replaceFirst(_drPrefix, '');
    return bare.isEmpty ? 'D' : bare.characters.first.toUpperCase();
  }

  // "cardiology" / "CARDIOLOGY" -> "Cardiology"
  String _titleCase(String s) {
    return s
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _profileAvatar(DoctorModel doc, double radius) {
    final bytes = doc.photoBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.12),
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              _initialOf(doc.name),
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.9,
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(DoctorModel doc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _queueTitle(doc.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (doc.department.isNotEmpty)
                      Text(
                        _titleCase(doc.department),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openProfileSheet(doc),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _profileAvatar(doc, 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.grey.shade800),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color ?? Colors.black87,
        ),
      ),
      trailing: color == null
          ? Icon(Icons.chevron_right, color: Colors.grey.shade500)
          : null,
      onTap: onTap,
    );
  }

  void _openProfileSheet(DoctorModel doc) {
    final String email =
        FirebaseAuth.instance.currentUser?.email ?? doc.email ?? '';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _profileAvatar(doc, 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              _sheetTile(
                icon: Icons.alternate_email,
                label: 'Change email',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openChangeEmail(email);
                },
              ),
              _sheetTile(
                icon: Icons.lock_outline,
                label: 'Change password',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openChangePassword();
                },
              ),
              const Divider(),
              _sheetTile(
                icon: Icons.logout,
                label: 'Log out',
                color: Colors.red.shade600,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChangePassword() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (done == true) _snack('Password changed successfully.', error: false);
  }

  Future<void> _openChangeEmail(String currentEmail) async {
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeEmailDialog(currentEmail: currentEmail),
    );
    if (newEmail != null) {
      _snack(
        'Verification link sent to $newEmail. '
        'Your email changes after you open it.',
        error: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppdataStore(),
      builder: (context, _) {
        final store = AppdataStore();

        if (!store.doctorsLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final matches = store.doctors.where((d) => d.id == widget.doctorId);
        if (matches.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your doctor profile was not found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _logout, child: const Text('Logout')),
                ],
              ),
            ),
          );
        }

        final DoctorModel doc = matches.first;
        final bool available = doc.status.toLowerCase() == 'available';

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: Column(
            children: [
              _buildHeader(doc),
              Expanded(
                // The header already handles the status bar, so the queue
                // page below must not add that space a second time.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: DoctorQueueDetailPage(
                    key: ValueKey(doc.id),
                    doctorName: doc.name,
                    department: doc.department,
                    showBack: false,
                    doctorMode: true,
                    // The page shows this switch inside its
                    // "Accepting patients" card.
                    topBarTrailing: Switch(
                      value: available,
                      activeThumbColor: AppColors.primaryPurple,
                      onChanged: _setAvailable,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// Shared helpers for the two dialogs below
// =========================================================================

String _authErrorText(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Your current password is incorrect.';
    case 'weak-password':
      return 'New password is too weak. Use at least 6 characters.';
    case 'email-already-in-use':
      return 'This email is already used by another account.';
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Please check your internet connection.';
    case 'requires-recent-login':
      return 'Please log out and log in again, then try once more.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

InputDecoration _fieldDecoration(String label, {Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    suffixIcon: suffix,
  );
}

/// Password input with a show / hide eye.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.action = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction action;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.action,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: _fieldDecoration(
        widget.label,
        suffix: IconButton(
          icon: Icon(
            _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

Widget _dialogMessage(String? error, String? info) {
  if (error == null && info == null) return const SizedBox.shrink();
  final bool isError = error != null;
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      error ?? info!,
      style: TextStyle(
        fontSize: 13,
        color: isError ? Colors.redAccent : const Color(0xFF2E7D32),
      ),
    ),
  );
}

Widget _saveButtonChild(bool busy, String label) {
  return busy
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
        )
      : Text(label);
}

// =========================================================================
// Change password: Current / New / Confirm (the old password is never shown)
// =========================================================================
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final current = _current.text;
    final next = _new.text;

    String? problem;
    if (current.isEmpty) {
      problem = 'Enter your current password.';
    } else if (next.length < 6) {
      problem = 'New password must be at least 6 characters.';
    } else if (next == current) {
      problem = 'New password must be different from the current one.';
    } else if (next != _confirm.text) {
      problem = 'New passwords do not match.';
    }
    if (problem != null) {
      setState(() {
        _error = problem;
        _info = null;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'You are not logged in.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      // Prove it is really the doctor, then set the new password.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(next);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _authErrorText(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  // "Forgot password?": emails a reset link to the doctor's own address.
  Future<void> _forgot() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _busy = false;
          _info = 'Password reset link sent to $email.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _authErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PasswordField(controller: _current, label: 'Current password'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgot,
                child: const Text('Forgot password?'),
              ),
            ),
            _PasswordField(controller: _new, label: 'New password'),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              action: TextInputAction.done,
              onSubmitted: _submit,
            ),
            _dialogMessage(_error, _info),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _saveButtonChild(_busy, 'Save'),
        ),
      ],
    );
  }
}

// =========================================================================
// Change email: needs the current password, then Firebase sends a
// verification link to the NEW address. The email changes only after the
// doctor opens that link.
// =========================================================================
class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({required this.currentEmail});

  final String currentEmail;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _newEmail = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _newEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final next = _newEmail.text.trim();

    String? problem;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(next)) {
      problem = 'Enter a valid email address.';
    } else if (next.toLowerCase() == widget.currentEmail.toLowerCase()) {
      problem = 'This is already your email.';
    } else if (_password.text.isEmpty) {
      problem = 'Enter your current password.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() => _error = 'You are not logged in.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: _password.text),
      );
      await user.verifyBeforeUpdateEmail(next);
      if (mounted) Navigator.pop(context, next);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _authErrorText(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current email',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.currentEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newEmail,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('New email'),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _password,
              label: 'Current password',
              action: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 10),
            Text(
              'We will send a verification link to the new email. '
              'Your email changes after you open it.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            _dialogMessage(_error, null),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _saveButtonChild(_busy, 'Send link'),
        ),
      ],
    );
  }
}