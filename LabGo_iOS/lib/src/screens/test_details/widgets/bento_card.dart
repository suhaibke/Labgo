import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Bento-style card with 3 size variants
/// RTL compatible and flexible for all languages
class BentoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final Gradient? gradient;
  final bool isLarge;
  final bool isMedium;
  final EdgeInsetsGeometry? padding;

  const BentoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.gradient,
    this.isLarge = false,
    this.isMedium = false,
    this.padding,
  });

  factory BentoCard.large({
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
    Gradient? gradient,
  }) {
    return BentoCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: backgroundColor,
      textColor: textColor,
      gradient: gradient,
      isLarge: true,
    );
  }

  factory BentoCard.medium({
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
    Gradient? gradient,
  }) {
    return BentoCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: backgroundColor,
      textColor: textColor,
      gradient: gradient,
      isMedium: true,
    );
  }

  factory BentoCard.small({
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
    Gradient? gradient,
  }) {
    return BentoCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      onTap: onTap,
      backgroundColor: backgroundColor,
      textColor: textColor,
      gradient: gradient,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ??
        (gradient != null ? null : AppTheme.white);

    final effectiveTextColor = textColor ?? AppTheme.gray900;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        padding: padding ??
            (isLarge
                ? const EdgeInsets.all(20)
                : isMedium
                    ? const EdgeInsets.all(16)
                    : const EdgeInsets.all(14)),
        decoration: BoxDecoration(
          gradient: gradient,
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(
            isLarge ? 22 : isMedium ? 18 : 16,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: isLarge ? 25 : 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: gradient == null
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: isLarge ? 52 : isMedium ? 44 : 38,
                height: isLarge ? 52 : isMedium ? 44 : 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    isLarge ? 14 : isMedium ? 12 : 10,
                  ),
                ),
                child: Icon(
                  icon,
                  size: isLarge ? 26 : isMedium ? 22 : 18,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: isLarge ? 14 : 10),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: isLarge ? 18 : isMedium ? 15 : 13,
                fontWeight: FontWeight.w700,
                color: effectiveTextColor,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: isLarge ? 13 : 12,
                  fontWeight: FontWeight.w500,
                  color: effectiveTextColor.withValues(alpha: 0.7),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
