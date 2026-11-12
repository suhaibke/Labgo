import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../services/favorites_service.dart';

/// Labs listing/search screen - clean list of real labs with search and
/// specialization filtering.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Lab> _labs = [];
  List<Lab> _filteredLabs = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _selectedSpecialization;
  String? _token;
  String? _userCity; // User's city from their account for filtering

  final List<String> _specializations = [
    'Blood Tests',
    'X-Ray',
    'MRI',
    'CT Scan',
    'Ultrasound',
    'Pathology',
    'Microbiology',
    'Biochemistry',
    'Genetics',
    'Allergy',
    'Cardiology',
    'Neurology',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadFavorites();
    AuthService.profileVersion.addListener(_onProfileChanged);
  }

  /// This tab stays mounted (IndexedStack), so a city change made on the
  /// profile screen would otherwise never reach this cached copy.
  void _onProfileChanged() {
    _initializeData();
  }

  /// Warms the favorites cache so the heart icons paint in the correct state.
  Future<void> _loadFavorites() async {
    final ok = await FavoritesService.loadIds(force: true);
    if (ok && mounted) setState(() {});
  }

  Future<void> _initializeData() async {
    if (AuthService.isGuestMode) {
      // Guest mode: no token, no city filter
      if (mounted) {
        setState(() {
          _token = null;
          _userCity = null;
        });
      }
    } else {
      final token = await AuthService().getToken();
      final userData = await AuthService().getUserData();
      if (mounted) {
        setState(() {
          _token = token;
          _userCity = userData?['city'] as String?;
        });
      }
    }
    await _loadLabs();
  }

  Future<void> _loadLabs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Restrict to labs in the patient's own governorate - a lab in a
      // different city has nothing it can actually serve this patient.
      final result = await LabService.getAllLabs(
        token: _token,
        city: _userCity,
      );

      if (result['success'] == true) {
        final labsData = result['labs'] as List;
        final labs = labsData.map((json) => Lab.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _labs = labs;
            _filteredLabs = labs;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
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

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final result = await LabService.getAllLabs(
        token: _token,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        specialization: _selectedSpecialization,
      );

      if (result['success'] == true && mounted) {
        final labsData = result['labs'] as List;
        final labs = labsData.map((json) => Lab.fromJson(json)).toList();

        setState(() {
          _filteredLabs = labs;
          _isSearching = false;
        });
      } else if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedSpecialization = null;
      _filteredLabs = _labs;
    });
    HapticFeedback.lightImpact();
  }

  void _openFilterSheet() {
    String? tempSelected = _selectedSpecialization;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.specialization,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specializations.map((spec) {
                      final isSelected = tempSelected == spec;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            tempSelected = isSelected ? null : spec;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.gray100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            spec,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.white : AppTheme.gray700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedSpecialization = tempSelected);
                        Navigator.of(sheetContext).pop();
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        l10n.applyFilters,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    AuthService.profileVersion.removeListener(_onProfileChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLabs,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _LabsListHeader(
                  labCount: _filteredLabs.length,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onSearch: _performSearch,
                  onFilterTap: _openFilterSheet,
                  userCity: _userCity,
                ),
              ),

              // Results Section
              _isLoading
                  ? SliverFillRemaining(
                      child: _LoadingState(),
                    )
                  : _isSearching
                      ? SliverFillRemaining(
                          child: _SearchingState(),
                        )
                      : _filteredLabs.isEmpty
                          ? SliverFillRemaining(
                              child: _EmptyStateIllustration(
                                onResetFilters: _resetFilters,
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _LabListCard(lab: _filteredLabs[index]),
                                  childCount: _filteredLabs.length,
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

/// Header: back button, title with lab count, search bar, filter button and
/// a location chip showing the user's city.
class _LabsListHeader extends StatelessWidget {
  final int labCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onSearch;
  final VoidCallback onFilterTap;
  final String? userCity;

  const _LabsListHeader({
    required this.labCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
    required this.onFilterTap,
    required this.userCity,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'NEARBY CARE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$labCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.labs,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.gray900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search bar + filter button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(fontSize: 14, color: AppTheme.gray900),
                    decoration: InputDecoration(
                      hintText: l10n.searchByLabName,
                      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.gray400),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.gray400,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onFilterTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    TablerIcons.adjustments_horizontal,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userCity != null && userCity!.isNotEmpty
                        ? '$userCity - المختبرات داخل محافظتك'
                        : l10n.labsNearYou,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lab list card: flask icon square (left), wishlist heart (far right),
/// name/area/tests/rating, and status/discount pill badges.
class _LabListCard extends StatelessWidget {
  final Lab lab;

  const _LabListCard({required this.lab});

  static const _iconBg = Color(0xFFEEEDFE);
  static const _openBg = Color(0xFFE3F7EA);
  static const _openText = Color(0xFF1FA855);
  static const _discountBg = Color(0xFFFCE8E8);
  static const _discountText = Color(0xFFE0433D);

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
      margin: const EdgeInsets.only(bottom: 12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wishlist heart (far-right in RTL)
                  FavoriteHeartButton(labId: lab.id),

                  const SizedBox(width: 10),

                  // Lab info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lab.name,
                          style: const TextStyle(
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
                            style: const TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        if (lab.averageRating != null && lab.averageRating! > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
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
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Lab photo (left in RTL) - falls back to a flask icon
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
                ],
              ),

              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Pill(label: l10n.openNow, bg: _openBg, fg: _openText),
                  if (hasOffers && bestDiscount > 0)
                    _Pill(label: 'خصم $bestDiscount%', bg: _discountBg, fg: _discountText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.loadingLabs,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Searching state widget
class _SearchingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.searchingLabs,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state illustration with custom painter
class _EmptyStateIllustration extends StatelessWidget {
  final VoidCallback onResetFilters;

  const _EmptyStateIllustration({required this.onResetFilters});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom illustration
            SizedBox(
              height: 100,
              child: CustomPaint(
                painter: _EmptyStatePainter(),
                size: const Size(100, 100),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noLabsFound,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tryAdjustingFilters,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.resetFilters, overflow: TextOverflow.ellipsis, maxLines: 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for empty state illustration
class _EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    final bgPaint = Paint()
      ..color = AppTheme.gray200
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.4, bgPaint);

    // Magnifying glass
    final glassPaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.4),
      size.width * 0.15,
      glassPaint,
    );

    // Handle
    final handlePaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.52),
      Offset(size.width * 0.65, size.height * 0.65),
      handlePaint,
    );

    // Question mark
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
