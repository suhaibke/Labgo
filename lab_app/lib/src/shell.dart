import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'screens/add_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/print_screen.dart';
import 'screens/results_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/store_screen.dart';
import 'glass_toast.dart';
import 'sheets.dart';
import 'splash.dart';
import 'theme.dart';
import 'ui.dart';

/// Root layout: top bar + scrolling screen + floating bottom nav + overlays.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final inApp = app.auth == 'app';

    Widget body;
    if (!inApp) {
      body = const AuthBody();
    } else {
      body = _AppBody(
        key: ValueKey(
          '${app.lang}-${app.tab}-${app.selectedPatient?.id}-${app.wastePage}-${app.maintenancePage}-${app.settingsPage}-${app.storeOpen}',
        ),
      );
    }

    return Directionality(
      textDirection: app.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: DefaultTextStyle(
        style: ts(context, 16),
        child: ColoredBox(
          color: pal.appBg,
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top),
                  const TopBar(),
                  Expanded(child: body),
                ],
              ),
              if (inApp && app.tab != 'print') const BottomNav(),
              if (inApp) const Overlays(),
              // Above sheets, so messages from a sheet's action are visible.
              const GlassToastHost(),
              if (app.splashVisible) const SplashOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBody extends StatefulWidget {
  const _AppBody({super.key});

  @override
  State<_AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends State<_AppBody> {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    Widget screen;
    if (app.guest && !app.storeOpen && app.tab != 'home') {
      return const SingleChildScrollView(child: Entrance(child: _GuestLock()));
    }
    switch (app.storeOpen ? 'store' : app.tab) {
      case 'store':
        screen = const StoreScreen();
      case 'home':
        screen = const HomeScreen();
      case 'add':
        screen = const AddScreen();
      case 'send':
        screen = const SendScreen();
      case 'profile':
        screen = const SettingsScreen();
      case 'results':
        screen = app.selectedPatient == null
            ? const ResultsScreen()
            : const ResultDetailScreen();
      case 'print':
        screen = const PrintScreen();
      default:
        screen = PlaceholderScreen(tab: app.tab);
    }
    return SingleChildScrollView(
      // `.lang-fade` + `.screen-enter`
      child: Entrance(child: screen),
    );
  }
}

