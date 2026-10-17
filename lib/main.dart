import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:queue_management_system/BACKEND/auth_service.dart';
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

  // Declared here (outside the if) so runApp below can use it.
  bool isLoggedIn = false;

  // Patient app (mobile/desktop).
  if (!kIsWeb) {
    AppdataStore().startListening();

    // Firebase remembers a verified phone number on this device, so this is
    // true on every launch after the first successful OTP.
    final user = await FirebaseAuth.instance.authStateChanges().first;
    isLoggedIn = user != null;
  }

  runApp(kIsWeb ? const AdminApp() : PatientApp(isLoggedIn: isLoggedIn));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppdataStore(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Listens to Firebase login state:
        // logged in -> dashboard, logged out -> login screen.
        home: StreamBuilder<User?>(
          stream: AuthService().authChanges,
          builder: (context, snapshot) {
            // Firebase is still checking the saved session
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // A user is logged in, so skip the login screen
            if (snapshot.hasData) {
              return const AppShell();
            }
            // Nobody is logged in
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class PatientApp extends StatelessWidget {
  // True when the patient has already verified their phone number.
  final bool isLoggedIn;

  const PatientApp({super.key, this.isLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Already verified: go straight to the QR page.
      // First time: the normal flow (splash -> phone number -> OTP).
      home: isLoggedIn ? const QRScanScreen() : SplashScreen(),
    );
  }
}