import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';

class NavBarItemData {
  final IconData? icon;
  final String? iconAsset;
  final String label;

  NavBarItemData({this.icon, this.iconAsset, required this.label})
      : assert(icon != null || iconAsset != null);
}

/// Modern pill-shaped bottom navigation bar with animated active indicator,
/// smooth bounce animation on tap, and an optional floating circular add-button
/// raised above the bar (inserted after [addButtonAfterIndex], if [onAddTap]
/// is provided).
///
/// Language-agnostic: labels use [FittedBox] so they auto-scale to fit
/// regardless of language length (Arabic, English, Kurdish, Turkish…),
/// preventing overflow or collision with the floating action button.
class AppBottomNavBar extends StatefulWidget {
  final List<NavBarItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddTap;
  final int addButtonAfterIndex;

  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onAddTap,
    this.addButtonAfterIndex = 1,
  });

  static const activeColor = Color(0xFF7257D8);
  static const inactiveColor = Color(0xFF9C9AA8);
  static const activePillColor = Color(0xFFEFEDFB);

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  int? _bouncingIndex;

  void _handleTap(int index) {
    setState(() => _bouncingIndex = index);
    widget.onTap(index);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _bouncingIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      children.add(_NavItem(
        data: widget.items[i],
        isActive: i == widget.currentIndex,
        isBouncing: i == _bouncingIndex,
        onTap: () => _handleTap(i),
      ));
      if (widget.onAddTap != null && i == widget.addButtonAfterIndex) {
        // Fixed-width gap that reserves space for the floating button.
        // Using a fixed width (not Expanded) ensures it never gets squeezed
        // when labels are long (e.g. English).
        children.add(const SizedBox(width: 60));
      }
    }

    const floatingButtonSize = 56.0;

    // The home-indicator safe-area inset (~34pt on notched/Dynamic Island
    // iPhones, ~0 on Android) belongs in the gap *below* the bar, not inside
    // it - putting SafeArea around the Row (as before) padded it into the
    // bar's own body, stretching the pill to a much taller, gap-heavy shape
    // on iOS than the compact one Android got. Keeping it in the outer
    // margin instead pushes the whole bar up off the screen edge without
    // changing its own height on either platform.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // ── Bar container ─────────────────────────────────────────────────
        Container(
          margin: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.gray200, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7257D8).withValues(alpha: 0.07),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: AppTheme.gray900.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(children: children),
        ),

        // ── Floating add button ───────────────────────────────────────────
        if (widget.onAddTap != null)
          Positioned(
            top: -floatingButtonSize * 0.2,
            child: _FloatingAddButton(onTap: widget.onAddTap!),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Single nav item
// ──────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final NavBarItemData data;
  final bool isActive;
  final bool isBouncing;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isActive,
    required this.isBouncing,
    required this.onTap,
  });

  Widget _buildIcon(Color color, double size) {
    if (data.iconAsset != null) {
      return Image.asset(
        data.iconAsset!,
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
      );
    }
    return Icon(data.icon, color: color, size: size);
  }

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AppBottomNavBar.activeColor : AppBottomNavBar.inactiveColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon with animated pill background ──────────────────────
              AnimatedScale(
                scale: isBouncing ? 1.28 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: isBouncing ? Curves.easeOut : Curves.easeIn,
                child: AnimatedSlide(
                  offset: isBouncing ? const Offset(0, -0.15) : Offset.zero,
                  duration: const Duration(milliseconds: 220),
                  curve: isBouncing ? Curves.easeOut : Curves.easeIn,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: isActive ? 38 : 30,
                    height: 27,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppBottomNavBar.activePillColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: _buildIcon(color, isActive ? 19 : 20),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // ── Label — FittedBox prevents overflow in any language ──────
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Floating add button
// ──────────────────────────────────────────────────────────────────────────────
class _FloatingAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _FloatingAddButton({required this.onTap});

  @override
  State<_FloatingAddButton> createState() => _FloatingAddButtonState();
}

class _FloatingAddButtonState extends State<_FloatingAddButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _rippleController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Gentle pulsing glow
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pressController.forward(from: 0).then((_) => _pressController.reverse());
    _rippleController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_pressController, _rippleController, _glowController]),
        builder: (context, child) {
          final press = Curves.easeOut.transform(_pressController.value);
          final scale =
              1 - 0.18 * (press < 0.5 ? press * 2 : (1 - press) * 2);
          final rotation = 135 *
              3.14159265 /
              180 *
              (press < 0.5 ? press * 2 : (1 - press) * 2);

          final ripple = _rippleController.value;
          final rippleScale = 0.4 + ripple * 1.2;
          final rippleOpacity = (0.35 * (1 - ripple)).clamp(0.0, 0.35);

          // Animated glow intensity
          final glowOpacity = 0.28 + 0.14 * _glowController.value;
          final glowBlur = 14.0 + 6.0 * _glowController.value;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9179E8), Color(0xFF7257D8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF7257D8).withValues(alpha: glowOpacity),
                    blurRadius: glowBlur,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple ring
                  Transform.scale(
                    scale: rippleScale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.white.withValues(alpha: rippleOpacity),
                      ),
                    ),
                  ),
                  // Rotating plus icon on press
                  Transform.rotate(
                    angle: rotation,
                    child: const Icon(
                      TablerIcons.plus,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
