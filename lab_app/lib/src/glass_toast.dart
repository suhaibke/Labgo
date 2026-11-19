import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'ui.dart';

/// The app's one message banner: a frosted "liquid glass" pill that slides and
/// fades in at the top centre, right under the status bar.
///
/// Every message goes through `app.toast(text)`; this host shows whatever
/// `app.toastText` holds and animates it out when it is cleared.
class GlassToastHost extends StatefulWidget {
  const GlassToastHost({super.key});

  @override
  State<GlassToastHost> createState() => _GlassToastHostState();
}

class _GlassToastHostState extends State<GlassToastHost> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  );
  String? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final text = context.app.toastText;
    if (text != null && text != _shown) {
      _shown = text;
      _c.forward(from: 0);
    } else if (text == null && _shown != null && _c.status != AnimationStatus.reverse) {
      _c.reverse().whenComplete(() {
        if (mounted && context.app.toastText == null) setState(() => _shown = null);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.app; // rebuild on every app change, so didChangeDependencies runs
    final text = _shown;
    if (text == null) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top + 8;
    final slide = CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0, .6, curve: Curves.easeOut), reverseCurve: Curves.easeIn);
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -28 * (1 - slide.value)),
                child: Transform.scale(scale: .94 + .06 * slide.value.clamp(0, 1), child: child),
              ),
              child: _GlassPill(key: ValueKey(text), text: text),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({super.key, required this.text});

  static final _fail = RegExp(r'^(تعذر|لا يمكن|أدخل|اكتب|اختر|أكمل|Could not|Cannot|Enter|Choose|Fill|Write|Not enough|ناتوانر|نەتوانرا)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final ok = text.contains('✓');
    final bad = !ok && _fail.hasMatch(text.trim());
    final icon = ok ? 'CircleCheck' : bad ? 'CircleAlert' : null;
    final iconColor = ok ? const Color(0xFF34C759) : const Color(0xFFFFB340);
    final shape = BorderRadius.circular(999);
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .9),
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: shape,
              // dark tint + a light sheen on the upper half, like curved glass
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C3A3A3C), Color(0x9E1C1C1E)],
              ),
              border: Border.all(color: const Color(0x47FFFFFF), width: 1),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: shape,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  LIcon(icon, size: 17, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    // the green tick icon replaces a "✓" in the message
                    ok ? text.replaceAll('✓', '').trim() : text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ts(context, 13, weight: w700, color: Colors.white, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
