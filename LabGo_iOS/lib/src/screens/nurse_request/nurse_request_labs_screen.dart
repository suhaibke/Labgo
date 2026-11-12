import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Modern, colorful lab selection for nurse requests.
/// Apple-inspired design with gradients, shadows, and vibrant accents.
class NurseRequestLabsScreen extends StatefulWidget {
  const NurseRequestLabsScreen({super.key});

  @override
  State<NurseRequestLabsScreen> createState() => _NurseRequestLabsScreenState();
}

class _NurseRequestLabsScreenState extends State<NurseRequestLabsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Lab> _labs = [];
  List<Lab> _filteredLabs = [];
  bool _isLoading = true;
  String? _token;
  String? _selectedSpecialization;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final token = await AuthService().getToken();
    if (mounted) {
      setState(() => _token = token);
    }
    await _loadLabs();
  }

  Future<void> _loadLabs() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await LabService.getAllLabs(token: _token);

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
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _performSearch(String query) {
    final trimmedQuery = query.toLowerCase().trim();

    if (trimmedQuery.isEmpty) {
      setState(() => _filteredLabs = _labs);
      return;
    }

    final filtered = _labs.where((lab) {
      return lab.name.toLowerCase().contains(trimmedQuery) ||
          (lab.city?.toLowerCase().contains(trimmedQuery) ?? false) ||
          (lab.specialization?.toLowerCase().contains(trimmedQuery) ?? false);
    }).toList();

    setState(() => _filteredLabs = filtered);
  }

  Future<void> _applySpecializationFilter(String? specialization) async {
    setState(() => _selectedSpecialization =
        _selectedSpecialization == specialization ? null : specialization);
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    try {
      final result = await LabService.getAllLabs(
        token: _token,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        specialization: _selectedSpecialization,
      );

      if (result['success'] == true) {
        final labsData = result['labs'] as List;
        final labs = labsData.map((json) => Lab.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _filteredLabs = labs;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectLab(Lab lab) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabDetailsScreen(lab: lab),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Gradient Hero Header
          SliverToBoxAdapter(
            child: _GradientHero(
              l10n: l10n,
              onBack: () => Navigator.pop(context),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: _ModernSearchBar(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearch: _performSearch,
              l10n: l10n,
            ),
          ),

          // Specializations Filter
          SliverToBoxAdapter(
            child: _SpecializationsFilter(
              selectedSpecialization: _selectedSpecialization,
              onSpecializationSelect: _applySpecializationFilter,
              l10n: l10n,
            ),
          ),

          // Content
          _isLoading
              ? SliverFillRemaining(child: _ModernLoadingState())
              : _filteredLabs.isEmpty
                  ? SliverFillRemaining(child: _ModernEmptyState(
                      l10n: l10n,
                      onReset: () async {
                        _searchController.clear();
                        setState(() => _selectedSpecialization = null);
                        await _loadLabs();
                      },
                    ))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      sliver: _LabsGrid(
                        labs: _filteredLabs,
                        onLabTap: _selectLab,
                      ),
                    ),
        ],
      ),
    );
  }
}

/// Gradient hero header with vibrant colors
class _GradientHero extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onBack;

  const _GradientHero({
    required this.l10n,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.85),
            const Color(0xFF6366F1),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onBack();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                l10n.selectALab,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              // Subtitle
              Text(
                l10n.selectLabForNurseRequest,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern search bar with gradient accent
class _ModernSearchBar extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Function(String) onSearch;
  final AppLocalizations l10n;

  const _ModernSearchBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
    required this.l10n,
  });

  @override
  State<_ModernSearchBar> createState() => _ModernSearchBarState();
}

class _ModernSearchBarState extends State<_ModernSearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(() {
      setState(() => _hasText = widget.searchController.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    widget.searchController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: widget.searchFocusNode,
        builder: (context, child) {
          final hasFocus = widget.searchFocusNode.hasFocus;
          return Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFocus ? AppTheme.primaryColor : AppTheme.gray200,
                width: hasFocus ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: hasFocus ? 0.15 : 0.05),
                  blurRadius: hasFocus ? 16 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: widget.searchController,
              focusNode: widget.searchFocusNode,
              onChanged: widget.onSearch,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.gray900,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.l10n.searchByLabName,
                hintStyle: TextStyle(
                  color: AppTheme.gray400,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.search_rounded,
                    color: hasFocus ? AppTheme.primaryColor : AppTheme.gray400,
                    size: 22,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: _hasText
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppTheme.gray400,
                          size: 20,
                        ),
                        onPressed: () {
                          widget.searchController.clear();
                          widget.onSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Specializations filter with horizontal scroll
class _SpecializationsFilter extends StatelessWidget {
  final String? selectedSpecialization;
  final Function(String?) onSpecializationSelect;
  final AppLocalizations l10n;

  const _SpecializationsFilter({
    required this.selectedSpecialization,
    required this.onSpecializationSelect,
    required this.l10n,
  });

  // Predefined specialization categories
  static const List<String> _specializationCategories = [
    'Pathology',
    'Radiology',
    'Cardiology',
    'Neurology',
    'Biochemistry',
    'Microbiology',
    'Genetics',
    'Hematology',
    'Allergy',
    'Immunology',
    'Endocrinology',
    'General',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _specializationCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final spec = _specializationCategories[index];
            final isSelected = selectedSpecialization == spec;

            return _SpecializationChip(
              label: spec,
              isSelected: isSelected,
              onTap: () => onSpecializationSelect(isSelected ? null : spec),
            );
          },
        ),
      ),
    );
  }
}

/// Individual specialization chip
class _SpecializationChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecializationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SpecializationChip> createState() => _SpecializationChipState();
}

class _SpecializationChipState extends State<_SpecializationChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.isSelected) _controller.forward();
  }

  @override
  void didUpdateWidget(_SpecializationChip oldWidget) {
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.85),
                    ],
                  )
                : null,
            color: widget.isSelected ? null : AppTheme.gray100,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isSelected ? Colors.white : AppTheme.gray700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labs grid with colorful cards
class _LabsGrid extends StatelessWidget {
  final List<Lab> labs;
  final Function(Lab) onLabTap;

  const _LabsGrid({
    required this.labs,
    required this.onLabTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final lab = labs[index];
          return _LabCard(
            lab: lab,
            onTap: () => onLabTap(lab),
          );
        },
        childCount: labs.length,
      ),
    );
  }
}

/// Colorful lab card with full-width logo
class _LabCard extends StatefulWidget {
  final Lab lab;
  final VoidCallback onTap;

  const _LabCard({
    required this.lab,
    required this.onTap,
  });

  @override
  State<_LabCard> createState() => _LabCardState();
}

class _LabCardState extends State<_LabCard>
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
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRating = widget.lab.averageRating != null && widget.lab.averageRating! >= 4.0;
    final isVerified = widget.lab.isVerified == true;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
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

/// Modern loading state
class _ModernLoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingLabs,
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

/// Modern empty state
class _ModernEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onReset;

  const _ModernEmptyState({
    required this.l10n,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.gray100,
                    AppTheme.gray200,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noLabsInArea,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tryAdjustingFilters,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onReset();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(l10n.resetFilters),
            ),
          ],
        ),
      ),
    );
  }
}
