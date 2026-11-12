import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/quick_service.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/therapeutic_prescription_sheet.dart';
import 'service_labs_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Full "View All" grid of admin-managed quick services, with a
/// prescription-upload banner at the bottom.
class QuickServicesListScreen extends StatefulWidget {
  const QuickServicesListScreen({super.key});

  @override
  State<QuickServicesListScreen> createState() => _QuickServicesListScreenState();
}

class _QuickServicesListScreenState extends State<QuickServicesListScreen> {
  bool _isLoading = true;
  List<QuickService> _services = [];

  static const _palette = [
    _CardColors(bg: Color(0xFFEAF3FE), fg: Color(0xFF2B6CB0)),
    _CardColors(bg: Color(0xFFFCEFDC), fg: Color(0xFFB8590F)),
    _CardColors(bg: Color(0xFFEEEDFE), fg: Color(0xFF5A42B8)),
    _CardColors(bg: Color(0xFFE1F5EE), fg: Color(0xFF0F7A5F)),
    _CardColors(bg: Color(0xFFFCEFEA), fg: Color(0xFFB84B2B)),
    _CardColors(bg: Color(0xFFEEEDFE), fg: Color(0xFF7257D8)),
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final result = await QuickServiceApi.getServices();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _services = result['services'] as List<QuickService>;
      }
    });
  }

  void _openPrescriptionFlow(AppLocalizations l10n) {
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToRequestNurse);
      return;
    }
    showTherapeuticPrescriptionSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadServices,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              BoxShadow(
                                color: AppTheme.gray900.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppTheme.gray700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.quickServicesTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.quickServicesSubtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                )
              else if (_services.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      l10n.noQuickServicesFound,
                      style: const TextStyle(color: AppTheme.gray500, fontSize: 14),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final service = _services[index];
                        final colors = _palette[index % _palette.length];
                        return _ServiceGridCard(
                          service: service,
                          colors: colors,
                          languageCode: languageCode,
                          bookNowLabel: l10n.bookNow,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ServiceLabsScreen(service: service),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _services.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: _PrescriptionBanner(
                    title: l10n.havePrescriptionQuestion,
                    subtitle: l10n.havePrescriptionSubtitle,
                    onTap: () => _openPrescriptionFlow(l10n),
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

class _CardColors {
  final Color bg;
  final Color fg;

  const _CardColors({required this.bg, required this.fg});
}

class _ServiceGridCard extends StatelessWidget {
  final QuickService service;
  final _CardColors colors;
  final String languageCode;
  final String bookNowLabel;
  final VoidCallback onTap;

  const _ServiceGridCard({
    required this.service,
    required this.colors,
    required this.languageCode,
    required this.bookNowLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gray900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: service.icon,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(
                  Icons.science_outlined,
                  color: colors.fg,
                  size: 22,
                ),
                placeholder: (context, url) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              service.displayName(languageCode),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (service.subtitle?.isNotEmpty ?? false) ...[
              const SizedBox(height: 3),
              Text(
                service.subtitle!,
                style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Text(
                  bookNowLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrescriptionBanner({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  TablerIcons.stethoscope,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
