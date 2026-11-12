import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/auth/register_screen.dart';
import 'src/screens/auth/blocked_screen.dart';
import 'src/screens/main/main_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/services/auth_service.dart';
import 'src/services/api_service.dart';
import 'src/services/notification_service.dart';
import 'src/utils/fallback_localizations.dart';
import 'l10n/app_localizations.dart';

/// Custom ScrollPhysics with controlled velocity to prevent fast/jumpy scrolling.
/// This creates a smooth, controlled scroll experience.
class SmoothScrollPhysics extends ScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothScrollPhysics(parent: buildParent(ancestor));
  }

  // Reduce the velocity of fling gestures significantly
  @override
  double get minFlingVelocity => 50.0; // Default is usually lower

  @override
  double get maxFlingVelocity => 2000.0; // Default is ~8000, this limits it

  // Increase friction to slow down scrolling faster
  @override
  double get dragStartDistanceMotionThreshold => 3.5; // Default is 3.5

  // Create simulation with higher friction
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Reduce the velocity significantly for smoother scrolling
    final double adjustedVelocity = velocity * 0.5; // Cut velocity in half
    
    final Tolerance tolerance = toleranceFor(position);
    if ((adjustedVelocity.abs() < tolerance.velocity) ||
        (adjustedVelocity > 0.0 && position.pixels >= position.maxScrollExtent) ||
        (adjustedVelocity < 0.0 && position.pixels <= position.minScrollExtent)) {
      return null;
    }
    
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: adjustedVelocity,
      friction: 0.02, // Higher friction = slower deceleration (default ~0.015)
      tolerance: tolerance,
    );
  }

  // Prevent overscroll
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}

/// Custom ScrollBehavior that uses SmoothScrollPhysics for controlled,
/// non-jumpy scrolling across all platforms.
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const SmoothScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Disable overscroll indicator completely for cleaner look
    return child;
  }

  // Enable drag scrolling on all devices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (with error handling)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize notification service (with error handling)
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();

  // Run app FIRST, then handle FCM in background
  runApp(LabGoApp(isLoggedIn: isLoggedIn));

  // Do FCM token/topic work AFTER app is visible (non-blocking)
  if (isLoggedIn) {
    _initializeFcmInBackground(authService);
  }
}

/// Handle FCM setup in background after app is visible
void _initializeFcmInBackground(AuthService authService) async {
  try {
    final notificationService = NotificationService();
    await notificationService.getAndSaveToken();
    final userData = await authService.getUserData();
    if (userData != null) {
      await notificationService.subscribeToUserTopics(userData);
    }
  } catch (e) {
    debugPrint('FCM background init error: $e');
  }
}

class LabGoApp extends StatefulWidget {
  final bool isLoggedIn;

  const LabGoApp({super.key, required this.isLoggedIn});

  @override
  State<LabGoApp> createState() => _LabGoAppState();

  static _LabGoAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_LabGoAppState>();
  }
}

class _LabGoAppState extends State<LabGoApp> {
  Locale _locale = const Locale('ar');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('locale');
    if (savedLocale != null) {
      setState(() {
        _locale = Locale(savedLocale);
      });
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabGo',
      debugShowCheckedModeBanner: false,
      // Apply custom scroll behavior globally to fix bouncy/oversensitive scroll
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      locale: _locale,
      navigatorKey: ApiService.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FallbackMaterialLocalizationsDelegate(),
        FallbackCupertinoLocalizationsDelegate(),
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('ku'),
        Locale('tr'),
      ],
      initialRoute: widget.isLoggedIn ? '/main' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/blocked': (context) => const BlockedScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
