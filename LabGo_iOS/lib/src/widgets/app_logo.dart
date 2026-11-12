import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double height;
  final bool showText;

  const AppLogo({
    super.key,
    this.width,
    this.height = 80,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final logoWidth = width ?? MediaQuery.of(context).size.width * 0.9;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Image - Clean, no background
        Image.asset(
          'assets/images/logo.png',
          width: logoWidth,
          height: height,
          fit: BoxFit.contain,
        ),

        if (showText) ...[

          const SizedBox(height: 4),

          // Tagline
          Text(
            l10n.appTagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray600,
                ),
          ),
        ],
      ],
    );
  }
}
