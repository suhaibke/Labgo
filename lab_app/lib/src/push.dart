import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_state.dart';

/// Push notifications for the lab app (Firebase Cloud Messaging).
///
/// Started after sign-in: asks permission, registers this phone with the
/// server, and refreshes the notification list when one arrives. It does
/// nothing on the web, or until the Firebase config files are added
/// (ios/Runner/GoogleService-Info.plist and android/app/google-services.json),
/// so the app runs the same without them.
class LabPush {
  LabPush._();

  static bool _started = false;
  static final List<StreamSubscription<dynamic>> _subs = [];

  static Future<void> start(AppState app) async {
    if (_started || kIsWeb || !LabApi.enabled || !LabApi.instance.signedIn) return;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    if (platform == null) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push: Firebase not configured ($e)');
      return;
    }
    _started = true;
    final fcm = FirebaseMessaging.instance;
    try {
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      // Show banners while the app is open too (iOS).
      await fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      final token = await fcm.getToken();
      if (token != null) await LabApi.instance.registerPushToken(token, platform);
    } catch (e) {
      debugPrint('Push: registration failed ($e)');
    }
    _subs
      ..add(fcm.onTokenRefresh.listen((t) => LabApi.instance.registerPushToken(t, platform).catchError((_) {})))
      // A notification while the app is open: the bell list catches up.
      ..add(FirebaseMessaging.onMessage.listen((_) => app.loadNotifications()))
      // Tapped from the phone's notification centre: open the list.
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((_) => _openList(app)));
    final initial = await fcm.getInitialMessage().catchError((_) => null);
    if (initial != null) _openList(app);
  }

  static void _openList(AppState app) {
    app.loadNotifications();
    app.openNotifications(true);
  }

  /// On sign-out: this phone stops receiving the account's notifications.
  static Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (!_started) return;
    _started = false;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
