import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

/// Safe Firebase Messaging access when Firebase may be uninitialized.
class FirebaseGuard {
  FirebaseGuard._();

  static bool get messagingAvailable => DefaultFirebaseOptions.isConfigured;

  static Future<NotificationSettings?> messagingSettings() async {
    if (!messagingAvailable) return null;
    try {
      return await FirebaseMessaging.instance.getNotificationSettings();
    } catch (_) {
      return null;
    }
  }

  static Future<NotificationSettings?> requestMessagingPermission() async {
    if (!messagingAvailable) return null;
    try {
      return await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      return null;
    }
  }
}
