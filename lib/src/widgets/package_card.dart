import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_theme.dart';
import '../services/package_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../screens/packages/package_detail_screen.dart';
import '../screens/order/order_confirmation_screen.dart';
import 'auth_required_dialog.dart';
import '../../l10n/app_localizations.dart';

class _CardColors {
  final Color bg;
  final Color fg;

  const _CardColors({required this.bg, required this.fg});
}

class PackageCard extends StatefulWidget {
  final Package package;
  final VoidCallback? onReturned;

  const PackageCard({super.key, required this.package, this.onReturned});

  @override
  State<PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<PackageCard> {
  bool _isOrdering = false;

  static const _palette = [
    _CardColors(bg: Color(0xFFE1F5EE), fg: Color(0xFF0F7A5F)),
    _CardColors(bg: Color(0xFFEEEDFE), fg: Color(0xFF5A42B8)),
    _CardColors(bg: Color(0xFFFCEFDC), fg: Color(0xFFB8590F)),
    _CardColors(bg: Color(0xFFFCEFEA), fg: Color(0xFFB84B2B)),
  ];

  IconData _categoryIcon() {
    switch (widget.package.category) {
      case 'Heart':
        return TablerIcons.heart;
      case 'Diabetes':
        return TablerIcons.droplet;
      case 'Women':
        return TablerIcons.gender_female;
      default:
        return TablerIcons.flask;
    }
  }

  Future<void> _openDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PackageDetailScreen(packageId: widget.package.id),
      ),
    );
    widget.onReturned?.call();
  }

  Future<void> _order() async {
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }
    if (_isOrdering) return;
    setState(() => _isOrdering = true);

    final result = await CartService.addPackage(
      labId: widget.package.labId,
      packageId: widget.package.id,
    );

    if (!mounted) return;
    setState(() => _isOrdering = false);

    if (result['success'] == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(
            labId: widget.package.labId,
            labName: widget.package.labName,
          ),
        ),
      );
      widget.onReturned?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? l10n.orderCreationFailed),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final isFeatured = package.isMostRequested;
    final colors = _palette[package.id.hashCode.abs() % _palette.length];
    final languageCode = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: _openDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isFeatured
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                )
              : null,
          color: isFeatured ? null : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppTheme.gray900.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isFeatured ? Colors.white.withValues(alpha: 0.18) : colors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(),
                size: 22,
                color: isFeatured ? Colors.white : colors.fg,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.labName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isFeatured ? Colors.white.withValues(alpha: 0.8) : AppTheme.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'الأكثر طلباً',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    package.displayName(languageCode),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isFeatured ? Colors.white : AppTheme.gray900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${package.testCount} تحليل',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isFeatured ? Colors.white.withValues(alpha: 0.85) : AppTheme.gray500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${package.price} د.ع',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isFeatured ? Colors.white : AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _isOrdering ? null : _order,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isFeatured ? Colors.white : AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isOrdering
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isFeatured ? AppTheme.primaryColor : Colors.white,
                                  ),
                                )
                              : Text(
                                  'اطلب الآن',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isFeatured ? AppTheme.primaryColor : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