/// A tab a guest cannot open: what it is for and a sign-in button.
class _GuestLock extends StatelessWidget {
  const _GuestLock();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 140),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: pal.softAccent, shape: BoxShape.circle),
            child: LIcon('ShieldCheck', size: 30, color: pal.accent),
          ),
          const SizedBox(height: 14),
          Text(app.tr('هذا القسم لحسابات المختبرات', 'ئەم بەشە بۆ هەژماری تاقیگەیە', 'This section is for lab accounts'),
              textAlign: TextAlign.center, style: ts(context, 20, weight: w700)),
          const SizedBox(height: 6),
          Text(
            app.tr('سجّل الدخول لإدارة المرضى والنتائج والإرسال والإعدادات. يمكنك تصفح المتجر كضيف.',
                'بچۆ ژوورەوە بۆ بەڕێوەبردنی نەخۆش و ئەنجام. دەتوانیت فرۆشگا ببینیت.',
                'Sign in to manage patients, results, transfers and settings. You can browse the store as a guest.'),
            textAlign: TextAlign.center,
            style: ts(context, 13, color: pal.muted, height: 1.6),
          ),
          const SizedBox(height: 18),
          Tap(
            onTap: app.leaveGuest,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text(app.tr('تسجيل الدخول', 'چوونە ژوورەوە', 'Sign in'), style: ts(context, 16, weight: w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Tap(
            onTap: app.openStore,
            child: SizedBox(
              height: 44,
              child: Center(child: Text(app.tr('تصفح المتجر', 'فرۆشگا', 'Browse the store'), style: ts(context, 14, weight: w700, color: pal.accent))),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky top bar (64px) — always laid out LTR like the design.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget circle({
      required Widget child,
      VoidCallback? onTap,
      Color? color,
      bool border = true,
    }) => Tap(
      onTap: onTap,
      scale: .9,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? pal.chipBg,
          shape: BoxShape.circle,
          border: border ? Border.all(color: pal.cardBorder) : null,
          boxShadow: border ? Shadows.sm : null,
        ),
        child: child,
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: pal.appBg,
          border: Border(bottom: BorderSide(color: pal.line)),
        ),
        child: Row(
          children: [
            if (app.auth == 'app') ...[
              circle(
                onTap: () => app.selectTab('profile'),
                color: pal.avatarBg,
                border: false,
                child: app.userPhoto != null
                    ? ClipOval(child: Image.memory(app.userPhoto!, width: 36, height: 36, fit: BoxFit.cover))
                    : Text(
                        app.profileInitial,
                        style: ts(context, 14, weight: w700),
                      ),
              ),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  circle(
                    onTap: () => app.openNotifications(true),
                    child: _ShakingBell(
                      active: app.unreadCount > 0,
                      child: LIcon('Bell', size: 17, color: pal.ink),
                    ),
                  ),
                  if (app.unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: IgnorePointer(
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 19),
                          height: 19,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Fixed.red,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: pal.appBg, width: 2),
                          ),
                          child: Text(
                            '${app.unreadCount}',
                            style: ts(
                              context,
                              10,
                              weight: w700,
                              color: Colors.white,
                              height: 1,
                              tracking: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            const _ThemeSwitch(),
            const Spacer(),
            circle(
              onTap: app.openStore,
              child: LIcon('Store', size: 19, strokeWidth: 1.8, color: pal.ink),
            ),
            const SizedBox(width: 8),
            circle(
              onTap: app.cycleLanguage,
              // CSS lets this content overflow the 36px circle; do the same.
              child: OverflowBox(
                maxWidth: 60,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LIcon('Globe', size: 14, color: pal.accent),
                    const SizedBox(width: 2),
                    Text(
                      app.langBadge,
                      style: ts(context, 11, weight: w900, height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final dark = app.darkMode;
    return GestureDetector(
      onTap: app.toggleTheme,
      child: Container(
        width: 60,
        height: 32,
        decoration: BoxDecoration(
          color: pal.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: pal.cardBorder),
          boxShadow: Shadows.sm,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 6,
              top: 8,
              child: LIcon(
                'Sun',
                size: 14,
                color: dark ? pal.muted : pal.accent,
              ),
            ),
            Positioned(
              right: 6,
              top: 8,
              child: LIcon(
                'Moon',
                size: 14,
                color: dark ? pal.accent : pal.muted,
              ),
            ),
            // knob moves without transition (design: transition: none)
            Positioned(
              left: dark ? 30 : 2,
              top: 2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: pal.accent,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating pill navigation with the sliding white circle.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _items = [
    ('home', 'House', 22.0, 1.8),
    ('add', 'Plus', 26.0, 2.4),
    ('results', 'FileText', 22.0, 1.8),
    ('send', 'Send', 22.0, 1.8),
    ('profile', 'Settings', 22.0, 1.8),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final index = _items.indexWhere((e) => e.$1 == app.tab);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 22 + (bottomInset > 0 ? bottomInset - 12 : 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 10),
              blurRadius: 30,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: pal.navBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: pal.navBorder),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final slot = c.maxWidth / 5;
                  // The design's indicator is positioned from the left edge in both directions.
                  final visualIndex = app.rtl ? 4 - index : index;
                  return SizedBox(
                    height: 48,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (index >= 0)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            left: slot * visualIndex,
                            top: 0,
                            width: slot,
                            height: 48,
                            child: Center(
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: pal.activeCircle,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x24000000),
                                      offset: Offset(0, 4),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            for (final it in _items)
                              Expanded(
                                child: Tap(
                                  scale: .92,
                                  onTap: () => app.selectTab(it.$1),
                                  child: SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: it.$1 == 'add'
                                          ? Transform.translate(
                                              offset: const Offset(
                                                0,
                                                -6,
                                              ), // -mt-3 on a centred grid item
                                              child: Container(
                                                width: 48,
                                                height: 48,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: pal.accent,
                                                  shape: BoxShape.circle,
                                                  boxShadow: Shadows.lg,
                                                ),
                                                child: LIcon(
                                                  it.$2,
                                                  size: it.$3,
                                                  strokeWidth: it.$4,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : LIcon(
                                              it.$2,
                                              size: it.$3,
                                              strokeWidth: it.$4,
                                              color: app.tab == it.$1
                                                  ? pal.activeIcon
                                                  : pal.muted,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}



/// The bell rings (a short swing every few seconds) while there are unread notifications.
class _ShakingBell extends StatefulWidget {
  final bool active;
  final Widget child;
  const _ShakingBell({required this.active, required this.child});

  @override
  State<_ShakingBell> createState() => _ShakingBellState();
}

class _ShakingBellState extends State<_ShakingBell> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _ShakingBell old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // Swing during the first quarter of each cycle, then rest.
        final t = _c.value / .25;
        final angle = t >= 1 ? 0.0 : math.sin(t * math.pi * 6) * (1 - t) * .45;
        return Transform.rotate(angle: angle, alignment: const Alignment(0, -0.8), child: child);
      },
    );
  }
}
