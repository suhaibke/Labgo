import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/lab_service.dart';
import '../../services/banner_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../main/main_screen.dart';
import '../search/search_screen.dart';
import '../packages/packages_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../services/favorites_service.dart';
import '../../widgets/quick_action_square.dart';
import '../../widgets/quick_services_row.dart';
import '../../widgets/therapeutic_prescription_sheet.dart';
import '../../services/quick_service.dart';
import '../search/service_labs_screen.dart';
import '../search/quick_services_list_screen.dart';
import '../../services/order_service.dart';
import '../order/order_details_screen.dart';
import '../order/new_order_flow_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/notifications_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  List<Lab> _labs = [];
  List<QuickService> _quickServices = [];
  List<Order> _recentOrders = [];
  bool _isLoading = true;
  String? _token;
  Map<String, dynamic>? _userData;
  bool _hasUnreadNotifications = false;

  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    _startAnimations();
    _loadQuickServices();
    _loadRecentOrders();
    _loadFavorites();
    _loadUnreadNotifications();
    AuthService.profileVersion.addListener(_onProfileChanged);
  }

  Future<void> _loadUnreadNotifications() async {
    if (AuthService.isGuestMode) return;
    final count = await NotificationsApi.getUnreadCount();
    if (mounted) setState(() => _hasUnreadNotifications = count > 0);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Badge may have changed while the list was open (marked as read).
    _loadUnreadNotifications();
  }

  /// The home tab stays mounted (IndexedStack), so a city change made on
  /// the profile screen would otherwise never reach this cached copy.
  void _onProfileChanged() {
    _initializeData();
  }

  /// Warms the favorites cache so the heart icons paint in the correct state.
  Future<void> _loadFavorites() async {
    final ok = await FavoritesService.loadIds(force: true);
    if (ok && mounted) setState(() {});
  }

  Future<void> _loadQuickServices() async {
    final result = await QuickServiceApi.getServices();
    if (mounted && result['success'] == true) {
      setState(() {
        _quickServices = result['services'] as List<QuickService>;
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    if (AuthService.isGuestMode) return;
    final result = await OrderService.getPatientOrders(limit: 3);
    if (mounted && result['success'] == true) {
      setState(() {
        _recentOrders = result['orders'] as List<Order>;
      });
    }
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _slideAnimationController.isDismissed) {
        _slideAnimationController.forward().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    AuthService.profileVersion.removeListener(_onProfileChanged);
    _scrollController.dispose();
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
      // A lab in a different governorate can't serve this patient, so both
      // the featured pick and the fallback list are restricted to their city.
      final userCity = _userData?['city'] as String?;

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

      // If no featured labs in this city, fall back to all active labs
      // there, sorted by rating.
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
        setState(() {
          _labs = labs;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
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
                      // Search Bar
                      _buildSearchBar(context, l10n),

                      // Promo Banner Carousel
                      const _PromoBanner(),

                      // Quick Actions Section
                      _buildQuickActions(context, l10n),

                      // Quick Services Row
                      QuickServicesRow(
                        services: _quickServices,
                        languageCode: Localizations.localeOf(context).languageCode,
                        onTap: (service) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ServiceLabsScreen(service: service),
                            ),
                          );
                        },
                        onViewAll: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const QuickServicesListScreen(),
                            ),
                          );
                        },
                      ),

                      // Section Header
                      _buildSectionHeader(context, l10n),

                      // Content
                      _buildContent(context, l10n),

                      // Recent Orders
                      _buildRecentOrdersSection(context, l10n),
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

  Widget _buildRecentOrdersSection(BuildContext context, AppLocalizations l10n) {
    if (_recentOrders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentOrders,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainScreen(initialIndex: 2),
                    ),
                  );
                },
                child: Text(
                  l10n.viewAll,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7257D8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentOrders.map((order) => _RecentOrderCard(order: order)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    final profilePicture = ApiService.resolveMediaUrl(_userData?['profilePicture'] as String?);
    final name = AuthService.isGuestMode
        ? l10n.guest
        : (_userData?['name']?.split(' ')[0] ?? 'User');
    final city = _userData?['city'] as String?;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatarBadge(profilePictureUrl: profilePicture, name: name),
              const Spacer(),
              Image.asset(
                'assets/images/logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              _NotificationBellButton(
                onTap: () {
                  if (AuthService.isGuestMode) {
                    showAuthRequiredDialog(
                      context,
                      message: l10n.loginToViewNotifications,
                    );
                  } else {
                    _openNotifications();
                  }
                },
                hasUnread: _hasUnreadNotifications,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${l10n.welcomeGuest} $name 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.healthMattersTagline,
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
          if (city != null && city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text(
                  '$city، العراق',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.gray600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openTherapeuticPrescription(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToRequestNurse);
      return;
    }
    await showTherapeuticPrescriptionSheet(context);
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.gray200, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppTheme.gray400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.searchForTestsOrLabs,
                    style: const TextStyle(
                      color: AppTheme.gray400,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openTherapeuticPrescription(context, l10n),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      TablerIcons.upload,
                      color: Color(0xFF3D2E8E),
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        children: [
          // Quick action tiles - New Request / Offers / Labs / Results / Prescription
          Row(
            children: [
              Expanded(
                child: QuickActionSquare(
                  icon: TablerIcons.plus,
                  label: l10n.newRequest,
                  color: const Color(0xFF7257D8),
                  onTap: () {
                    if (AuthService.isGuestMode) {
                      showAuthRequiredDialog(
                        context,
                        message: l10n.loginToAddToCart,
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewOrderFlowScreen(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: QuickActionSquare(
                  icon: TablerIcons.package,
                  label: l10n.packages,
                  color: const Color(0xFFEFA24B),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PackagesScreen(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: QuickActionSquare(
                  iconAsset: 'assets/images/flask_icon.png',
                  label: l10n.labs,
                  color: const Color(0xFF7257D8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: QuickActionSquare(
                  icon: TablerIcons.file_text,
                  label: l10n.myResults,
                  color: const Color(0xFF4BB4A8),
                  onTap: () {
                    if (AuthService.isGuestMode) {
                      showAuthRequiredDialog(
                        context,
                        message: l10n.loginToRequestNurse,
                      );
                      return;
                    }
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialIndex: 2),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: QuickActionSquare(
                  icon: TablerIcons.pill,
                  label: l10n.therapeuticPrescription,
                  color: const Color(0xFFD8509B),
                  onTap: () => _openTherapeuticPrescription(context, l10n),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.recommendedLaboratories,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            child: Text(
              l10n.viewAll,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7257D8),
              ),
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
          children: _labs.take(3).map((lab) => _MinimalLabCard(lab: lab)).toList(),
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

}

/// Auto-advancing promo banner carousel shown near the top of the home screen.
class _PromoBanner extends StatefulWidget {
  const _PromoBanner();

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;

  static const List<List<Color>> _slideGradients = [
    [AppTheme.primaryColor, Color(0xFF6B5FE0)],
    [Color(0xFFF4A900), Color(0xFFD49100)],
  ];

  List<HomeBanner> _banners = [];
  int _durationSeconds = 4;
  bool _loadedBanners = false;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final result = await BannerApi.getBanners();
    if (!mounted) return;
    setState(() {
      _banners = (result['banners'] as List<HomeBanner>?) ?? [];
      _durationSeconds = (result['durationSeconds'] as int?) ?? 4;
      _loadedBanners = true;
    });
    _startAutoAdvance(_slideCount);
  }

  void _startAutoAdvance(int count) {
    _autoAdvanceTimer?.cancel();
    if (count <= 1) return;
    _autoAdvanceTimer = Timer.periodic(Duration(seconds: _durationSeconds), (_) {
      if (!mounted || !_pageController.hasClients) return;
      // Skip when this tab is not visible (IndexedStack + TickerMode)
      if (!TickerMode.of(context)) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  int get _slideCount => _banners.isNotEmpty ? _banners.length : 2;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Real admin-managed banners once loaded; otherwise (or if none are
    // configured yet) fall back to the built-in gradient slides so the
    // home page never looks empty.
    final useRealBanners = _loadedBanners && _banners.isNotEmpty;
    final slides = [
      (title: l10n.specialOffers, subtitle: l10n.limitedTimeOffer),
      (title: l10n.bannerWelcomeTitle, subtitle: l10n.bannerWelcomeSubtitle),
    ];
    final itemCount = useRealBanners ? _banners.length : slides.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: itemCount,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                if (useRealBanners) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PackagesScreen(),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CachedNetworkImage(
                        imageUrl: _banners[index].imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _slideGradients[index % _slideGradients.length],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final slide = slides[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PackagesScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _slideGradients[index],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slide.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slide.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.exploreNow,
                                      style: TextStyle(
                                        color: _slideGradients[index][0],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_back_rounded, size: 14, color: _slideGradients[index][0]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.local_offer_rounded,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(itemCount, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.gray300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
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

  static const _iconBg = Color(0xFFEEEDFE);
  static const _openGreen = Color(0xFF1FA855);

  String _buildSubtitle() {
    final parts = <String>[];
    if (lab.city != null && lab.city!.isNotEmpty) parts.add(lab.city!);
    if (lab.address != null && lab.address!.isNotEmpty) parts.add(lab.address!);
    if (lab.totalTestsPerformed != null && lab.totalTestsPerformed! > 0) {
      parts.add('${lab.totalTestsPerformed}+ فحص');
    }
    return parts.join('، ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasOffers = lab.hasActiveOffers;
    final bestDiscount = lab.bestDiscount ?? 0;
    final subtitle = _buildSubtitle();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Wishlist heart (far-right in RTL)
              FavoriteHeartButton(labId: lab.id),

              const SizedBox(width: 10),

              // Lab Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lab.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.gray900,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray500,
                              fontSize: 12,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          l10n.openNow,
                          style: const TextStyle(
                            color: _openGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (lab.averageRating != null && lab.averageRating! > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            lab.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Lab photo (left in RTL) - falls back to a flask icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: lab.hasValidLogo
                        ? CachedNetworkImage(
                            imageUrl: lab.logo!,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            errorWidget: (context, url, error) => const Icon(
                              TablerIcons.flask,
                              size: 22,
                              color: AppTheme.primaryColor,
                            ),
                            placeholder: (context, url) => const SizedBox.shrink(),
                          )
                        : const Icon(
                            TablerIcons.flask,
                            size: 22,
                            color: AppTheme.primaryColor,
                          ),
                  ),
                  if (hasOffers && bestDiscount > 0)
                    Positioned(
                      top: -6,
                      left: -6,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact card for a single recent order in the home page's "Recent
/// Orders" list.
class _RecentOrderCard extends StatelessWidget {
  final Order order;

  const _RecentOrderCard({required this.order});

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final labName = order.labData?['name']?.toString() ?? '';
    final shortRef = order.id.length >= 6
        ? order.id.substring(order.id.length - 6).toUpperCase()
        : order.id.toUpperCase();
    final date = order.createdAt;
    final dateLabel = '${date.day} ${_arabicMonths[date.month - 1]} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gray100, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  TablerIcons.file_text,
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
                      labName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateLabel • #$shortRef',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.gray300),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular profile picture with a purple ring border, falling back to the
/// user's initial when there's no picture set.
class _ProfileAvatarBadge extends StatelessWidget {
  final String? profilePictureUrl;
  final String name;

  const _ProfileAvatarBadge({required this.profilePictureUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      child: ClipOval(
        child: Container(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: profilePictureUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                  memCacheHeight: (44 * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorWidget: (context, url, error) => Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Notification bell shortcut shown in the home app bar. Shows a small
/// unread-indicator dot only when [hasUnread] is true.
class _NotificationBellButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasUnread;

  const _NotificationBellButton({required this.onTap, this.hasUnread = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/notification_bell.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            if (hasUnread)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
