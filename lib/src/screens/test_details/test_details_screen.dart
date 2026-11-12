import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/asymmetric_sliver_header.dart';
import 'widgets/bento_grid_layout.dart';
import 'widgets/bento_card.dart';
import 'widgets/sticky_section_header.dart';
import 'widgets/expandable_content_card.dart';
import 'widgets/floating_cta_button.dart';

/// Test Details Screen with "Medical Magazine" aesthetic.
/// Features asymmetric header, bento-box layout, sticky sections, and confetti animation.
class TestDetailsScreen extends StatefulWidget {
  final LabTest test;
  final String labName;
  final String labId;
  final LabOffer? offer; // Optional offer for discount display

  const TestDetailsScreen({
    super.key,
    required this.test,
    required this.labName,
    required this.labId,
    this.offer,
  });

  @override
  State<TestDetailsScreen> createState() => _TestDetailsScreenState();
}

class _TestDetailsScreenState extends State<TestDetailsScreen>
    with TickerProviderStateMixin {
  bool _isAdded = false;
  bool _isLoading = false;
  late AnimationController _entranceController;
  late Animation<double> _fadeInAnimation;

  // Expansion states
  bool _descriptionExpanded = false;
  bool _instructionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkIfTestInCart();
  }

  void _initializeAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOut,
      ),
    );

    _entranceController.forward();
  }

  Future<void> _checkIfTestInCart() async {
    if (AuthService.isGuestMode) return; // Skip for guests
    final isInCart = await CartService.isTestInCart(widget.test.id);
    if (mounted) {
      setState(() {
        _isAdded = isInCart;
      });
    }
  }

  Future<void> _toggleCart() async {
    if (_isLoading) return;

    // Guest mode: show login dialog
    if (AuthService.isGuestMode) {
      final l10n = AppLocalizations.of(context)!;
      showAuthRequiredDialog(
        context,
        message: l10n.loginToAddToCart,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      if (_isAdded) {
        // Remove from cart
        final result = await CartService.removeFromCart(
          testId: widget.test.id,
        );

        if (mounted) {
          setState(() {
            _isAdded = false;
            _isLoading = false;
          });

          _showSnackBar(
            l10n.testRemoved,
            result['success'] == true ? AppTheme.gray700 : AppTheme.error,
          );
        }
      } else {
        // Calculate discounted price if offer exists
        int? discountedPrice;
        if (widget.offer != null) {
          discountedPrice = widget.offer!.calculateDiscountedPriceForTest(
            widget.test.price,
            widget.test.id,
            widget.test.code,
          );
        }

        // Add to cart
        final result = await CartService.addToCart(
          labId: widget.labId,
          testId: widget.test.id,
          discountedPrice: discountedPrice,
        );

        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _isAdded = true;
              _isLoading = false;
            });

            // Navigate back immediately (no delay)
            Navigator.of(context).pop();

            // Show snackbar AFTER navigation (non-blocking)
            // Use a post-frame callback to ensure snackbar shows on the previous screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSnackBar(
                l10n.testAddedSuccessfully,
                AppTheme.success,
              );
            });
          } else {
            setState(() {
              _isLoading = false;
            });

            _showSnackBar(
              l10n.orderCreationFailed,
              AppTheme.error,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showSnackBar(
          '${l10n.errorLoadingData}. ${l10n.tryAgain}',
          AppTheme.error,
        );
      }
    }

    HapticFeedback.mediumImpact();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == AppTheme.success
                  ? Icons.check_circle_rounded
                  : backgroundColor == AppTheme.error
                      ? Icons.error_rounded
                      : Icons.remove_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(milliseconds: 2000),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  String _getCategoryKey(String name) {
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

  /// Build the price card with discount support
  Widget _buildPriceCard(AppLocalizations l10n) {
    final hasOffer = widget.offer != null;
    final discountValue = hasOffer 
        ? widget.offer!.getDiscountValueForTest(widget.test.id, widget.test.code)
        : 0.0;
    final hasDiscount = hasOffer && discountValue > 0;
    
    if (hasDiscount) {
      final discountedPrice = widget.offer!.calculateDiscountedPriceForTest(
        widget.test.price,
        widget.test.id,
        widget.test.code,
      );
      final formatter = NumberFormat('#,###', 'en_US');
      
      return Container(
        height: 180, // Fixed height to match BentoCard.large
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '-${discountValue.toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original price with strikethrough
                Text(
                  widget.test.formattedPrice,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                // Discounted price
                Text(
                  '${formatter.format(discountedPrice)} IQD',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ],
        ),
      );
    }
    
    // Default price card without discount
    return BentoCard.large(
      title: widget.test.formattedPrice,
      subtitle: l10n.tests,
      icon: Icons.monetization_on_rounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.primaryColor,
          AppTheme.primaryDark,
        ],
      ),
      textColor: AppTheme.white,
    );
  }

  String _getCategoryName(String categoryName, AppLocalizations l10n) {
    final key = _getCategoryKey(categoryName);

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

    return getterMap[key] ?? categoryName;
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoryName = widget.test.category != null && widget.test.category!.isNotEmpty
        ? _getCategoryName(widget.test.category!, l10n)
        : 'N/A';

    // Set global context for back button navigation
    Globals.context = context;

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: FadeTransition(
        opacity: _fadeInAnimation,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Asymmetric Header
                AsymmetricSliverHeader(
                  title: widget.test.arabicName,
                  subtitle: widget.test.hasEnglishSubtitle
                      ? '${widget.test.englishName}  ·  ${widget.labName}'
                      : widget.labName,
                  badge: widget.test.category,
                  badgeIcon: Icons.category_rounded,
                  expandedHeight: 320,
                  collapsedHeight: 80,
                  onBackPressed: () => Navigator.of(context).pop(),
                ),

                // Bento Grid Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32, bottom: 24),
                    child: BentoGridLayout(
                      spacing: 12,
                      items: [
                        // Price Card (Large) - with discount support
                        BentoGridItem.large(
                          child: _buildPriceCard(l10n),
                        ),

                        // Category Card (Medium)
                        BentoGridItem.medium(
                          child: BentoCard.medium(
                            title: l10n.category,
                            subtitle: categoryName.length > 20
                                ? '${categoryName.substring(0, 20)}...'
                                : categoryName,
                            icon: Icons.category_rounded,
                            backgroundColor: AppTheme.white,
                          ),
                        ),

                        // Quick Info Cards (Small)
                        BentoGridItem.small(
                          child: BentoCard.small(
                            title: 'Available',
                            subtitle: '24/7',
                            icon: Icons.access_time_rounded,
                            backgroundColor: AppTheme.primaryColor
                                .withValues(alpha: 0.08),
                            textColor: AppTheme.primaryColor,
                          ),
                        ),

                        BentoGridItem.small(
                          child: BentoCard.small(
                            title: 'Verified',
                            subtitle: 'Lab',
                            icon: Icons.verified_rounded,
                            backgroundColor: AppTheme.success
                                .withValues(alpha: 0.08),
                            textColor: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Description Section
                if (widget.test.description != null &&
                    widget.test.description!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          StickySectionHeader(
                            title: l10n.description,
                            icon: Icons.article_rounded,
                            actionLabel: _descriptionExpanded ? 'Collapse' : 'Expand',
                            isExpanded: _descriptionExpanded,
                            onTap: () {
                              setState(() {
                                _descriptionExpanded = !_descriptionExpanded;
                              });
                              HapticFeedback.lightImpact();
                            },
                          ),
                          const SizedBox(height: 16),
                          ExpandableContentCard(
                            content: widget.test.description ?? '',
                            maxLines: _descriptionExpanded ? 100 : 3,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                // Instructions Section
                if (widget.test.instructions != null &&
                    widget.test.instructions!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          StickySectionHeader(
                            title: l10n.specialInstructions,
                            icon: Icons.warning_amber_rounded,
                            actionLabel: _instructionsExpanded ? 'Collapse' : 'Expand',
                            isExpanded: _instructionsExpanded,
                            onTap: () {
                              setState(() {
                                _instructionsExpanded = !_instructionsExpanded;
                              });
                              HapticFeedback.lightImpact();
                            },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFFF7ED),
                                  const Color(0xFFFFF7ED)
                                      .withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.warning.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: AppTheme.warning.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.info_rounded,
                                    size: 20,
                                    color: AppTheme.warning,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: _instructionsExpanded
                                            ? double.infinity
                                            : 80,
                                      ),
                                      child: Text(
                                        widget.test.instructions ?? '',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.gray800,
                                          height: 1.6,
                                          letterSpacing: -0.2,
                                        ),
                                        overflow: _instructionsExpanded
                                            ? TextOverflow.visible
                                            : TextOverflow.fade,
                                        maxLines: _instructionsExpanded ? null : 5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                // Bottom padding for floating CTA
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),

            // Floating CTA Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingCTAButton(
                isAdded: _isAdded,
                isLoading: _isLoading,
                onTap: _toggleCart,
                addText: l10n.addTest,
                addedText: l10n.added,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
