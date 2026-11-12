import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../services/cart_service.dart';
import '../order/order_confirmation_screen.dart';
import '../../../l10n/app_localizations.dart';

class CartScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final File? localPrescriptionImage;

  const CartScreen({
    super.key,
    required this.labId,
    required this.labName,
    this.localPrescriptionImage,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  Cart? _cart;
  bool _isLoading = true;
  File? _prescriptionImage;
  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final result = await CartService.getCart();
    if (mounted) {
      setState(() {
        _cart = result['success'] == true ? result['cart'] : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeTest(String testId) async {
    final result = await CartService.removeFromCart(testId: testId);
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _cart = result['cart'];
        });
      }
      _showSnackBar(
        result['message'] ?? 'Test removed',
        result['success'] == true,
      );
    }
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(milliseconds: 2000),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildCartContent(context, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, AppLocalizations l10n) {
    final isEmpty = _cart == null || _cart!.isEmpty;
    final hasPrescription = _cart?.hasPrescription ?? false;
    final hasLocalPrescription = widget.localPrescriptionImage != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Handle
          _buildHandle(),

          // Header
          _buildHeader(context, l10n),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : isEmpty
                    ? _buildEmptyState(context, l10n)
                    : _buildCartItems(context, l10n),
          ),

          // Bottom Section
          if (!isEmpty) _buildBottomSection(context, l10n, hasPrescription, hasLocalPrescription),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 48,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.gray300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        children: [
          // Cart Icon with Badge
          Stack(
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
                  Icons.biotech_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (_cart != null && _cart!.testCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '${_cart!.testCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cart,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gray900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.labName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          // Close Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.science_outlined,
              size: 40,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.cartEmpty,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.cartEmptySubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.browseTests,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        // Items List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _cart!.tests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _cart!.tests[index];
              return _buildCartItem(item, l10n);
            },
          ),
        ),

        const SizedBox(height: 16),

        // Summary Card
        _buildSummaryCard(l10n),
      ],
    );
  }

  Widget _buildCartItem(CartItem item, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Test Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.science_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          // Test Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.testName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (item.category != null && item.category!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.category!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show original price with strikethrough if discounted
              if (item.hasDiscount) ...[
                Text(
                  '${item.formattedOriginalPrice} IQD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray400,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppTheme.gray400,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              // Current price (discounted or original)
              Text(
                '${item.formattedPrice} IQD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: item.hasDiscount ? Colors.red.shade700 : AppTheme.primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
              // Show discount badge
              if (item.hasDiscount) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${item.discountPercentage}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
              ],
              GestureDetector(
                onTap: () => _removeTest(item.testId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.remove,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppLocalizations l10n) {
    final hasPrescription = _cart?.hasPrescription ?? false;
    final hasLocalPrescription = _prescriptionImage != null || widget.localPrescriptionImage != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.subtotal,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray600,
                ),
              ),
              Text(
                '${_cart!.totalPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} IQD',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Optional Prescription Upload
          _buildPrescriptionUploadSection(l10n, hasPrescription, hasLocalPrescription),
        ],
      ),
    );
  }

  Widget _buildPrescriptionUploadSection(
    AppLocalizations l10n,
    bool hasPrescription,
    bool hasLocalPrescription,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasPrescription || hasLocalPrescription
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.gray200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasPrescription || hasLocalPrescription
                    ? Icons.check_rounded
                    : Icons.add_photo_alternate_rounded,
                size: 18,
                color: hasPrescription || hasLocalPrescription
                    ? AppTheme.success
                    : AppTheme.gray600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.uploadPrescription,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                  Text(
                    hasPrescription || hasLocalPrescription
                        ? l10n.prescriptionUploaded
                        : l10n.prescriptionOptional,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: hasPrescription || hasLocalPrescription
                          ? AppTheme.success
                          : AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasPrescription || hasLocalPrescription)
              GestureDetector(
                onTap: _removePrescription,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.remove,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _pickPrescriptionImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                        AppTheme.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    l10n.selectPrescription,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
      // Handle error silently
    }
  }

  Future<void> _removePrescription() async {
    final result = await CartService.removePrescription();
    if (mounted) {
      setState(() {
        _prescriptionImage = null;
        if (result['success'] == true) {
          _cart = result['cart'];
        }
      });
      _showSnackBar(
        result['message'] ?? 'Prescription removed',
        result['success'] == true,
      );
    }
  }

  Widget _buildBottomSection(
    BuildContext context,
    AppLocalizations l10n,
    bool hasPrescription,
    bool hasLocalPrescription,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checkout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (_cart == null || _cart!.isEmpty) return;

                    // Upload prescription image if exists
                    String? prescriptionImageUrl;
                    if (_prescriptionImage != null || widget.localPrescriptionImage != null) {
                      final imageFile = _prescriptionImage ?? widget.localPrescriptionImage;
                      if (imageFile != null) {
                        // TODO: Implement image upload and get URL
                        // For now, we'll pass the file directly
                      }
                    }

                    // Close cart and navigate to order confirmation
                    if (mounted) {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderConfirmationScreen(
                            labId: widget.labId,
                            labName: widget.labName,
                            cart: _cart!,
                            localPrescriptionImage: _prescriptionImage ?? widget.localPrescriptionImage,
                          ),
                        ),
                      );
                      // Reload cart after returning
                      _loadCart();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryColor, Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.proceedToCheckout,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
