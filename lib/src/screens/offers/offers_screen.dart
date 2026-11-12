import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../../../l10n/app_localizations.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<OfferWithLab> _offers = [];
  List<OfferWithLab> _starredOffers = [];
  List<OfferWithLab> _regularOffers = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (AuthService.isGuestMode) {
      setState(() {
        _userData = null;
      });
    } else {
      final userData = await AuthService().getUserData();
      setState(() {
        _userData = userData;
      });
    }
    await _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = AuthService.isGuestMode ? null : await AuthService().getToken();
      final userCity = _userData?['city'] as String?;
      final result = await LabService.getLabsWithOffers(token: token, city: userCity);

      if (result['success'] == true && mounted) {
        final labsData = result['labs'] as List;
        final labs = labsData.map((json) => Lab.fromJson(json)).toList();

        // Flatten: Extract all offers with their lab info
        final List<OfferWithLab> allOffers = [];
        for (final lab in labs) {
          final offers = lab.activeOffers ?? lab.validOffers;
          for (final offer in offers) {
            allOffers.add(OfferWithLab(offer: offer, lab: lab));
          }
        }

        // Separate starred and regular offers
        final starred = allOffers.where((o) => o.offer.isStarred).toList();
        final regular = allOffers.where((o) => !o.offer.isStarred).toList();

        // Sort starred by starredAt (newest first)
        starred.sort((a, b) {
          final dateA = a.offer.starredAt ?? DateTime(2000);
          final dateB = b.offer.starredAt ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        // Sort regular by best discount (highest first)
        regular.sort((a, b) {
          final discountA = _getBestDiscount(a.offer);
          final discountB = _getBestDiscount(b.offer);
          return discountB.compareTo(discountA);
        });

        setState(() {
          _offers = allOffers;
          _starredOffers = starred;
          _regularOffers = regular;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load offers';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Get the best discount value from offer (checking applicableTests if needed)
  int _getBestDiscount(LabOffer offer) {
    // If offer has a direct discount value, use it
    if (offer.discountValue > 0) {
      return offer.discountValue;
    }

    // Otherwise, find the best discount from applicableTests
    if (offer.applicableTests != null && offer.applicableTests!.isNotEmpty) {
      double maxDiscount = 0;
      for (final test in offer.applicableTests!) {
        if (test.discountValue != null && test.discountValue! > maxDiscount) {
          maxDiscount = test.discountValue!;
        }
      }
      return maxDiscount.toInt();
    }

    return 0;
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppTheme.gray100,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, l10n),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState(l10n)
                      : _offers.isEmpty
                          ? _buildEmptyState(l10n)
                          : _buildOffersList(l10n, locale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppTheme.gray900,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title with offers icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.offers,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                  ),
                ),
                Text(
                  '${_offers.length} ${l10n.available}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          // User greeting
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getGreeting(l10n),
                style: const TextStyle(
                  color: AppTheme.gray500,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userData?['name']?.split(' ')[0] ?? 'User',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.gray200,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.errorLoadingData,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadOffers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noOffersAvailable,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noOffersDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadOffers,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l10n.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(AppLocalizations l10n, String locale) {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Starred offers section
            if (_starredOffers.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                title: l10n.starredOffers,
                count: _starredOffers.length,
              ),
              const SizedBox(height: 12),
              ..._starredOffers.map((offerWithLab) =>
                _buildOfferCard(offerWithLab, l10n, locale, isStarred: true)
              ),
              const SizedBox(height: 24),
            ],
            // Regular offers section
            if (_regularOffers.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.local_offer_rounded,
                iconColor: AppTheme.primaryColor,
                title: l10n.allOffers,
                count: _regularOffers.length,
              ),
              const SizedBox(height: 12),
              ..._regularOffers.map((offerWithLab) =>
                _buildOfferCard(offerWithLab, l10n, locale)
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.gray200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(OfferWithLab offerWithLab, AppLocalizations l10n, String locale, {bool isStarred = false}) {
    final offer = offerWithLab.offer;
    final lab = offerWithLab.lab;

    // Get the best discount (from offer or applicableTests)
    final bestDiscount = _getBestDiscount(offer);

    // Get localized label (which often contains the discount info like "خصم 20%")
    final label = offer.getLocalizedLabel(locale);

    // Calculate days remaining
    final daysRemaining = offer.endDate?.difference(DateTime.now()).inDays;
    final isEndingSoon = daysRemaining != null && daysRemaining <= 3 && daysRemaining >= 0;

    // Count applicable tests
    final testCount = offer.applicableTests?.length ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LabDetailsScreen(lab: lab),
          ),
        ).then((_) => _loadOffers());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isStarred
                  ? Colors.amber.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Lab logo
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.gray50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.gray200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: lab.hasValidLogo
                                  ? CachedNetworkImage(
                                      imageUrl: lab.logo!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.biotech_rounded,
                                        size: 28,
                                        color: AppTheme.gray400,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.biotech_rounded,
                                      size: 28,
                                      color: AppTheme.gray400,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Offer info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Offer name
                                Text(
                                  offer.getLocalizedName(locale),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.gray900,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Lab name with verification
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.science_outlined,
                                      size: 14,
                                      color: AppTheme.gray500,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        lab.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.gray600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (lab.isVerified == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Discount badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  bestDiscount > 0 ? '$bestDiscount%' : (label.isNotEmpty ? label : '-'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                                if (bestDiscount > 0)
                                  const Text(
                                    'OFF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Description if available
                      if (offer.getLocalizedDescription(locale) != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.gray50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppTheme.gray500,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  offer.getLocalizedDescription(locale)!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray700,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Bottom info bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.gray50,
                    border: Border(
                      top: BorderSide(color: AppTheme.gray100),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Location
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppTheme.gray500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lab.city ?? lab.fullAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Tags section
                      if (isEndingSoon) ...[
                        _buildTag(
                          icon: Icons.timer_outlined,
                          text: daysRemaining == 0
                              ? _getEndsTodayText(locale)
                              : _getEndsInText(daysRemaining, locale),
                          color: AppTheme.secondaryColor,
                        ),
                      ] else if (offer.applyToAllTests) ...[
                        _buildTag(
                          icon: Icons.check_circle_outline_rounded,
                          text: _getAllTestsText(locale),
                          color: AppTheme.success,
                        ),
                      ] else if (testCount > 0) ...[
                        _buildTag(
                          icon: Icons.science_outlined,
                          text: '$testCount ${l10n.tests}',
                          color: AppTheme.primaryColor,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
            // Star icon for starred offers
            if (isStarred)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getEndsTodayText(String locale) {
    switch (locale) {
      case 'ar':
        return 'ينتهي اليوم';
      case 'ku':
        return 'ئەمڕۆ تەواو دەبێت';
      case 'tr':
        return 'Bugün bitiyor';
      default:
        return 'Ends today';
    }
  }

  String _getEndsInText(int days, String locale) {
    switch (locale) {
      case 'ar':
        return '$days أيام متبقية';
      case 'ku':
        return '$days ڕۆژ ماوە';
      case 'tr':
        return '$days gün kaldı';
      default:
        return '$days days left';
    }
  }

  String _getAllTestsText(String locale) {
    switch (locale) {
      case 'ar':
        return 'جميع الفحوصات';
      case 'ku':
        return 'هەموو تێستەکان';
      case 'tr':
        return 'Tüm testler';
      default:
        return 'All tests';
    }
  }
}

// Helper class to hold offer with its lab info
class OfferWithLab {
  final LabOffer offer;
  final Lab lab;

  OfferWithLab({required this.offer, required this.lab});
}
