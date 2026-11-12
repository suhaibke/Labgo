import 'package:flutter/material.dart';

/// Flat, single-color quick-action square (icon + label below), matching
/// the reference design exactly - no animation, no gradients.
class QuickActionSquare extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionSquare({
    super.key,
    this.icon,
    this.iconAsset,
    required this.label,
    required this.color,
    required this.onTap,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: iconAsset != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        iconAsset!,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: Color(0xFF3D3A50),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
