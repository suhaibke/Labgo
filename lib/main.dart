import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/auth/register_screen.dart';
import 'src/screens/auth/blocked_screen.dart';
import 'src/screens/main/main_screen.dart';
import 'src/screens/packages/package_detail_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/services/auth_service.dart';
import 'src/services/api_service.dart';
import 'src/services/notification_service.dart';
import 'src/utils/fallback_localizations.dart';
import 'src/utils/package_share.dart';
import 'l10n/app_localizations.dart';

/// Scroll behavior using platform-default physics (no velocity hacking).
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

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

  // The default release-mode ErrorWidget is a blank grey box with no text,
  // which is indistinguishable from other legitimate grey UI (e.g. a map's
  // tile-layer background) when something throws during build(). Show the
  // actual error so a broken widget is diagnosable from a screenshot alone,
  // without needing a debug build or logcat access.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: const Color(0xFFFFCDD2),
      child: Text(
        details.exceptionAsString(),
        style: const TextStyle(color: Colors.red, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  };

  // Show UI first. Firebase / notifications / auth must not block first paint
  // (TestFlight white screen when permission or Firebase hangs before runApp).
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  runApp(const LabGoApp());
}

Future<void> _initializeServicesInBackground({required bool isLoggedIn}) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    if (isLoggedIn) {
      await notificationService.getAndSaveToken();
      final userData = await AuthService().getUserData();
      if (userData != null) {
        await notificationService.subscribeToUserTopics(userData);
      }
    }
  } catch (e) {
    debugPrint('Notification init error: $e');
  }
}

class LabGoApp extends StatefulWidget {
  const LabGoApp({super.key});

  @override
  State<LabGoApp> createState() => _LabGoAppState();

  static _LabGoAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_LabGoAppState>();
  }
}

class _LabGoAppState extends State<LabGoApp> {
  Locale _locale = const Locale('ar');
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _ready = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var loggedIn = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString('locale');
      if (savedLocale != null && mounted) {
        _locale = Locale(savedLocale);
      }
      loggedIn = await AuthService().isLoggedIn();
    } catch (e) {
      debugPrint('Bootstrap auth/locale error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _ready = true;
    });

    _initDeepLinks();
    unawaited(_initializeServicesInBackground(isLoggedIn: loggedIn));
  }

  /// Opens a package's detail screen from a shared link. The stream also
  /// delivers the link that launched the app, so it needs no separate
  /// getInitialLink() call (that would open the screen twice).
  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (e) => debugPrint('Deep link stream error: $e'),
    );
  }

  void _handleIncomingLink(Uri uri) {
    final packageId = packageIdFromLink(uri);
    if (packageId == null) return;

    ApiService.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => PackageDetailScreen(packageId: packageId)),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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
      home: _ready
          ? (_isLoggedIn ? const MainScreen() : const LoginScreen())
          : const _StartupSplash(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/blocked': (context) => const BlockedScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
