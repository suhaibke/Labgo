import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_state.dart';
import 'lucide_data.dart';
import 'theme.dart';

/// Short-hands used by every screen.
extension Ctx on BuildContext {
  AppState get app => AppScope.of(this);
  Palette get pal => AppScope.of(this).palette;
}

/// Text style matching the design: SF on iPhone, Inter elsewhere, -0.02em tracking in LTR,
/// no tracking in RTL, Tailwind default line-height 1.5.
TextStyle ts(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.5,
  double? tracking,
}) {
  final app = context.app;
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? app.palette.ink,
    height: height,
    // CSS puts half the extra line-height above and half below the glyphs.
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: tracking ?? (app.rtl ? 0 : -0.02 * size),
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
  );
}

/// iPhone / Mac: the system font (SF Pro + SF Arabic) — `null` means "system".
/// Android and others: bundled Inter, with IBM Plex Sans Arabic for Arabic/Kurdish.
bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

String? get kAppFontFamily => _isApple ? null : 'Inter';

List<String>? get kAppFontFallback =>
    _isApple ? null : const ['IBMPlexSansArabic'];

const w400 = FontWeight.w400;
const w500 = FontWeight.w500;
const w600 = FontWeight.w600;
const w700 = FontWeight.w700;
const w800 = FontWeight.w800;
const w900 = FontWeight.w900;

/// Lucide icon rendered from the design's own SVG paths.
class LIcon extends StatelessWidget {
  final String name;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool flipX;

  const LIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.flipX = false,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? DefaultTextStyle.of(context).style.color ?? context.pal.ink;
    final hex =
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" '
        'stroke="$hex" stroke-opacity="${c.a.toStringAsFixed(3)}" stroke-width="$strokeWidth" stroke-linecap="round" '
        'stroke-linejoin="round">${kLucide[name] ?? ''}</svg>';
    Widget icon = SvgPicture.string(svg, width: size, height: size);
    if (flipX) icon = Transform.flip(flipX: true, child: icon);
    return SizedBox(width: size, height: size, child: icon);
  }
}

/// Button with the design's `active:scale-*` press feedback.
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool enabled;

  const Tap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.98,
    this.enabled = true,
  });

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 150),
        curve: const Cubic(0.4, 0, 0.2, 1),
        child: widget.child,
      ),
    );
  }
}

/// `bg-[var(--card)] rounded-[28px] border border-[var(--card-border)] shadow-sm`
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow> shadow;
  final Color? color;

  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.shadow = Shadows.sm,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? pal.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pal.cardBorder),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// Pill used for filter chips (`px-4 py-2 rounded-full text-[13px] font-bold`).
class FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.scale = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      onTap: onTap,
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? pal.ink : pal.chipBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: ts(
            context,
            13,
            weight: w700,
            color: selected
                ? (pal.dark ? const Color(0xFF0B0B0D) : pal.appBg)
                : pal.muted2,
          ),
        ),
      ),
    );
  }
}

/// `search-bar` from the design: single rounded box, transparent input.
class SearchBarBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double iconSize;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final String icon;

  const SearchBarBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.iconSize = 16,
    this.controller,
    this.onTap,
    this.onSubmitted,
    this.icon = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      height: 45, // 14px × 1.5 line + 12px padding top and bottom
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pal.searchBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          LIcon(icon, size: iconSize, color: pal.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              textAlignVertical: TextAlignVertical.center,
              onSubmitted: onSubmitted,
              style: ts(context, 14, height: 1.5),
              strutStyle: const StrutStyle(
                fontSize: 14,
                height: 1.5,
                forceStrutHeight: true,
              ),
              cursorColor: pal.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: ts(context, 14, color: pal.placeholder, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill used in report rows.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final pending = status == 'Pending';
    final label = status == 'Completed'
        ? app.w('completed')
        : status == 'Pending'
        ? app.w('pending')
        : status == 'Payment Pending'
        ? app.w('paymentPending')
        : app.w('sent');
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: pending ? pal.softAccent : pal.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: pending ? null : Border.all(color: pal.line),
      ),
      child: Text(
        label,
        style: ts(
          context,
          11,
          weight: w700,
          color: pending
              ? pal.accent
              : (status == 'Payment Pending' ? pal.ink : pal.muted2),
          height: 1.45,
        ),
      ),
    );
  }
}

/// Small round avatar with initials (`w-11 h-11 rounded-full bg-[var(--segmented)]`).
class InitialsAvatar extends StatelessWidget {
  final String text;
  final double size;
  const InitialsAvatar(this.text, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.pal.segmented,
        shape: BoxShape.circle,
      ),
      child: Text(text, style: ts(context, 13, weight: w700)),
    );
  }
}

