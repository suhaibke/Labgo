import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/package_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../utils/package_share.dart';
import '../../widgets/auth_required_dialog.dart';
import '../order/order_confirmation_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Full details for a single package: its lab, constituent tests, combined
/// price, and a share link. Also the destination when a shared package
/// link (https://labgo-iq.com/p/:id) is opened with the app installed.
class PackageDetailScreen extends StatefulWidget {
  final String packageId;

  const PackageDetailScreen({super.key, required this.packageId});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  bool _isLoading = true;
  bool _isOrdering = false;
  PackageDetails? _package;
  String? _error;
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await PackageApi.getPackageDetails(widget.packageId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _package = result['package'] as PackageDetails;
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  String _testName(PackageTest test, String languageCode) {
    return languageCode == 'ar' && (test.nameAr?.isNotEmpty ?? false) ? test.nameAr! : test.name;
  }

  Future<void> _share() async {
    final pkg = _package;
    if (pkg == null) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    final text = packageShareText(
      packageId: pkg.id,
      packageName: pkg.displayName(languageCode),
      testNames: pkg.tests.map((test) => _testName(test, languageCode)).toList(),
      price: pkg.price,
    );

    // Without the Web Share API, share_plus falls back to a mailto: link,
    // which often does nothing visible. Copy the message instead.
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ تفاصيل الباقة والرابط')),
      );
      return;
    }

    // iPad presents the share sheet as a popover, which needs an anchor.
    final button = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      sharePositionOrigin: button == null ? null : button.localToGlobal(Offset.zero) & button.size,
    );
  }

  Future<void> _order() async {
    final pkg = _package;
    if (pkg == null) return;
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }
    if (_isOrdering) return;
    setState(() => _isOrdering = true);

    final result = await CartService.addPackage(labId: pkg.labId, packageId: pkg.id);
    if (!mounted) return;
    setState(() => _isOrdering = false);

    if (result['success'] == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(labId: pkg.labId, labName: pkg.labName),
        ),
      );
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _error != null || _package == null
                ? _buildError(context)
                : _buildContent(context, _package!),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      children: [
        _buildBackBar(context, share: false),
        Expanded(
          child: Center(
            child: Text(
              _error ?? 'تعذر العثور على الباقة',
              style: const TextStyle(color: AppTheme.gray500, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackBar(BuildContext context, {required bool share}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppTheme.gray900.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.gray700),
            ),
          ),
          const Spacer(),
          if (share)
            InkWell(
              key: _shareButtonKey,
              borderRadius: BorderRadius.circular(20),
              onTap: _share,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppTheme.gray900.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.share_outlined, size: 18, color: AppTheme.gray700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PackageDetails pkg) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Column(
      children: [
        _buildBackBar(context, share: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg.labName,
                  style: const TextStyle(fontSize: 13, color: AppTheme.gray500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  pkg.displayName(languageCode),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.gray900),
                ),
                if ((pkg.description ?? pkg.descriptionAr)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    languageCode == 'ar' ? (pkg.descriptionAr ?? pkg.description ?? '') : (pkg.description ?? ''),
                    style: const TextStyle(fontSize: 13, color: AppTheme.gray600, height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(TablerIcons.package, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${pkg.tests.length} تحليل ضمن الباقة',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${pkg.price} د.ع',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'الفحوصات المشمولة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.gray900),
                ),
                const SizedBox(height: 10),
                ...pkg.tests.map((test) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testName(test, languageCode),
                              style: const TextStyle(fontSize: 13, color: AppTheme.gray800),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isOrdering ? null : _order,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isOrdering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('اطلب الآن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}
