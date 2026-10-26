import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/DOCTOR/doctor_controller.dart';
import 'app_user.dart';
import 'doctor_dashboard.dart';
import 'doctor_login_screen.dart';
import 'role_selection_screen.dart';



/// Reads users/{uid}. Returns null if the document does not exist.
Future<AppUser?> fetchAppUser(String uid) async {
  final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!snap.exists || snap.data() == null) return null;
  return AppUser.fromMap(uid, snap.data()!);
}

const _loader = Scaffold(body: Center(child: CircularProgressIndicator()));

// ======================================================================
// WEB: used inside AdminApp once a Firebase user is logged in.
//   role == admin                   -> adminHome (your AppShell)
//   role == doctor (not removed)    -> DoctorDashboard
//   anything else                   -> access denied + logout
// ======================================================================
class AdminRoleGate extends StatefulWidget {
  const AdminRoleGate({
    super.key,
    required this.uid,
    required this.adminHome,
  });

  final String uid;
  final Widget adminHome;

  @override
  State<AdminRoleGate> createState() => _AdminRoleGateState();
}

class _AdminRoleGateState extends State<AdminRoleGate> {
  late final Future<AppUser?> _future = fetchAppUser(widget.uid).then((u) {
    // The first successful doctor login turns "invited" into "active".
    if (u != null &&
        u.role == UserRole.doctor &&
        u.doctorId != null &&
        !u.disabled) {
      DoctorController.markActive(u.doctorId!);
    }
    return u;
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loader;

        final user = snap.data;
        if (user?.role == UserRole.admin) return widget.adminHome;

        if (user?.role == UserRole.doctor &&
            user?.doctorId != null &&
            !(user?.disabled ?? false)) {
          // On web, signing out triggers authChanges -> LoginScreen
          // automatically, so nothing else is needed in onLogout.
          return DoctorDashboard(doctorId: user!.doctorId!, onLogout: () {});
        }
        return const _AccessDenied();
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text('You do not have access to this dashboard.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// MOBILE: first open -> Patient/Doctor selection, then the right flow.
// Phone-auth users (patients) have a phoneNumber; email users (doctors)
// do not. That is how the two kinds of session are told apart here.
// ======================================================================
enum _Step { loading, selection, patient, doctorLogin, doctorHome }

class PatientRoleGate extends StatefulWidget {
  const PatientRoleGate({
    super.key,
    required this.splashScreen,
    required this.qrScreen,
  });

  /// Your existing first-time patient flow (SplashScreen).
  final Widget splashScreen;

  /// Your existing screen for already verified patients (QRScanScreen).
  final Widget qrScreen;

  @override
  State<PatientRoleGate> createState() => _PatientRoleGateState();
}

class _PatientRoleGateState extends State<PatientRoleGate> {
  _Step _step = _Step.loading;
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  void _go(_Step s) {
    if (mounted) setState(() => _step = s);
  }

  Future<void> _decide() async {
    final auth = FirebaseAuth.instance;
    var saved = await RoleStorage.read();
    final current = auth.currentUser;
    final isPhoneUser = current?.phoneNumber != null;

    // Patients who verified their phone before roles existed.
    if (saved == null && isPhoneUser) {
      await RoleStorage.save(UserRole.patient);
      saved = UserRole.patient;
    }

    if (saved == UserRole.patient) {
      // A leftover doctor (email) session must not open the patient flow.
      if (current != null && !isPhoneUser) await auth.signOut();
      _go(_Step.patient);
    } else if (saved == UserRole.doctor) {
      if (current != null && !isPhoneUser) {
        final user = await fetchAppUser(current.uid);
        if (user?.role == UserRole.doctor &&
            user?.doctorId != null &&
            !(user?.disabled ?? false)) {
          _doctorId = user!.doctorId;
          _go(_Step.doctorHome);
          return;
        }
        await auth.signOut();
      }
      _go(_Step.doctorLogin);
    } else {
      _go(_Step.selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.loading:
        return _loader;

      case _Step.selection:
        // RoleSelectionScreen saves the role first, then calls these.
        return RoleSelectionScreen(onPatient: _decide, onDoctor: _decide);

      case _Step.patient:
        return FirebaseAuth.instance.currentUser != null
            ? widget.qrScreen
            : widget.splashScreen;

      case _Step.doctorLogin:
        return DoctorLoginScreen(
          onLoggedIn: (user) {
            _doctorId = user.doctorId;
            _go(_Step.doctorHome);
          },
          onBack: () async {
            await RoleStorage.clear();
            _go(_Step.selection);
          },
        );

      case _Step.doctorHome:
        return DoctorDashboard(
          doctorId: _doctorId!,
          onLogout: () => _go(_Step.doctorLogin),
        );
    }
  }
}