/// Plays the design's `screenIn` / `fadeUp` / `popIn` entrance animations.
class Entrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double dy;
  final double fromScale;
  final Curve curve;

  const Entrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.dy = 10,
    this.fromScale = 1,
    this.curve = Curves.easeOut,
  });

  /// `.stagger` → fadeUp .38s cubic-bezier(.2,.8,.2,1)
  const Entrance.fadeUp({super.key, required this.child})
    : duration = const Duration(milliseconds: 380),
      dy = 14,
      fromScale = 1,
      curve = const Cubic(.2, .8, .2, 1);

  /// `.pop-in` → popIn .28s ease
  const Entrance.pop({super.key, required this.child})
    : duration = const Duration(milliseconds: 280),
      dy = 8,
      fromScale = .98,
      curve = Curves.ease;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = widget.curve.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - t)),
            child: Transform.scale(
              scale: widget.fromScale + (1 - widget.fromScale) * t,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Back link (`flex items-center gap-1 text-[13px] font-bold text-[var(--muted)] py-1`).
class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const BackLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tap(
      onTap: onTap,
      scale: .95,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LIcon(
              'ArrowLeft',
              size: 15,
              color: pal.muted,
              flipX: context.app.rtl,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: ts(context, 13, weight: w700, color: pal.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS-like negative top margin (e.g. Tailwind `-mt-4`): pulls the child up
/// by [amount] and reduces the space it takes in the layout by the same amount.
class NegativeTopMargin extends SingleChildRenderObjectWidget {
  final double amount;
  const NegativeTopMargin({super.key, required this.amount, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNegTop(amount);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderNegTop renderObject,
  ) {
    renderObject.amount = amount;
  }
}

class _RenderNegTop extends RenderProxyBox {
  double _amount;
  _RenderNegTop(this._amount);

  set amount(double v) {
    if (v == _amount) return;
    _amount = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    final s = child!.size;
    size = constraints.constrain(
      Size(s.width, (s.height - _amount).clamp(0, double.infinity)),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(child!, offset.translate(0, -_amount));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, -_amount),
      position: position,
      hitTest: (r, p) => child!.hitTest(r, position: p),
    );
  }
}

/// Absolutely-positioned dropdown under a field (`absolute top-full mt-1 z-20`),
/// floating over the content below it like the design.
class FloatingDropdown extends StatefulWidget {
  final Widget child;
  final bool open;
  final List<Widget> items;

  const FloatingDropdown({
    super.key,
    required this.child,
    required this.open,
    required this.items,
  });

  @override
  State<FloatingDropdown> createState() => _FloatingDropdownState();
}

class _FloatingDropdownState extends State<FloatingDropdown> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  void _sync() {
    final show = widget.open && widget.items.isNotEmpty;
    if (show && !_portal.isShowing) _portal.show();
    if (!show && _portal.isShowing) _portal.hide();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mounted ? _sync() : null,
    );
  }

  @override
  void didUpdateWidget(covariant FloatingDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mounted ? _sync() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (overlayContext) {
          final box = context.findRenderObject() as RenderBox?;
          final width = box?.size.width ?? 300;
          final pal = context.pal;
          return Positioned(
            width: width,
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              offset: const Offset(0, 4),
              child: Directionality(
                textDirection: Directionality.of(context),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal.cardBorder),
                      boxShadow: Shadows.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.items,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Row inside a [FloatingDropdown] (`px-3 py-2.5 text-[14px] font-semibold`).
class DropdownRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final FontWeight weight;
  const DropdownRow({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.weight = w600,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        style: ts(context, 14, weight: weight, color: color),
      ),
    ),
  );
}

/// Input drawn like the design's `<input>`: fixed CSS height, input-bg fill,
/// 1px card-border, rounded corners; the TextField inside is borderless.
class BoxField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final double fontSize;
  final double vPad;
  final double radius;
  final int lines;
  final bool ltr;
  final TextInputType? keyboard;

  const BoxField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.onChanged,
    this.onTap,
    this.fontSize = 15,
    this.vPad = 12,
    this.radius = 16,
    this.lines = 1,
    this.ltr = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final height = fontSize * 1.5 * lines + vPad * 2 + 2;
    return Container(
      height: height,
      alignment: lines > 1 ? Alignment.topCenter : Alignment.center,
      padding: lines > 1 ? EdgeInsets.only(top: vPad) : null,
      decoration: BoxDecoration(
        color: pal.inputBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pal.cardBorder),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTap: onTap,
        minLines: lines,
        maxLines: lines,
        keyboardType: keyboard,
        textDirection: ltr ? TextDirection.ltr : null,
        style: ts(context, fontSize),
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: 1.5,
          forceStrutHeight: true,
        ),
        cursorColor: pal.accent,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: ts(context, fontSize, color: pal.placeholder),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
