import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../painters/asymmetric_background_painter.dart';
import '../../../theme/app_theme.dart';

/// Asymmetric SliverAppBar with parallax and organic shapes
class AsymmetricSliverHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData badgeIcon;
  final double expandedHeight;
  final double collapsedHeight;
  final Widget? trailing;
  final VoidCallback? onBackPressed;

  const AsymmetricSliverHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeIcon = Icons.category_rounded,
    this.expandedHeight = 320,
    this.collapsedHeight = 80,
    this.trailing,
    this.onBackPressed,
  });

  @override
  State<AsymmetricSliverHeader> createState() => _AsymmetricSliverHeaderState();
}

class _AsymmetricSliverHeaderState extends State<AsymmetricSliverHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      floating: false,
      delegate: _AsymmetricSliverHeaderDelegate(
        title: widget.title,
        subtitle: widget.subtitle,
        badge: widget.badge,
        badgeIcon: widget.badgeIcon,
        expandedHeight: widget.expandedHeight,
        collapsedHeight: widget.collapsedHeight,
        backgroundAnimation: _backgroundController,
        trailing: widget.trailing,
        onBackPressed: widget.onBackPressed,
      ),
    );
  }
}

class _AsymmetricSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData badgeIcon;
  final double expandedHeight;
  final double collapsedHeight;
  final AnimationController backgroundAnimation;
  final Widget? trailing;
  final VoidCallback? onBackPressed;

  _AsymmetricSliverHeaderDelegate({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.badgeIcon,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.backgroundAnimation,
    this.trailing,
    this.onBackPressed,
  });

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final currentExtent = maxExtent - shrinkOffset;

    return Stack(
      children: [
        // Animated background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: backgroundAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: AsymmetricBackgroundPainter(
                  animation: backgroundAnimation,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),

        // Content
        Positioned.fill(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: 1 - progress,
                            child: Opacity(
                              opacity: 1 - progress,
                              child: Transform.translate(
                                offset: Offset(0, progress * 30),
                                child: _buildExpandedContent(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                  },
            ),
          ),
        ),

        // Back button (positioned properly with SafeArea)
        Positioned(
          top: 0,
          left: 16,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildBackButton(),
            ),
          ),
        ),

        // Trailing widget (e.g., share button)
        if (trailing != null)
          Positioned(
            top: 0,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: trailing!,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final showBadge = availableHeight > 180 && badge != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge - Conditional based on available space
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            if (showBadge) const SizedBox(height: 20),

            // Title with overflow handling
            Text(
              title,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Subtitle with overflow handling
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onBackPressed ??
            () {
              final context = Globals.context;
              if (context != null) {
                Navigator.of(context).pop();
              }
            },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppTheme.gray900,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AsymmetricSliverHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        subtitle != oldDelegate.subtitle ||
        badge != oldDelegate.badge;
  }
}

/// Helper class for accessing navigator context
class Globals {
  static BuildContext? context;
}
