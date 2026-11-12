import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/cart_service.dart';
import '../test_details/test_details_screen.dart';
import '../order/order_confirmation_screen.dart';
import 'cart_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';

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
  File? _prescriptionImage;
  final ImagePicker _imagePicker = ImagePicker();
  int _cartCount = 0;
  bool _hasLoadedOnce = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load cart count immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCartCount();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartCount();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load cart count when dependencies change (navigation back)
    if (_hasLoadedOnce) {
      _loadCartCount();
    }
    _hasLoadedOnce = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _specializationKeys {
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
        test.name.toLowerCase().contains(query) ||
        test.code.toLowerCase().contains(query)
      ).toList();
    }

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

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 90),

          // Row 1: Logo, Name, Location, Status
          _buildLabInfoSection(context, l10n),

          const SizedBox(height: 20),

          // Prescription Upload Button
          _buildPrescriptionUploadSection(context, l10n),

          const SizedBox(height: 24),

          // Search Input
          _buildSearchInput(l10n),

          const SizedBox(height: 16),

          // Row 2: Specializations Horizontal Slider
          _buildSpecializationsSlider(context, l10n),

          const SizedBox(height: 24),

          // Row 3: Tests Cards
          _buildTestsSection(context, l10n, locale),

          const SizedBox(height: 100),
        ],
      ),
      // Floating Cart Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCartButton(context, l10n),
    );
  }

  Widget _buildFloatingCartButton(BuildContext context, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () async {
        if (AuthService.isGuestMode) {
          showAuthRequiredDialog(
            context,
            message: l10n.loginToAddToCart,
          );
          return;
        }
        await showModalBottomSheet<Cart>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CartScreen(
            labId: widget.lab.id,
            labName: widget.lab.name,
            localPrescriptionImage: _prescriptionImage,
          ),
        );

        // Update cart count after closing cart screen
        if (mounted) {
          _loadCartCount();
        }
      },
      child: Container(
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
            const Icon(
              Icons.science_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 14),
            Text(
              l10n.showSelectedTests,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (_cartCount > 0) ...[
              const SizedBox(width: 16),
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
          ],
        ),
      ),
    );
  }

  Future<void> _loadCartCount() async {
    if (AuthService.isGuestMode) {
      setState(() => _cartCount = 0);
      return;
    }
    final result = await CartService.getCart();
    if (mounted) {
      setState(() {
        _cartCount = result['success'] == true && result['cart'] != null
            ? result['cart'].testCount
            : 0;
      });
    }
  }

  Widget _buildLabInfoSection(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lab Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gray900.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.lab.hasValidLogo
                ? CachedNetworkImage(
                    imageUrl: widget.lab.logo!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.biotech_rounded,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : const Icon(
                    Icons.biotech_rounded,
                    size: 32,
                    color: AppTheme.primaryColor,
                  ),
          ),
        ),

        const SizedBox(width: 16),

        // Lab Info: Name, Location, Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lab Name
              Text(
                widget.lab.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),

              // Location
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppTheme.gray500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.lab.fullAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Rating Display
              _buildRatingRow(),
              
              const SizedBox(height: 8),

              // Status Badge
              _buildStatusBadge(l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    final isOpen = widget.lab.status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? l10n.openNow : l10n.closed,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow() {
    final hasRating = widget.lab.averageRating != null && widget.lab.averageRating! > 0;
    final rating = widget.lab.averageRating ?? 0.0;
    final reviewCount = widget.lab.totalReviews ?? 0;
    
    if (!hasRating) {
      return const SizedBox.shrink();
    }
    
    return Row(
      children: [
        // Star icons
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          Color color;
          
          if (rating >= starValue) {
            icon = Icons.star_rounded;
            color = AppTheme.secondaryColor;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half_rounded;
            color = AppTheme.secondaryColor;
          } else {
            icon = Icons.star_outline_rounded;
            color = AppTheme.gray400;
          }
          
          return Icon(
            icon,
            size: 16,
            color: color,
          );
        }),
        const SizedBox(width: 6),
        // Rating value
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray800,
          ),
        ),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrescriptionUploadSection(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.uploadPrescription,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.uploadPrescriptionSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Upload Button / Preview
          GestureDetector(
            onTap: _pickPrescriptionImage,
            child: Container(
              height: _prescriptionImage != null ? 200 : 80,
              decoration: BoxDecoration(
                color: _prescriptionImage != null
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                  style: _prescriptionImage != null
                      ? BorderStyle.none
                      : BorderStyle.solid,
                ),
              ),
              child: _prescriptionImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.file(
                              _prescriptionImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _prescriptionImage = null;
                                });
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 24,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.selectPrescription,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // Order by Prescription button - shown when prescription is uploaded
          if (_prescriptionImage != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _navigateToPrescriptionOrder,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFF59E0B),
                      const Color(0xFFD97706),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.orderByPrescription,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickPrescriptionImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _prescriptionImage = File(image.path);
        });
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  Future<void> _navigateToPrescriptionOrder() async {
    if (_prescriptionImage == null) return;

    // Navigate directly to order confirmation with prescription-only mode
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(
            labId: widget.lab.id,
            labName: widget.lab.name,
            prescriptionOnly: true,
            localPrescriptionImage: _prescriptionImage,
          ),
        ),
      );
    }
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: l10n.searchTests,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppTheme.gray500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.gray500,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.gray500,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTestsSection(BuildContext context, AppLocalizations l10n, String locale) {
    final tests = _filteredTests;

    // Get applicable offers for showing discounted prices
    final offers = widget.lab.validOffers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                '${tests.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (tests.isEmpty)
          Center(
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
          )
        else
        ...tests.map((test) {
          // Find applicable offer for this test
          LabOffer? applicableOffer;
          for (final offer in offers) {
            if (offer.appliesToTest(test.id, test.code)) {
              applicableOffer = offer;
              break;
            }
          }

          return _TestCard(
              test: test,
              offer: applicableOffer,
              locale: locale,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestDetailsScreen(
                      test: test,
                      labName: widget.lab.name,
                      labId: widget.lab.id,
                      offer: applicableOffer,
                    ),
                  ),
                );
              },
            );
        }),
      ],
    );
  }
}

