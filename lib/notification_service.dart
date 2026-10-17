import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background / terminated state mein notification Android khud dikha deta hai.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _tokenListenerAdded = false;

  static const _channel = AndroidNotificationChannel(
    'queue_channel',
    'Queue Alerts',
    description: 'Alerts when it is your turn',
    importance: Importance.high,
  );

  /// main.dart mein Firebase.initializeApp ke baad ek dafa call karein.
  /// Web (admin dashboard) par ye kuch nahi karta.
  static Future<void> init() async {
    if (kIsWeb) return;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App khuli ho (foreground) to Android khud notification nahi dikhata,
    // isliye yahan se dikhate hain.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        id: n.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  /// Patient login hone ke baad call karein: is phone ka token
  /// users/{uid}.fcmToken mein save karta hai.
  static Future<void> saveToken() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    if (token != null) {
      await ref.update({'fcmToken': token});
    }

    if (!_tokenListenerAdded) {
      _tokenListenerAdded = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) return;
        FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .update({'fcmToken': t});
      });
    }
  }
}