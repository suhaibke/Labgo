import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'order_service.dart';
import 'notification_destination.dart';
import '../screens/main/main_screen.dart';
import '../screens/order/order_details_screen.dart';
import '../utils/cities.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _fcmTokenKey = 'fcm_token';
  static const String _topicsKey = 'subscribed_topics';

  // Notification channel IDs
  static const String _defaultChannelId = 'labgo_notifications';
  static const String _ordersChannelId = 'labgo_orders';
  static const String _offersChannelId = 'labgo_offers';
  static const String _resultsChannelId = 'labgo_results';

  // Topic names
  static const String topicAllPatients = 'all_patients';
  static String topicNurseCity(String city) =>
      'nurse_city_${_cityTopicKey(city)}';
  static String topicPatientCity(String city) =>
      'patient_city_${_cityTopicKey(city)}';

  bool _initialized = false;

  /// Initialize FCM - call in main.dart. Idempotent: getAndSaveToken() also
  /// calls this itself (see below) since it's the only thing that actually
  /// asks iOS to request permission and register for remote notifications -
  /// AuthService.login()/register() call getAndSaveToken() directly without
  /// ever guaranteeing this ran first, and calling getToken() before iOS
  /// has even been asked to register leaves APNS with nothing to ever
  /// deliver, which is exactly the failure a production client-debug-log
  /// report showed (retrying getAPNSToken() for 5s still returned null).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions
    await _requestPermissions();

    // iOS: allow system banners/sounds while the app is open. Without this,
    // FCM notification payloads are delivered to onMessage but never shown.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for foreground
    await _initializeLocalNotifications();

    // Create notification channels (Android)
    await _createNotificationChannels();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state via notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM: User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('FCM: User granted provisional permission');
    } else {
      debugPrint('FCM: User declined permission');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Align local-notification permission with FCM (needed to show banners
    // from _showLocalNotification while the app is in the foreground).
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Default channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'General Notifications',
        description: 'General LabGo notifications',
        importance: Importance.high,
      ),
    );

    // Orders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _ordersChannelId,
        'Order Updates',
        description: 'Notifications about your orders',
        importance: Importance.high,
      ),
    );

    // Offers channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _offersChannelId,
        'Lab Offers',
        description: 'Special offers from laboratories',
        importance: Importance.defaultImportance,
      ),
    );

    // Results channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _resultsChannelId,
        'Test Results',
        description: 'Notifications when your test results are ready',
        importance: Importance.max,
      ),
    );
  }

  // ============================================================================
  // Token Management
  // ============================================================================

  /// Get FCM token and save to backend
  Future<String?> getAndSaveToken() async {
    try {
      // Login can race the background Firebase bootstrap in main.dart.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // No-op if already done (e.g. from main.dart at startup) - but on a
      // fresh install/session where login/register calls this directly,
      // this is what actually requests notification permission and tells
      // iOS to register for remote notifications in the first place.
      await initialize();

      if (Platform.isIOS) {
        // getToken() needs the native APNS device token first. Right after
        // permission is granted (e.g. on login), iOS may not have finished
        // delivering it yet. Poll longer than a single login-path tick.
        // Simulator often never gets a real APNs token at all.
        String? apnsToken = await _messaging.getAPNSToken();
        var attempts = 0;
        const maxAttempts = 20; // ~10s
        while (apnsToken == null && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await _messaging.getAPNSToken();
          attempts++;
        }
        if (apnsToken == null) {
          final hint = _looksLikeSimulator()
              ? ' (iOS Simulator — use a physical iPhone for push)'
              : ' (check Push capability, APNs key in Firebase, notification permission)';
          debugPrint('FCM: APNS token never became available$hint');
          _reportDebug(
            'APNS token never became available after ${attempts * 500}ms of retries$hint',
          );
          return null;
        }
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenLocally(token);
        await _sendTokenToBackend(token);
        debugPrint('FCM: Token obtained: $token');
        debugPrint('FCM: Token saved successfully');
      } else {
        debugPrint('FCM: Token is null!');
        _reportDebug('getToken() returned null');
      }
      return token;
    } catch (e, st) {
      debugPrint('FCM: Error getting token: $e');
      _reportDebug('getToken() threw: $e\n$st');
      return null;
    }
  }

  /// Best-effort simulator detection without extra plugins.
  bool _looksLikeSimulator() {
    if (!Platform.isIOS) return false;
    // iOS Simulator sets this env var; physical devices do not.
    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
        Platform.environment.containsKey('SIMULATOR_UDID');
  }

  /// Temporary: report a notification-setup failure to the backend so it
  /// shows up in server logs, since debugPrint() output from a release/
  /// TestFlight build isn't visible to us at all. Best-effort - never lets
  /// a logging failure affect the actual notification flow.
  Future<void> _reportDebug(String message) async {
    try {
      final authService = AuthService();
      final authToken = await authService.getToken();
      if (authToken == null) return;
      await ApiService.post(
        ApiEndpoints.clientDebugLog,
        token: authToken,
        body: {
          'message': message,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (_) {
      // Nothing more we can do if even the debug report fails.
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    debugPrint('FCM: Token refreshed');
    await _saveTokenLocally(token);
    await _sendTokenToBackend(token);
  }

  /// Save token locally
  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
  }

  /// Get locally stored token
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Send token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final authService = AuthService();
      final authToken = await authService.getToken();
      if (authToken == null) {
        debugPrint('FCM: No auth token, skipping backend registration');
        return;
      }

      // Get device info
      final platform = Platform.isIOS ? 'ios' : 'android';

      await ApiService.post(
        ApiEndpoints.registerFcmToken,
        token: authToken,
        body: {
          'fcmToken': token,
          'platform': platform,
        },
      );
      debugPrint('FCM: Token sent to backend');
    } catch (e) {
      debugPrint('FCM: Error sending token to backend: $e');
      _reportDebug('register-token POST failed: $e');
    }
  }

  /// Remove token from backend (on logout)
  Future<void> removeTokenFromBackend() async {
    try {
      final authService = AuthService();
      final authToken = await authService.getToken();
      final fcmToken = await getStoredToken();

      if (authToken != null && fcmToken != null) {
        await ApiService.post(
          ApiEndpoints.unregisterFcmToken,
          token: authToken,
          body: {'fcmToken': fcmToken},
        );
      }

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      await prefs.remove(_topicsKey);

      debugPrint('FCM: Token removed from backend');
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  // ============================================================================
  // Topic Subscriptions
  // ============================================================================

  /// Subscribe user to appropriate topics based on role
  Future<void> subscribeToUserTopics(Map<String, dynamic> userData) async {
    final role = userData['role'] as String?;
    final city = userData['city'] as String?;

    debugPrint('FCM: Subscribing user with role: $role, city: $city');

    if (role == 'patient') {
      await subscribeToTopic(topicAllPatients);
      debugPrint('FCM: Patient subscribed to $topicAllPatients');
      if (city != null) {
        final patientTopic = topicPatientCity(city);
        await subscribeToTopic(patientTopic);
        debugPrint('FCM: Patient subscribed to $patientTopic');
      }
    } else if (role == 'nurse' && city != null) {
      final nurseTopic = topicNurseCity(city);
      await subscribeToTopic(nurseTopic);
      debugPrint('FCM: Nurse subscribed to $nurseTopic');
    }
  }

  /// Unsubscribe from all topics (on logout)
  Future<void> unsubscribeFromAllTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = prefs.getString(_topicsKey);

    if (topicsJson != null) {
      final topics = List<String>.from(jsonDecode(topicsJson));
      for (final topic in topics) {
        await _messaging.unsubscribeFromTopic(topic);
      }
      await prefs.remove(_topicsKey);
    }
    debugPrint('FCM: Unsubscribed from all topics');
  }

  /// Subscribe to a specific topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      await _addTopicToStorage(topic);
      debugPrint('FCM: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('FCM: Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a specific topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      await _removeTopicFromStorage(topic);
      debugPrint('FCM: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('FCM: Error unsubscribing from topic $topic: $e');
    }
  }

  /// Update nurse city subscription (when city changes)
  Future<void> updateNurseCitySubscription(
      String? oldCity, String newCity) async {
    if (oldCity != null) {
      await unsubscribeFromTopic(topicNurseCity(oldCity));
    }
    await subscribeToTopic(topicNurseCity(newCity));
  }

  Future<void> _addTopicToStorage(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = prefs.getString(_topicsKey);
    final topics = topicsJson != null
        ? List<String>.from(jsonDecode(topicsJson))
        : <String>[];

    if (!topics.contains(topic)) {
      topics.add(topic);
      await prefs.setString(_topicsKey, jsonEncode(topics));
    }
  }

  Future<void> _removeTopicFromStorage(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = prefs.getString(_topicsKey);

    if (topicsJson != null) {
      final topics = List<String>.from(jsonDecode(topicsJson));
      topics.remove(topic);
      await prefs.setString(_topicsKey, jsonEncode(topics));
    }
  }

  /// Stable ASCII key for a (Arabic) governorate name, for use in FCM topic
  /// names (topics only allow [A-Za-z0-9-_.~%]).
  ///
  /// This used to strip non-ASCII characters directly, which erased every
  /// Arabic city name down to an empty string - every nurse/patient ended
  /// up subscribed to the same topic regardless of their real city, so
  /// everyone received every city's notifications.
  static String _cityTopicKey(String city) {
    final trimmed = city.trim();
    for (final c in iraqiCities) {
      if (c.nameAr == trimmed) return c.id;
    }
    // Fallback for a city string that doesn't match the known list - still
    // ASCII-safe and unique per distinct input.
    return trimmed.codeUnits.fold<int>(0, (hash, unit) => (hash * 31 + unit) & 0x7fffffff).toRadixString(36);
  }

  // ============================================================================
  // Message Handlers
  // ============================================================================

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM: ========== FOREGROUND MESSAGE ==========');
    debugPrint('FCM: Message ID: ${message.messageId}');
    debugPrint('FCM: Data: ${message.data}');
    debugPrint('FCM: Notification: ${message.notification?.title} - ${message.notification?.body}');

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String? ?? 'LabGo';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    if (body.isEmpty && (notification?.title == null || notification!.title!.isEmpty)) {
      debugPrint('FCM: No displayable foreground payload');
      return;
    }

    // Always show a local notification in foreground. Relying only on
    // setForegroundNotificationPresentationOptions is unreliable with a
    // custom AppDelegate; AppDelegate.willPresent also allows the banner.
    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      channelId: _getChannelIdFromType(message.data['type']),
    );
    debugPrint('FCM: Local notification shown');
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped: ${message.data}');
    _navigateBasedOnNotificationType(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateBasedOnNotificationType(data);
    }
  }

  // Notification types that represent an order-status change and should
  // deep-link straight to that order's tracking page (map/timeline) instead
  // of just switching tabs.
  static const _orderTrackingTypes = {
    'order_accepted',
    'nurse_assigned',
    'nurse_assigned_by_admin',
    // Prescription was priced by the admin; open the order so the patient
    // can approve or reject the quote right away.
    'prescription_quoted',
  };

  /// Public entry point for tapping a notification from the in-app
  /// notifications list (as opposed to a system tray tap), reusing the
  /// same deep-link logic as an FCM tap.
  Future<void> openNotificationTarget(Map<String, dynamic> data) =>
      _navigateBasedOnNotificationType(data);

  /// Navigate based on notification type
  Future<void> _navigateBasedOnNotificationType(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;

    final navigator = ApiService.navigatorKey.currentState;
    if (navigator == null) return;

    if (_orderTrackingTypes.contains(type) && orderId != null && orderId.isNotEmpty) {
      final result = await OrderService.getOrderById(orderId);
      if (result['success'] == true) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        navigator.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: result['order'] as Order),
          ),
        );
        return;
      }
      // Fall through to the tab-switch behavior below if the order fetch fails.
    }

    switch (type) {
      case 'lab_offer':
        // Navigate to main screen (offers tab or lab details)
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);
        break;

      case 'order_accepted':
      case 'nurse_assigned':
      case 'results_ready':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              initialIndex: mainTabForNotificationType(type),
            ),
          ),
          (route) => false,
        );
        break;

      case 'new_order_in_city':
        // Navigate to main screen (nurse will see available orders)
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);
        break;

      default:
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);
    }
  }

  /// Show local notification (for foreground)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _defaultChannelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  String _getChannelIdFromType(String? type) {
    switch (type) {
      case 'lab_offer':
        return _offersChannelId;
      case 'order_accepted':
      case 'nurse_assigned':
      case 'new_order_in_city':
        return _ordersChannelId;
      case 'results_ready':
        return _resultsChannelId;
      default:
        return _defaultChannelId;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _offersChannelId:
        return 'Lab Offers';
      case _ordersChannelId:
        return 'Order Updates';
      case _resultsChannelId:
        return 'Test Results';
      default:
        return 'General Notifications';
    }
  }
}
