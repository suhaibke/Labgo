import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui.dart';

/// Splash screen with the design's logo pop, bubbles, bouncing dots and progress bar.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Progress (0..1) of a CSS animation with [delayMs] and [durMs] at elapsed [ms].
  static double _seg(double ms, double delayMs, double durMs) =>
      ((ms - delayMs) / durMs).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final dark = app.darkMode;
    return Positioned.fill(
      child: GestureDetector(
        onTap: app.skipSplash,
        child: AnimatedOpacity(
          opacity: app.splashFading ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
          child: ColoredBox(
            color: dark ? Colors.black : Colors.white,
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _loop]),
              builder: (context, _) {
                final ms = _intro.value * 2200;
                final loopMs = _loop.value * 4200;

                // .splash-circle: scale 0 → 1.1 (60%) → 1, cubic-bezier(.34,1.56,.64,1)
                // CSS applies the timing function per keyframe interval.
                const spring = Cubic(.34, 1.56, .64, 1);
                final cRaw = _seg(ms, 0, 600);
                final circleScale = cRaw < .6
                    ? 1.1 * spring.transform(cRaw / .6)
                    : 1.1 - .1 * spring.transform((cRaw - .6) / .4);
                // .splash-logo: opacity 0→1, scale .8→1, rotate -3deg→0, .5s ease-out delay .1s
                final lT = Curves.easeOut.transform(_seg(ms, 100, 500));
                // .splash-text: translateY 8→0, .45s ease-out delay .4s
                final tT = Curves.easeOut.transform(_seg(ms, 400, 450));
                // .splash-logo-wrap: pulse 1 → 1.05 → 1 at 1.4s for .45s
                final pT = _seg(ms, 1400, 450);
                final pulse = pT < .5
                    ? 1 + .05 * Curves.easeInOut.transform(pT / .5)
                    : 1.05 - .05 * Curves.easeInOut.transform((pT - .5) / .5);

                Widget bubble(double leftFrac, double size, double delayMs) {
                  final t = ((loopMs - delayMs) % 1000) / 1000;
                  final e = Curves.easeIn.transform(t);
                  final op = t < .25
                      ? Curves.easeIn.transform(t / .25)
                      : 1 - Curves.easeIn.transform((t - .25) / .75);
                  return Positioned(
                    left: 110 * leftFrac,
                    top: 6,
                    child: Opacity(
                      opacity: op.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 14 + (-34 - 14) * e),
                        child: Transform.scale(
                          scale: .6 + .4 * e,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: const BoxDecoration(
                              color: Fixed.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                Widget dot(Color color, double delayMs) {
                  final t = ((loopMs - delayMs) % 700) / 700;
                  final y = t < .5
                      ? -7 * Curves.easeInOut.transform(t / .5)
                      : -7 + 7 * Curves.easeInOut.transform((t - .5) / .5);
                  return Transform.translate(
                    offset: Offset(0, y),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: pulse,
                            child: SizedBox(
                              width: 110,
                              height: 110,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  bubble(.38, 7, 0),
                                  bubble(.52, 5, 180),
                                  bubble(.64, 6, 360),
                                  Transform.scale(
                                    scale: circleScale,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color.fromRGBO(
                                              17,
                                              17,
                                              17,
                                              .18,
                                            ),
                                            offset: Offset(0, 18),
                                            blurRadius: 38,
                                          ),
                                          BoxShadow(
                                            color: Color.fromRGBO(
                                              17,
                                              17,
                                              17,
                                              .10,
                                            ),
                                            offset: Offset(0, 4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Opacity(
                                        opacity: lT,
                                        child: Transform.rotate(
                                          angle: (-3 + 3 * lT) * math.pi / 180,
                                          child: Transform.scale(
                                            scale: .8 + .2 * lT,
                                            child: Image.asset(
                                              'assets/images/logo.jpg',
                                              width: 78,
                                              height: 78,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Opacity(
                            opacity: tT,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - tT)),
                              child: Column(
                                children: [
                                  Text(
                                    'LabGo',
                                    style: ts(
                                      context,
                                      24,
                                      weight: w800,
                                      height: 1.2,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xFF111111),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'مختبرك بين يديك',
                                    textDirection: TextDirection.rtl,
                                    style: ts(
                                      context,
                                      14,
                                      height: 1.4,
                                      color: const Color(0xFF8A8A8E),
                                      tracking: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 42 + MediaQuery.paddingOf(context).bottom,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              dot(Fixed.orange, 0),
                              const SizedBox(width: 8),
                              dot(Fixed.blue, 150),
                              const SizedBox(width: 8),
                              dot(Fixed.orange, 300),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 120,
                            height: 3,
                            alignment: AlignmentDirectional.centerStart,
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFE7E7E9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: Curves.easeOut.transform(
                                _seg(ms, 0, 1900),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Fixed.orange,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
