import 'package:flutter/material.dart';

/// Bento grid layout with responsive sizing and RTL support
class BentoGridLayout extends StatelessWidget {
  final List<BentoGridItem> items;
  final double spacing;

  const BentoGridLayout({
    super.key,
    required this.items,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildLayout(context),
    );
  }

  Widget _buildLayout(BuildContext context) {
    // Use IntrinsicHeight to properly size items
    final List<Widget> rows = [];

    for (int i = 0; i < items.length; i += 2) {
      final firstItem = items[i];
      final secondItem = i + 1 < items.length ? items[i + 1] : null;

      if (firstItem.isLarge) {
        // Large item takes full width
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: firstItem.child,
          ),
        );

        // Add second item if it exists
        if (secondItem != null && !secondItem.isLarge) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: secondItem!.child,
            ),
          );
        }
      } else {
        // Two items in a row - use IntrinsicHeight for proper sizing
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: firstItem.child,
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: secondItem != null
                        ? secondItem.child
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Data class for bento grid items
class BentoGridItem {
  final Widget child;
  final bool isLarge;

  BentoGridItem({
    required this.child,
    this.isLarge = false,
  });

  factory BentoGridItem.large({
    required Widget child,
  }) {
    return BentoGridItem(
      child: child,
      isLarge: true,
    );
  }

  factory BentoGridItem.medium({
    required Widget child,
  }) {
    return BentoGridItem(
      child: child,
      isLarge: false,
    );
  }

  factory BentoGridItem.small({
    required Widget child,
  }) {
    return BentoGridItem(
      child: child,
      isLarge: false,
    );
  }
}
