import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/firebase_guard.dart';
import '../core/notification_navigation.dart';
import '../core/root_scaffold_messenger.dart';
import '../firebase_options.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || !FirebaseGuard.messagingAvailable) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await FirebaseGuard.requestMessagingPermission();

    await _registerCurrentToken(messaging);
    messaging.onTokenRefresh.listen(_uploadToken);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _openFromMessage(initial);
    }
  }

  static Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _uploadToken(token);
      }
    } catch (_) {}
  }

  static Future<void> _uploadToken(String token) async {
    try {
      await ApiService.registerFcmToken(token);
    } catch (_) {}
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title'] as String? ?? 'Notification';
    final body =
        message.notification?.body ?? message.data['body'] as String? ?? '';
    final deepLink = message.data['deep_link'] as String?;

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E222A),
        content: Text(
          body.isNotEmpty ? '$title: $body' : title,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        ),
        action: deepLink != null
            ? SnackBarAction(
                label: 'Open',
                textColor: const Color(0xFFFF6B00),
                onPressed: () => _openDeepLink(deepLink),
              )
            : null,
      ),
    );
  }

  static void _onMessageOpened(RemoteMessage message) {
    _openFromMessage(message);
  }

  static void _openFromMessage(RemoteMessage message) {
    final deepLink = message.data['deep_link'] as String?;
    _openDeepLink(deepLink);
  }

  static void _openDeepLink(String? deepLink) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    openTournamentDeepLink(context, deepLink);
  }
}
