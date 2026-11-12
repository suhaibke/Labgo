import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Sticky section header with glassmorphism blur effect
class StickySectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final String? actionLabel;
  final bool isExpanded;

  const StickySectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.actionLabel,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.gray200,
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (actionLabel != null && onTap != null)
                TextButton.icon(
                  onPressed: onTap,
                  icon: AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                    ),
                  ),
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
