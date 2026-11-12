import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../main/main_screen.dart';
import '../nurse_request/nurse_request_screen.dart';
import '../offers/offers_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' as main;
import '../../widgets/auth_required_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  List<Lab> _labs = [];
  bool _isLoading = true;
  String? _token;
  Map<String, dynamic>? _userData;
  int _totalTests = 0;

  late AnimationController _cardAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardOpacityAnimation;
  late Animation<Offset> _slideAnimation;

  // Language data
  static const Map<String, Locale> _languages = {
    'العربية': Locale('ar'),
    'Kurdî': Locale('ku'),
    'Türkçe': Locale('tr'),
    'English': Locale('en'),
  };

  String _selectedLanguage = 'العربية';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    _startAnimations();
  }

  void _initializeAnimations() {
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _cardAnimationController.isDismissed) {
        _cardAnimationController.forward().catchError((_) {});
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _slideAnimationController.isDismissed) {
        _slideAnimationController.forward().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cardAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (AuthService.isGuestMode) {
      // Guest mode: no token, no user data
      setState(() {
        _token = null;
        _userData = null;
      });
    } else {
      final token = await AuthService().getToken();
      final userData = await AuthService().getUserData();

      setState(() {
        _token = token;
        _userData = userData;
      });
    }

    await _loadLabs();
  }

  Future<void> _loadLabs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user's city for filtering
      final userCity = _userData?['city'] as String?;

      // First, try to get featured labs (selected by admin)
      final featuredResult = await LabService.getFeaturedLabs(
        token: _token,
        limit: 10,
        city: userCity,
      );

      List<Lab> labs = [];

      if (featuredResult['success'] == true) {
        final labsData = featuredResult['labs'] as List;
        labs = labsData.map((json) => Lab.fromJson(json)).toList();
      }

      // If no featured labs, fall back to all labs sorted by rating
      if (labs.isEmpty) {
        final result = await LabService.getAllLabs(token: _token, city: userCity);
        if (result['success'] == true) {
          final labsData = result['labs'] as List;
          labs = labsData.map((json) => Lab.fromJson(json)).toList();

          // Sort by rating (highest first) as fallback
          labs.sort((a, b) {
            final ratingA = a.averageRating ?? 0;
            final ratingB = b.averageRating ?? 0;
            return ratingB.compareTo(ratingA);
          });
        }
      }

      if (mounted) {
        // Calculate total tests from all labs
        int totalTests = 0;
        for (var lab in labs) {
          // Count tests from the tests array
          if (lab.tests != null && lab.tests!.isNotEmpty) {
            totalTests += lab.tests!.length;
          } else {
            // If tests array is not available, use totalTestsPerformed
            totalTests += lab.totalTestsPerformed ?? 0;
          }
        }

        setState(() {
          _labs = labs;
          _totalTests = totalTests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              onTap: () {
                final appState = main.LabGoApp.of(context);
                appState?.setLocale(entry.value);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _selectedLanguage = _languages.entries
        .firstWhere(
          (entry) => entry.value.languageCode == Localizations.localeOf(context).languageCode,
          orElse: () => _languages.entries.first,
        )
        .key;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar with Logo (centered), Language (left), Name (right)
            _buildAppBar(context, l10n),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadLabs,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Highlight Card
                      _buildHighlightCard(context, l10n),

                      // Quick Actions Section
                      _buildQuickActions(context, l10n),

                      // Section Header
                      _buildSectionHeader(context, l10n),

                      // Content
                      _buildContent(context, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Language Selector (Left)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => _showLanguageDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedLanguage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppTheme.gray700,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Logo (Centered)
          Image.asset(
            'assets/images/logo.png',
            height: 56,
            fit: BoxFit.contain,
          ),

          const Spacer(),

          // User Name (Right)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getGreeting(l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                      fontSize: 11,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                AuthService.isGuestMode
                    ? l10n.guest
                    : (_userData?['name']?.split(' ')[0] ?? 'User'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(BuildContext context, AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Opacity(
            opacity: _cardOpacityAnimation.value,
            child: _MetricsCard(
              l10n: l10n,
              labsCount: _labs.length,
              totalTests: _totalTests,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          // First Row - Labs + Offers (side by side)
          Row(
            children: [
              // Labs Card - Blue
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.biotech_rounded,
                  title: l10n.labs,
                  subtitle: '${_labs.length} ${l10n.available}',
                  color: const Color(0xFF4A90E2),
                  onTap: () {
                    // Navigate to Search tab
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialIndex: 1),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Offers Card - Red/Pink (moved to Row 1)
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.local_offer_rounded,
                  title: l10n.offers,
                  subtitle: l10n.specialOffers,
                  color: const Color(0xFFE53935),
                  onTap: () {
                    // Navigate to Offers Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OffersScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Second Row - Request Nurse Button - Gold
          _RequestNurseButton(
            title: l10n.requestANurse,
            subtitle: l10n.homeVisitSampleCollection,
            onTap: () {
              if (AuthService.isGuestMode) {
                showAuthRequiredDialog(
                  context,
                  message: l10n.loginToRequestNurse,
                );
                return;
              }
              // Navigate to Nurse Request Screen (no lab selection needed)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NurseRequestScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.featuredLaboratories,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                  letterSpacing: -0.5,
                ),
          ),
          Text(
            '${_labs.length} ${l10n.laboratoriesFound}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.gray500,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return _buildLoadingState(context, l10n);
    }

    if (_labs.isEmpty) {
      return _buildEmptyState(context, l10n);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: _labs.map((lab) => _MinimalLabCard(lab: lab)).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadingLaboratories,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noLaboratoriesFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.gray800,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.checkBackLater,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }
}

// Metrics Card Widget - Apple-style clean metrics display
class _MetricsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final int labsCount;
  final int totalTests;

  const _MetricsCard({
    required this.l10n,
    required this.labsCount,
    required this.totalTests,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8378F4),
            Color(0xFF9D94F7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8378F4).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Decorative Elements
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF4A900).withValues(alpha: 0.08),
                ),
              ),
            ),

            // Subtle grid pattern overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _DotPatternPainter(),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Promotional Text
                  Text(
                    l10n.labTestsAtYourDoorstep,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.bookTestGetSampleAtHomeReceiveResultsOnline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Metrics - 2 items only
                  Row(
                    children: [
                      Expanded(
                        child: _MetricItem(
                          icon: Icons.biotech_rounded,
                          value: '$totalTests+',
                          label: l10n.tests,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MetricItem(
                          icon: Icons.business_rounded,
                          value: '$labsCount+',
                          label: l10n.laboratories,
                          color: const Color(0xFFF4A900),
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

// Custom painter for subtle dot pattern
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    const dotSize = 3.0;
    const spacing = 20.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Individual Metric Item
class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Minimal Lab Card
class _MinimalLabCard extends StatelessWidget {
  final Lab lab;

  const _MinimalLabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final hasOffers = lab.hasActiveOffers;
    final bestDiscount = lab.bestDiscount ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOffers ? Colors.red.withValues(alpha: 0.3) : AppTheme.gray100,
          width: hasOffers ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LabDetailsScreen(
                lab: lab,
                initialTab: hasOffers ? 'offers' : null,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Minimal Logo with offer badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: lab.hasValidLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: lab.logo!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.science_rounded,
                                size: 24,
                                color: AppTheme.gray400,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.science_rounded,
                            size: 24,
                            color: AppTheme.gray400,
                          ),
                  ),
                  // Offer badge
                  if (hasOffers && bestDiscount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-$bestDiscount%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // Lab Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Row
                    Text(
                      lab.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.gray900,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Location - Minimal
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            lab.fullAddress,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.gray500,
                                  fontSize: 12,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Stats Row - Minimal
                    if (lab.averageRating != null || lab.totalTestsPerformed != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (lab.averageRating != null && lab.averageRating! > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lab.averageRating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.gray700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                            ),
                            if (lab.totalReviews != null && lab.totalReviews! > 0) ...[
                              Text(
                                ' (${lab.totalReviews})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.gray400,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ],
                          if (lab.averageRating != null &&
                              lab.averageRating! > 0 &&
                              lab.totalTestsPerformed != null &&
                              lab.totalTestsPerformed! > 0)
                            const SizedBox(width: 10),
                          if (lab.totalTestsPerformed != null && lab.totalTestsPerformed! > 0)
                            Text(
                              '${lab.totalTestsPerformed}+ tests',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.gray500,
                                    fontSize: 12,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.gray300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 100,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray900,
                              fontSize: 14,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: color.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestNurseButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RequestNurseButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFF4A900);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 72,
          ),
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Color(0xFFF4A900),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray900,
                              fontSize: 14,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: goldColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
