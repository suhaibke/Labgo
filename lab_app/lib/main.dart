import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app_state.dart';
import 'src/shell.dart';
import 'src/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LabGoLabApp());
}

class LabGoLabApp extends StatefulWidget {
  const LabGoLabApp({super.key});

  @override
  State<LabGoLabApp> createState() => _LabGoLabAppState();
}

class _LabGoLabAppState extends State<LabGoLabApp> with WidgetsBindingObserver {
  final _state = AppState()
    ..startSplash()
    ..restoreSession()
    ..loadMemory();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Back in the foreground: pick up what changed on the web dashboard.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _state.syncFromServer();
      _state.loadNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: Builder(
        builder: (context) {
          final app = AppScope.of(context);
          final pal = app.palette;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (app.darkMode
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark)
                    .copyWith(statusBarColor: Colors.transparent),
            child: MaterialApp(
              title: 'LabGo Lab',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: kAppFontFamily,
                fontFamilyFallback: kAppFontFallback,
                brightness: app.darkMode ? Brightness.dark : Brightness.light,
                scaffoldBackgroundColor: pal.appBg,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: pal.accent,
                  brightness: app.darkMode ? Brightness.dark : Brightness.light,
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: pal.accent,
                ),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
              ),
              home: const Scaffold(
                resizeToAvoidBottomInset: true,
                body: Shell(),
              ),
            ),
          );
        },
      ),
    );
  }
}