class _TestCard extends StatelessWidget {
  final LabTest test;
  final LabOffer? offer;
  final String locale;
  final VoidCallback onTap;

  const _TestCard({
    required this.test,
    this.offer,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasOffer = offer != null;
    // Use per-test discount calculation
    final discountedPrice = hasOffer 
        ? offer!.calculateDiscountedPriceForTest(test.price, test.id, test.code) 
        : test.price;
    // Get the discount value specifically for this test
    final testDiscountValue = hasOffer 
        ? offer!.getDiscountValueForTest(test.id, test.code)
        : 0.0;
    final testDiscountType = hasOffer 
        ? offer!.getDiscountTypeForTest(test.id, test.code)
        : 'percentage';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasOffer ? AppTheme.primaryColor.withValues(alpha: 0.03) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasOffer ? AppTheme.primaryColor.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Test Icon with offer badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.science_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    if (hasOffer && testDiscountValue > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${testDiscountValue.toInt()}${testDiscountType == 'percentage' ? '%' : ''}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Test Name with offer label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (hasOffer && testDiscountValue > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer!.getLocalizedLabel(locale),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Price section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasOffer && testDiscountValue > 0) ...[
                      // Original price with strikethrough
                      Text(
                        test.formattedPrice,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gray400,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppTheme.gray400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Discounted price
                      Text(
                        '${NumberFormat('#,###', 'en_US').format(discountedPrice)} IQD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ] else ...[
                      Text(
                        test.formattedPrice,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(width: 12),

                // Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.gray400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
