import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Search Screen with "Scientific Discovery" aesthetic.
/// Features animated gradient hero, floating filter chips, and masonry grid results.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _heroAnimationController;
  late AnimationController _filterAnimationController;
  late Animation<double> _heroFadeAnimation;
  late Animation<Offset> _heroSlideAnimation;
  late Animation<double> _filterStaggerAnimation;

  // For masonry layout
  // final List<double> _columnHeights = [0.0, 0.0];
  // int _shortestColumn = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    // Removed: _scrollController.addListener(_onScroll) - was causing scroll issues
  }

  void _initializeAnimations() {
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heroFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _heroSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _filterStaggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _filterAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _heroAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _filterAnimationController.forward();
    });
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
      // Filter by user's city from their account
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
      // Always filter by user's city from their account
      final result = await LabService.getAllLabs(
        token: _token,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        city: _userCity,
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

  void _toggleSpecialization(String? spec) {
    setState(() {
      _selectedSpecialization = _selectedSpecialization == spec ? null : spec;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _heroAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: RefreshIndicator(
        onRefresh: _loadLabs,
        color: AppTheme.primaryColor,
        edgeOffset: 120, // Offset to account for hero section
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Animated Gradient Hero
            SliverToBoxAdapter(
              child: _AnimatedGradientHero(
                fadeAnimation: _heroFadeAnimation,
                slideAnimation: _heroSlideAnimation,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearch: _performSearch,
                isSearching: _isSearching,
                labs: _labs,
              ),
            ),

            // Floating Filter Chips
            SliverToBoxAdapter(
              child: _FilterChipsSection(
                staggerAnimation: _filterStaggerAnimation,
                specializations: _specializations,
                selectedSpecialization: _selectedSpecialization,
                onSpecializationToggle: _toggleSpecialization,
                onPerformSearch: _performSearch,
                onResetFilters: _resetFilters,
                isSearching: _isSearching,
                hasActiveFilters: _searchController.text.isNotEmpty ||
                    _selectedSpecialization != null,
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
                        : _UniformGridResults(
                            labs: _filteredLabs,
                          ),

            // Bottom padding for floating elements
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated gradient hero section with organic shapes and glassmorphism
class _AnimatedGradientHero extends StatefulWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onSearch;
  final bool isSearching;
  final List<Lab> labs;

  const _AnimatedGradientHero({
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
    required this.isSearching,
    required this.labs,
  });

  @override
  State<_AnimatedGradientHero> createState() => _AnimatedGradientHeroState();
}

class _AnimatedGradientHeroState extends State<_AnimatedGradientHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: widget.fadeAnimation.value,
          child: Transform.translate(
            offset: widget.slideAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        // Use tighter constraints to prevent overflow
        constraints: const BoxConstraints.tightFor(height: 340),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDark,
              const Color(0xFF6366F1),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated gradient mesh background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _GradientMeshPainter(
                      animation: _gradientController,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),

            // Decorative circles
            Positioned(
              top: -60,
              right: -60,
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _gradientController.value * 2 * math.pi,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_gradientController.value * 2 * math.pi,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      l10n.discoverLabs,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.findPerfectLab,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Row
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.science_rounded,
                          label: l10n.labs,
                          value: widget.labs.length.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Glassmorphism Search Input
                    _ModernSearchInput(
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      onSearch: widget.onSearch,
                      isSearching: widget.isSearching,
                    ),
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

/// Custom painter for animated gradient mesh with organic shapes
class _GradientMeshPainter extends CustomPainter {
  final Animation<double> animation;

  _GradientMeshPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = AppTheme.primaryLight.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final paint3 = Paint()
      ..color = AppTheme.secondaryColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Organic blob shapes with animation
    final blob1 = _createBlobPath(
      size.width * 0.8,
      size.height * 0.3,
      100 + math.sin(animation.value * 2 * math.pi) * 20,
    );
    final blob2 = _createBlobPath(
      size.width * 0.2,
      size.height * 0.7,
      80 + math.cos(animation.value * 2 * math.pi) * 15,
    );
    final blob3 = _createBlobPath(
      size.width * 0.7,
      size.height * 0.8,
      120 + math.sin(animation.value * math.pi) * 25,
    );

    canvas.drawPath(blob1, paint1);
    canvas.drawPath(blob2, paint2);
    canvas.drawPath(blob3, paint3);
  }

  Path _createBlobPath(double x, double y, double radius) {
    final path = Path();
    final angleStep = 2 * math.pi / 8;

    for (int i = 0; i < 8; i++) {
      final angle = i * angleStep;
      final r = radius * (0.8 + 0.2 * math.sin(angle * 3));
      final px = x + r * math.cos(angle);
      final py = y + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _GradientMeshPainter oldDelegate) => true;
}

/// Animated stat card for hero section
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modern glassmorphism search input with focus animations
class _ModernSearchInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSearch;
  final bool isSearching;

  const _ModernSearchInput({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.isSearching,
  });

  @override
  State<_ModernSearchInput> createState() => _ModernSearchInputState();
}

class _ModernSearchInputState extends State<_ModernSearchInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _borderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _borderController,
        curve: Curves.easeOut,
      ),
    );

    widget.focusNode.addListener(() {
      setState(() {
        _hasFocus = widget.focusNode.hasFocus;
      });
      if (_hasFocus) {
        _borderController.forward();
      } else {
        _borderController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedBuilder(
            animation: _borderAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor
                        .withValues(alpha: 0.3 + _borderAnimation.value * 0.5),
                    width: 1.5 + _borderAnimation.value * 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        onSubmitted: (_) => widget.onSearch(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gray900,
                          letterSpacing: -0.2,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.searchByLabName,
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.gray400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (widget.controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          widget.controller.clear();
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.gray100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.onSearch();
                        HapticFeedback.mediumImpact();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _hasFocus
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: widget.isSearching
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Floating filter chips section with horizontal scroll
class _FilterChipsSection extends StatelessWidget {
  final Animation<double> staggerAnimation;
  final List<String> specializations;
  final String? selectedSpecialization;
  final Function(String?) onSpecializationToggle;
  final VoidCallback onPerformSearch;
  final VoidCallback onResetFilters;
  final bool isSearching;
  final bool hasActiveFilters;

  const _FilterChipsSection({
    required this.staggerAnimation,
    required this.specializations,
    required this.selectedSpecialization,
    required this.onSpecializationToggle,
    required this.onPerformSearch,
    required this.onResetFilters,
    required this.isSearching,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RepaintBoundary(
      child: Container(
        color: AppTheme.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Specialization Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.specialization,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: specializations.length + 1,
                itemBuilder: (context, index) {
                  if (index < specializations.length) {
                    final spec = specializations[index];
                    final isSelected = selectedSpecialization == spec;
                    return _FilterChip(
                      label: spec,
                      isSelected: isSelected,
                      onTap: () => onSpecializationToggle(spec),
                      delay: index * 30,
                    );
                  } else {
                    return const SizedBox(width: 8);
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSearching ? null : onPerformSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: isSearching
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.applyFilters,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: TextButton.icon(
                        onPressed: onResetFilters,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.gray600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(
                          l10n.reset,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual filter chip with tap animation
class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.delay = 0,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_FilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: widget.delay)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scaleAnimation.value - 1.0) * 0.1,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: widget.isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryDark,
                              ],
                            )
                          : null,
                      color: widget.isSelected
                          ? null
                          : AppTheme.gray100.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: widget.isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3 * _glowAnimation.value),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                      border: Border.all(
                        color: widget.isSelected
                            ? Colors.transparent
                            : AppTheme.gray200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? AppTheme.white
                                : AppTheme.gray700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (widget.isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppTheme.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Uniform grid layout for search results
class _UniformGridResults extends StatelessWidget {
  final List<Lab> labs;

  const _UniformGridResults({
    required this.labs,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _UniformLabCard(
              lab: labs[index],
              index: index,
            );
          },
          childCount: labs.length,
        ),
      ),
    );
  }
}

/// Uniform lab card with full-width logo (matching nurse request screen design)
class _UniformLabCard extends StatefulWidget {
  final Lab lab;
  final int index;

  const _UniformLabCard({
    required this.lab,
    required this.index,
  });

  @override
  State<_UniformLabCard> createState() => _UniformLabCardState();
}

class _UniformLabCardState extends State<_UniformLabCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRating = widget.lab.averageRating != null && widget.lab.averageRating! > 0;
    final isVerified = widget.lab.isVerified == true;
    final hasReviews = widget.lab.totalReviews != null && widget.lab.totalReviews! > 0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LabDetailsScreen(lab: widget.lab),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-width logo section
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                          AppTheme.primaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: widget.lab.hasValidLogo
                        ? ClipRRect(
                            child: CachedNetworkImage(
                              imageUrl: widget.lab.logo!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  Icons.science_rounded,
                                  size: 40,
                                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.science_rounded,
                              size: 40,
                              color: AppTheme.primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                ),

                // Content section
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Lab name
                        Text(
                          widget.lab.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.gray900,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Badges row
                        Row(
                          children: [
                            if (hasRating)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: AppTheme.secondaryColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.lab.averageRating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: AppTheme.gray800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (hasReviews) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        '(${widget.lab.totalReviews})',
                                        style: const TextStyle(
                                          color: AppTheme.gray500,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            if (hasRating && isVerified) const SizedBox(width: 4),
                            if (isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      AppLocalizations.of(context)!.verified,
                                      style: const TextStyle(
                                        color: AppTheme.gray700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
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
              label: Text(l10n.resetFilters),
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
