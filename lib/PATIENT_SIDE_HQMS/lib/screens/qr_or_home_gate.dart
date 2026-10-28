import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'department_list_screen.dart';
import 'qr_scan_screen.dart';

/// Logged-in patient (OTP already verified) -> Home.
/// Not logged in -> QR scan screen.
class QrOrHomeGate extends StatelessWidget {
  const QrOrHomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FirebaseAuth.instance.currentUser != null
        ? const DepartmentListScreen()
        : const QRScanScreen();
  }
}