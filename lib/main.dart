import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:queue_management_system/BACKEND/auth_service.dart';
import 'package:queue_management_system/DOCTOR/role_gatway.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/qr_scan_screen.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/splash_screen.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/notification_service.dart';
import 'package:queue_management_system/screens/auth/login_page.dart';
import 'package:queue_management_system/screens/layout/app_shell.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await NotificationService.init();
  if (FirebaseAuth.instance.currentUser != null) {
    NotificationService.saveToken().catchError((_) {});
  }

  // Mobile app (patient / doctor).
  if (!kIsWeb) {
    AppdataStore().startListening();

    // Wait until Firebase has restored any saved session, so PatientRoleGate
    // sees the correct currentUser on the first frame.
    await FirebaseAuth.instance.authStateChanges().first;
  }

  runApp(kIsWeb ? const AdminApp() : const PatientApp());
}

/// Web: admin + doctor dashboard.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppdataStore(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // logged out -> login screen
        // logged in  -> AdminRoleGate checks the Firestore role:
        //               admin -> AppShell, doctor -> DoctorDashboard
        home: StreamBuilder<User?>(
          stream: AuthService().authChanges,
          builder: (context, snapshot) {
            // Firebase is still checking the saved session
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return AdminRoleGate(
                key: ValueKey(snapshot.data!.uid),
                uid: snapshot.data!.uid,
                adminHome: const AppShell(),
              );
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

/// Mobile: first open asks Patient / Doctor, then opens the right flow.
class PatientApp extends StatelessWidget {
  const PatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PatientRoleGate(
        splashScreen: SplashScreen(),
        qrScreen: const QRScanScreen(),
      ),
    );
  }
}