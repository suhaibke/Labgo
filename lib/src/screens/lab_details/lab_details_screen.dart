import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/cart_service.dart';
import '../../services/package_service.dart';
import '../../widgets/bilingual_test_name.dart';
import '../../widgets/package_card.dart';
import '../order/order_confirmation_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../widgets/app_map_tiles.dart';
import '../../widgets/favorite_heart_button.dart';

class LabDetailsScreen extends StatefulWidget {
  final Lab lab;
  final String? initialTab; // 'offers' to open offers section first

  const LabDetailsScreen({
    super.key,
    required this.lab,
    this.initialTab,
  });

  @override
  State<LabDetailsScreen> createState() => _LabDetailsScreenState();
}

class _LabDetailsScreenState extends State<LabDetailsScreen>
    with WidgetsBindingObserver {
  String _selectedSpecializationKey = 'all';
  int _cartCount = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  LatLng? _userLocation;
  bool _isLoadingUserLocation = false;
  late int _contentTab;
  final Set<String> _addingTestIds = {};
  List<String>? _cachedSpecKeys;
  List<LabTest>? _cachedFilteredTests;
  String? _cachedFilterKey;
  final ImagePicker _imagePicker = ImagePicker();
  bool _packagesLoading = true;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tabs order: tests (0), packages (1), offers (2) — matches reference RTL layout
    _contentTab = widget.initialTab == 'offers' ? 2 : 0;

    // Load cart count immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCartCount();
      _loadPackages();
    });

    if (widget.lab.hasCoordinates) {
      _loadUserLocation();
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLoadingUserLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoadingUserLocation = false;
        });
      }
    } catch (_) {
      // Silently fail - distance/user marker just won't be shown
      if (mounted) setState(() => _isLoadingUserLocation = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartCount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _specializationKeys {
    if (_cachedSpecKeys != null) return _cachedSpecKeys!;
    final specs = <String>[];
    if (widget.lab.specialization != null &&
        widget.lab.specialization!.isNotEmpty) {
      // Remove brackets if present and clean the string
      var cleanString = widget.lab.specialization!;
      cleanString = cleanString.replaceAll('[', '').replaceAll(']', '');
      cleanString = cleanString.replaceAll('"', '').replaceAll("'", '');

      final labSpecs = cleanString
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      specs.addAll(labSpecs);
    }
    _cachedSpecKeys = specs;
    return specs;
  }

  // Map specialization names to localization keys
  String _getSpecializationKey(String name) {
    final keyMap = {
      'Blood Tests': 'bloodTests',
      'X-Ray': 'xRay',
      'MRI': 'mri',
      'CT Scan': 'ctScan',
      'Ultrasound': 'ultrasound',
      'Pathology': 'pathology',
      'Microbiology': 'microbiology',
      'Biochemistry': 'biochemistry',
      'Genetics': 'genetics',
      'Allergy': 'allergy',
      'Cardiology': 'cardiology',
      'Neurology': 'neurology',
      'General': 'general',
    };
    return keyMap[name] ?? name;
  }

  // Get localized specialization name
  String _getSpecializationName(String keyOrName, AppLocalizations l10n) {
    if (keyOrName == 'all') return l10n.all;

    final getterMap = {
      'bloodTests': l10n.bloodTests,
      'xRay': l10n.xRay,
      'mri': l10n.mri,
      'ctScan': l10n.ctScan,
      'ultrasound': l10n.ultrasound,
      'pathology': l10n.pathology,
      'microbiology': l10n.microbiology,
      'biochemistry': l10n.biochemistry,
      'genetics': l10n.genetics,
      'allergy': l10n.allergy,
      'cardiology': l10n.cardiology,
      'neurology': l10n.neurology,
      'general': l10n.general,
    };

    return getterMap[keyOrName] ?? keyOrName;
  }

  List<LabTest> get _filteredTests {
    final key = '$_selectedSpecializationKey|$_searchQuery';
    if (_cachedFilterKey == key && _cachedFilteredTests != null) {
      return _cachedFilteredTests!;
    }

    List<LabTest> tests = widget.lab.testObjects ?? [];

    // Filter by specialization
    if (_selectedSpecializationKey != 'all') {
      final selectedCategory = _getSpecializationNameFromKey(_selectedSpecializationKey);
      tests = tests.where((test) => test.category == selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      tests = tests.where((test) =>
        test.arabicName.toLowerCase().contains(query) ||
        test.englishName.toLowerCase().contains(query)
      ).toList();
    }

    _cachedFilterKey = key;
    _cachedFilteredTests = tests;
    return tests;
  }

  // Get the original category name from the key for filtering
  String _getSpecializationNameFromKey(String key) {
    final nameMap = {
      'bloodTests': 'Blood Tests',
      'xRay': 'X-Ray',
      'mri': 'MRI',
      'ctScan': 'CT Scan',
      'ultrasound': 'Ultrasound',
      'pathology': 'Pathology',
      'microbiology': 'Microbiology',
      'biochemistry': 'Biochemistry',
      'genetics': 'Genetics',
      'allergy': 'Allergy',
      'cardiology': 'Cardiology',
      'neurology': 'Neurology',
      'general': 'General',
    };
    return nameMap[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final tests = _contentTab == 0 ? _filteredTests : const <LabTest>[];
    final offers = widget.lab.validOffers;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: CustomScrollView(
        cacheExtent: 480,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernHeader(l10n),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabIdentity(l10n),
                      const SizedBox(height: 16),
                      _buildQuickInfoRow(l10n),
                      if (widget.lab.hasCoordinates) ...[
                        const SizedBox(height: 16),
                        _buildLocationMapSection(l10n),
                      ],
                      const SizedBox(height: 16),
                      _buildContentTabs(l10n),
                      const SizedBox(height: 16),
                      if (_contentTab == 0) ...[
                        _buildSearchInput(l10n),
                        const SizedBox(height: 12),
                        _buildSpecializationsSlider(context, l10n),
                        const SizedBox(height: 16),
                        _buildTestsSectionHeader(l10n, tests.length),
                        const SizedBox(height: 12),
                      ],
                      if (_contentTab == 1) _buildPackagesTab(l10n, locale),
                      if (_contentTab == 2) _buildOffersTab(l10n, locale),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_contentTab == 0 && tests.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyTests(l10n)),
          if (_contentTab == 0 && tests.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final test = tests[index];
                    LabOffer? applicableOffer;
                    for (final offer in offers) {
                      if (offer.appliesToTest(test.id, test.code)) {
                        applicableOffer = offer;
                        break;
                      }
                    }
                    return RepaintBoundary(
                      child: _TestCard(
                        test: test,
                        offer: applicableOffer,
                        locale: locale,
                        adding: _addingTestIds.contains(test.id),
                        onTap: () => _openTest(test, applicableOffer),
                        onAdd: () => _addTestToCart(test, applicableOffer),
                      ),
                    );
                  },
                  childCount: tests.length,
                  addAutomaticKeepAlives: false,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCartButton(context, l10n),
    );
  }

  Widget _circleHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppTheme.gray800),
        ),
      ),
    );
  }

  Widget _buildModernHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 168,
          child: Stack(
            children: [
              Container(
                height: 168,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE4DFF8), Color(0xFFEEEAFB), Color(0xFFF5F2FC)],
                  ),
                ),
                child: Stack(
                  children: [
                    if (widget.lab.hasValidCoverImage) ...[
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: widget.lab.coverImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox.shrink(),
                          errorWidget: (context, url, error) => const SizedBox.shrink(),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.38),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Positioned(
                        top: -36,
                        right: -24,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -18,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 48,
                        left: 48,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    _circleHeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: FavoriteHeartButton(
                        labId: widget.lab.id,
                        size: 20,
                        inactiveColor: AppTheme.gray700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _circleHeaderButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () {
                        Share.share('${widget.lab.name}\n${widget.lab.fullAddress}');
                      },
                    ),
                  ],
                ),
              ),
              // Al-Taif banner: lab logo when available, otherwise test-tube icon
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.lab.hasValidLogo
                      ? CachedNetworkImage(
                          imageUrl: widget.lab.logo!,
                          fit: BoxFit.cover,
                          memCacheWidth: (78 * MediaQuery.devicePixelRatioOf(context)).round(),
                          memCacheHeight: (78 * MediaQuery.devicePixelRatioOf(context)).round(),
                          errorWidget: (context, url, error) => const Icon(
                            TablerIcons.test_pipe,
                            color: Colors.white,
                            size: 36,
                          ),
                        )
                      : const Icon(
                          TablerIcons.test_pipe,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabIdentity(AppLocalizations l10n) {
    final rating = widget.lab.averageRating ?? 0;
    final reviews = widget.lab.totalReviews ?? 0;
    final hasRating = rating > 0;
    final locationText = [
      if (widget.lab.address != null && widget.lab.address!.isNotEmpty) widget.lab.address,
      if (widget.lab.city != null && widget.lab.city!.isNotEmpty) widget.lab.city,
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.lab.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.gray900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        if (locationText.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (hasRating) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.gray800),
              ),
              if (reviews > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '(${l10n.reviewsCount(reviews)})',
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoChip(l10n.digitalResults),
            _infoChip(l10n.homeCollection),
            if (widget.lab.isVerified == true) _infoChip(l10n.accredited),
          ],
        ),
        if (widget.lab.description != null && widget.lab.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            widget.lab.description!,
            style: const TextStyle(fontSize: 13, color: AppTheme.gray500, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5A42B8),
        ),
      ),
    );
  }

  Widget _buildQuickInfoRow(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _quickInfoItem(
              icon: Icons.calendar_today_rounded,
              title: l10n.today,
              subtitle: l10n.nearestAppointment,
            ),
          ),
          Expanded(
            child: _quickInfoItem(
              icon: Icons.local_shipping_rounded,
              title: l10n.available,
              subtitle: l10n.homeCollection,
            ),
          ),
          Expanded(
            child: _quickInfoItem(
              icon: Icons.schedule_rounded,
              title: l10n.defaultWorkingHours,
              subtitle: l10n.workingHours,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gray900),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppTheme.gray500),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs(AppLocalizations l10n) {
    final tabs = [l10n.tests, l10n.packages, l10n.offers];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E6F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = _contentTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _contentTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppTheme.primaryColor : AppTheme.gray600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOffersTab(AppLocalizations l10n, String locale) {
    final offers = widget.lab.validOffers;
    if (offers.isEmpty) {
      return _emptyTabState(l10n.noOffersAvailable, l10n.noOffersDescription);
    }
    return Column(
      children: offers.map((offer) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_offer_rounded, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.getLocalizedName(locale),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.gray900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.getLocalizedLabel(locale),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPackagesTab(AppLocalizations l10n, String locale) {
    if (_packagesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    if (_packages.isEmpty) {
      return _emptyTabState(l10n.noPackagesAvailable, l10n.noOffersDescription);
    }

    return Column(
      children: _packages
          .map((pkg) => PackageCard(package: pkg, onReturned: _loadCartCount))
          .toList(),
    );
  }

  Future<void> _loadPackages() async {
    final result = await PackageApi.getPackages(
      labId: widget.lab.id,
      city: widget.lab.city,
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      _packagesLoading = false;
      if (result['success'] == true) {
        final list = result['packages'] as List<Package>;
        _packages = list.where((pkg) => pkg.labId == widget.lab.id).toList();
      } else {
        _packages = [];
      }
    });
  }

  Widget _emptyTabState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 42, color: AppTheme.gray400),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.gray800)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.gray500)),
        ],
      ),
    );
  }

  void _openTest(LabTest test, LabOffer? offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TestDetailsSheet(
        test: test,
        offer: offer,
        labId: widget.lab.id,
        labName: widget.lab.name,
        onAdded: () {
          _loadCartCount();
        },
        onConfirm: () async {
          Navigator.pop(context);
          await _openCheckout();
        },
      ),
    ).then((_) => _loadCartCount());
  }

  Future<void> _openCheckout() async {
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderConfirmationScreen(
          labId: widget.lab.id,
          labName: widget.lab.name,
        ),
      ),
    );
    if (mounted) _loadCartCount();
  }

  Future<void> _addTestToCart(LabTest test, LabOffer? offer) async {
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }
    if (_addingTestIds.contains(test.id)) return;
    setState(() => _addingTestIds.add(test.id));
    int? discountedPrice;
    if (offer != null) {
      discountedPrice = offer.calculateDiscountedPriceForTest(test.price, test.id, test.code);
    }
    final result = await CartService.addToCart(
      labId: widget.lab.id,
      testId: test.id,
      discountedPrice: discountedPrice,
    );
    if (!mounted) return;
    setState(() => _addingTestIds.remove(test.id));
    if (result['success'] == true) {
      await _loadCartCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testAddedSuccessfully), backgroundColor: AppTheme.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderCreationFailed), backgroundColor: AppTheme.error),
      );
    }
  }

  Widget? _buildFloatingCartButton(BuildContext context, AppLocalizations l10n) {
    // Confirm button appears only after at least one test is added
    if (_cartCount <= 0) return null;

    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: _openCheckout,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: screenWidth * 0.9,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, Color(0xFF6366F1)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              l10n.confirmOrder,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                '$_cartCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCartCount() async {
    if (AuthService.isGuestMode) {
      if (_cartCount != 0) setState(() => _cartCount = 0);
      return;
    }
    final result = await CartService.getCart();
    if (!mounted) return;
    final count = result['success'] == true && result['cart'] != null
        ? result['cart'].testCount as int
        : 0;
    if (count != _cartCount) {
      setState(() => _cartCount = count);
    }
  }

  Widget _buildLocationMapSection(AppLocalizations l10n) {
    final labLocation = LatLng(widget.lab.latitude!, widget.lab.longitude!);
    final userLocation = _userLocation;
    final distanceKm = userLocation != null
        ? const Distance().as(LengthUnit.Kilometer, labLocation, userLocation)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: RepaintBoundary(
              child: _LabMiniMap(
                labLocation: labLocation,
                userLocation: userLocation,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.social_distance_rounded,
                  size: 16,
                  color: AppTheme.gray500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    distanceKm != null
                        ? l10n.distanceAwayKm(distanceKm.toStringAsFixed(1))
                        : (_isLoadingUserLocation
                            ? l10n.calculatingDistance
                            : l10n.enableLocationForDistance),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.gray600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isLoadingUserLocation)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSpecializationsSlider(BuildContext context, AppLocalizations l10n) {
    // Prepend "all" key at the beginning
    final allKeys = [
      'all',
      ..._specializationKeys.map(_getSpecializationKey),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.laboratories,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allKeys.length,
            itemBuilder: (context, index) {
              final key = allKeys[index];
              final displayName = _getSpecializationName(key, l10n);
              final isSelected = _selectedSpecializationKey == key;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == allKeys.length - 1 ? 0 : 10,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSpecializationKey = key;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.gray700,
                        letterSpacing: 0.1,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchInput(AppLocalizations l10n) {
    // Home-style search without inner border/underline.
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppTheme.gray400, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                      if (!mounted) return;
                      setState(() => _searchQuery = value.trim());
                    });
                    final hadText =
                        _searchQuery.isNotEmpty || _searchController.text.isNotEmpty;
                    final willHave = value.isNotEmpty;
                    if (hadText != willHave) setState(() {});
                  },
                  style: const TextStyle(
                    color: AppTheme.gray800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  minLines: 1,
                  maxLines: 2,
                  cursorColor: AppTheme.primaryColor,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'البحث عن الفحوصات او ارفاق وصفة طبية',
                    hintMaxLines: 2,
                    hintStyle: TextStyle(
                      color: AppTheme.gray400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  _searchDebounce?.cancel();
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: Icon(Icons.close_rounded, color: AppTheme.gray400, size: 16),
                ),
              ),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _startPrescriptionOrder,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  TablerIcons.upload,
                  color: Color(0xFF3D2E8E),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPrescriptionOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(
            labId: widget.lab.id,
            labName: widget.lab.name,
            localPrescriptionImage: File(image.path),
            prescriptionOnly: true,
          ),
        ),
      );
      if (mounted) _loadCartCount();
    } catch (_) {
      // Ignore picker cancellation / platform errors
    }
  }

  Widget _buildTestsSectionHeader(AppLocalizations l10n, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.tests,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray900,
            letterSpacing: -0.3,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTests(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.gray400,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noTestsFound,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolated mini-map so parent setState (search/cart) doesn't recreate OSM tiles.
class _LabMiniMap extends StatelessWidget {
  final LatLng labLocation;
  final LatLng? userLocation;

  const _LabMiniMap({
    required this.labLocation,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final mapCenter = userLocation != null
        ? LatLng(
            (labLocation.latitude + userLocation!.latitude) / 2,
            (labLocation.longitude + userLocation!.longitude) / 2,
          )
        : labLocation;

    return FlutterMap(
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: userLocation != null ? 12 : 14,
        interactionOptions: const InteractionOptions(
          // Pinch only — avoids fighting the parent scroll gesture
          flags: InteractiveFlag.pinchZoom,
        ),
      ),
      children: [
        const AppMapTileLayer(),
        MarkerLayer(
          markers: [
            Marker(
              point: labLocation,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
            ),
            if (userLocation != null)
              Marker(
                point: userLocation!,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TestCard extends StatelessWidget {
  final LabTest test;
  final LabOffer? offer;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final bool adding;

  const _TestCard({
    required this.test,
    this.offer,
    required this.locale,
    required this.onTap,
    required this.onAdd,
    this.adding = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasOffer = offer != null;
    final discountedPrice = hasOffer
        ? offer!.calculateDiscountedPriceForTest(test.price, test.id, test.code)
        : test.price;
    final testDiscountValue = hasOffer
        ? offer!.getDiscountValueForTest(test.id, test.code)
        : 0.0;
    final priceText = hasOffer && testDiscountValue > 0
        ? '${NumberFormat('#,###', 'en_US').format(discountedPrice)} د.ع'
        : test.formattedPrice.replaceAll(' IQD', ' د.ع');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // In RTL this places the icon on the visual left (matches reference)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: BilingualTestName(
                              test: test,
                              arabicSize: 14.5,
                              englishSize: 11.5,
                              arabicWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (test.description != null && test.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          test.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                        ),
                      ],
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: adding ? null : onAdd,
                        child: adding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.info),
                              )
                            : Text(
                                l10n.addToOrder,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.info,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE7FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: test.hasImage
                      ? CachedNetworkImage(
                          imageUrl: test.image!,
                          fit: BoxFit.cover,
                          memCacheWidth: (46 * MediaQuery.devicePixelRatioOf(context)).round(),
                          memCacheHeight: (46 * MediaQuery.devicePixelRatioOf(context)).round(),
                          errorWidget: (context, url, error) => const Icon(
                            TablerIcons.test_pipe,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        )
                      : const Icon(TablerIcons.test_pipe, color: AppTheme.primaryColor, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TestDetailsSheet extends StatefulWidget {
  final LabTest test;
  final LabOffer? offer;
  final String labId;
  final String labName;
  final VoidCallback onAdded;
  final Future<void> Function() onConfirm;

  const _TestDetailsSheet({
    required this.test,
    this.offer,
    required this.labId,
    required this.labName,
    required this.onAdded,
    required this.onConfirm,
  });

  @override
  State<_TestDetailsSheet> createState() => _TestDetailsSheetState();
}

class _TestDetailsSheetState extends State<_TestDetailsSheet> {
  bool _adding = false;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    _checkInCart();
  }

  Future<void> _checkInCart() async {
    if (AuthService.isGuestMode) return;
    final inCart = await CartService.isTestInCart(widget.test.id);
    if (mounted) setState(() => _added = inCart);
  }

  Future<void> _addToOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToAddToCart);
      return;
    }
    if (_adding || _added) return;
    setState(() => _adding = true);

    int? discountedPrice;
    if (widget.offer != null) {
      discountedPrice = widget.offer!.calculateDiscountedPriceForTest(
        widget.test.price,
        widget.test.id,
        widget.test.code,
      );
    }

    final result = await CartService.addToCart(
      labId: widget.labId,
      testId: widget.test.id,
      discountedPrice: discountedPrice,
    );

    if (!mounted) return;
    setState(() {
      _adding = false;
      if (result['success'] == true) _added = true;
    });

    if (result['success'] == true) {
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testAddedSuccessfully), backgroundColor: AppTheme.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderCreationFailed), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final test = widget.test;
    final offer = widget.offer;
    final hasOffer = offer != null;
    final discountedPrice = hasOffer
        ? offer.calculateDiscountedPriceForTest(test.price, test.id, test.code)
        : test.price;
    final discountValue = hasOffer ? offer.getDiscountValueForTest(test.id, test.code) : 0.0;
    final priceText = hasOffer && discountValue > 0
        ? '${NumberFormat('#,###', 'en_US').format(discountedPrice)} د.ع'
        : test.formattedPrice.replaceAll(' IQD', ' د.ع');
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE7FB),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: test.hasImage
                              ? CachedNetworkImage(
                                  imageUrl: test.image!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: (64 * MediaQuery.devicePixelRatioOf(context)).round(),
                                  memCacheHeight: (64 * MediaQuery.devicePixelRatioOf(context)).round(),
                                  errorWidget: (c, u, e) => const Icon(
                                    TablerIcons.test_pipe,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                )
                              : const Icon(
                                  TablerIcons.test_pipe,
                                  color: AppTheme.primaryColor,
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BilingualTestName(
                                test: test,
                                arabicSize: 18,
                                englishSize: 13,
                                arabicWeight: FontWeight.w800,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    priceText,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  if (hasOffer && discountValue > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      test.formattedPrice.replaceAll(' IQD', ' د.ع'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.gray400,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (test.category != null && test.category!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EDFA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          test.category!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5A42B8),
                          ),
                        ),
                      ),
                    ],
                    if (test.description != null && test.description!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        l10n.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gray800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        test.description!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                    if (test.instructions != null && test.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.specialInstructions,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gray800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        test.instructions!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_adding || _added) ? null : _addToOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _added ? AppTheme.success : AppTheme.primaryColor,
                          disabledBackgroundColor: _added ? AppTheme.success : AppTheme.gray300,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _adding
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_added) ...[
                                    const Icon(Icons.check_rounded, size: 20),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    l10n.addToOrder,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_added) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => widget.onConfirm(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            l10n.confirmOrder,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
