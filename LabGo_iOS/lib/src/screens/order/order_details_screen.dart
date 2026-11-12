import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../widgets/rating_dialog.dart';
import '../../../l10n/app_localizations.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _order;
  bool _isCancelling = false;
  bool _hasShownRatingDialog = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    // Schedule to show rating dialog after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRatingDialogIfNeeded();
    });
  }

  void _showRatingDialogIfNeeded() {
    if (_order.canRate && !_hasShownRatingDialog) {
      _hasShownRatingDialog = true;
      _showRatingDialog();
    }
  }

  void _showRatingDialog() {
    final labName = _order.labData?['name']?.toString() ?? 'Laboratory';
    final hasNurse = _order.nurseId != null;
    final nurseName = _order.nurseData?['name']?.toString();

    RatingDialog.show(
      context: context,
      orderId: _order.id,
      labName: labName,
      hasNurse: hasNurse,
      nurseName: nurseName,
      onRatingSubmitted: () {
        _refreshOrder();
      },
    );
  }

  Future<void> _refreshOrder() async {
    final result = await OrderService.getOrderById(_order.id);

    if (mounted && result['success'] == true) {
      setState(() => _order = result['order'] as Order);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await _showCancelConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    final result = await OrderService.cancelOrder(_order.id, '');

    setState(() => _isCancelling = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderCancelled),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (result['order'] != null) {
        setState(() => _order = result['order'] as Order);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? AppLocalizations.of(context)!.failedToCancelOrder),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<bool?> _showCancelConfirmDialog() async {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(l10n.cancelOrder),
        content: Text(l10n.cancelOrderReason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancelOrder),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.orderDetails),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_order.canCancel)
            TextButton(
              onPressed: _isCancelling ? null : _cancelOrder,
              child: Text(
                l10n.cancelOrder,
                style: TextStyle(
                  color: _isCancelling ? AppTheme.gray400 : AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrder,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. Test Results Card (only show for completed orders with report) - FIRST
            if (_order.status == 'completed' && _order.results?['reportUrl'] != null) ...[
              _buildTestResultsCard(l10n),
              const SizedBox(height: 20),
            ],

            // 1.5 Rating Card (for completed orders)
            if (_order.status == 'completed') ...[
              _buildRatingCard(l10n),
              const SizedBox(height: 20),
            ],

            // 2. Status Card
            _buildStatusCard(l10n),

            const SizedBox(height: 20),

            // 2.5 Beneficiary Info Card (only show if order is for another person)
            if (_order.isForOtherPerson) ...[
              _buildBeneficiaryInfoCard(l10n),
              const SizedBox(height: 20),
            ],

            // 3. Assigned Nurse Card (only show when nurse is assigned)
            if (_order.nurseData != null) ...[
              _buildNurseInfoCard(l10n),
              const SizedBox(height: 20),
            ],

            // 4. Scheduled Visit Card (if date/time is set)
            if (_order.scheduledDate != null || _order.timeSlot != null)
              _buildScheduledVisitCard(l10n),

            if (_order.scheduledDate != null || _order.timeSlot != null)
              const SizedBox(height: 20),

            // 5. Tests Card
            _buildTestsCard(l10n),

            const SizedBox(height: 20),

            // 6. Pricing Card - only show for orders with tests
            if (_order.tests.isNotEmpty) ...[
              _buildPricingCard(l10n),
              const SizedBox(height: 20),
            ],

            // 7. Location Card
            _buildLocationCard(l10n),

            const SizedBox(height: 20),

            // 8. QR Code Card
            _buildQRCodeCard(l10n),

            const SizedBox(height: 20),

            // 9. Map Card
            _buildLocationMap(l10n),

            const SizedBox(height: 40),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(AppLocalizations l10n) {
    final statusColor = _getStatusColor(_order.status);
    final statusIcon = _getStatusIcon(_order.status);
    final statusName = _getStatusDisplayName(_order.status, l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.12),
            statusColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 28,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.orderStatus,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(AppLocalizations l10n) {
    final hasBeenRated = _order.hasBeenRated;
    final labRating = _order.rating?['labRating'];
    final nurseRating = _order.rating?['nurseRating'];

    if (hasBeenRated) {
      // Show thank you card with submitted ratings
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.thankYouForRating,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.yourFeedbackHelps,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (labRating != null) ...[
                  _buildRatingDisplay(l10n.labRating, labRating),
                ],
                if (labRating != null && nurseRating != null)
                  const SizedBox(width: 24),
                if (nurseRating != null) ...[
                  _buildRatingDisplay(l10n.nurseRating, nurseRating),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // Show "Rate your experience" card
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rateYourExperience,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.helpUsImprove,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showRatingDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.rateNow,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDisplay(String label, int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: index < rating
                    ? const Color(0xFFFFD700)
                    : Colors.white.withValues(alpha: 0.5),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryInfoCard(AppLocalizations l10n) {
    final name = _order.beneficiary?['name']?.toString() ?? '';
    final phone = _order.beneficiary?['phone']?.toString() ?? '';
    final gender = _order.beneficiary?['gender']?.toString();
    final relationship = _order.beneficiary?['relationship']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            const Color(0xFF8B5CF6).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.orderForOtherPerson,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Beneficiary name
          if (name.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Beneficiary phone
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          // Gender and relationship tags
          if (gender != null || relationship != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (gender != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gender == 'male' ? l10n.male : l10n.female,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (relationship != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getRelationshipLabel(relationship, l10n),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getRelationshipLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'spouse':
        return l10n.spouse;
      case 'child':
        return l10n.child;
      case 'parent':
        return l10n.parent;
      case 'sibling':
        return l10n.sibling;
      case 'other':
        return l10n.other;
      default:
        return value;
    }
  }

  Widget _buildQRCodeCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            l10n.qrCode,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _order.qrCode,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gray200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.sampleCollectionLocation,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _order.location.address,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.gray900,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_order.location.landmark != null) ...[
            const SizedBox(height: 4),
            Text(
              _order.location.landmark!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray600,
              ),
            ),
          ],
          if (_order.location.buildingName != null ||
              _order.location.apartmentNumber != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_order.location.buildingName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _order.location.buildingName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_order.location.apartmentNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _order.location.apartmentNumber!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduledVisitCard(AppLocalizations l10n) {
    // Format the date if available
    String formattedDate = '';
    if (_order.scheduledDate != null) {
      final date = _order.scheduledDate!;
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      formattedDate = '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    // Get time slot display if available
    String timeSlotDisplay = '';
    if (_order.timeSlot != null) {
      final slot = _order.timeSlot!;
      timeSlotDisplay = slot['display']?.toString() ??
          '${slot['start']} - ${slot['end']}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.scheduledVisit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (formattedDate.isNotEmpty || timeSlotDisplay.isNotEmpty) ...[
            Row(
              children: [
                if (formattedDate.isNotEmpty) ...[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.gray900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (formattedDate.isNotEmpty && timeSlotDisplay.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gray400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (timeSlotDisplay.isNotEmpty) ...[
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeSlotDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.gray900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNurseInfoCard(AppLocalizations l10n) {
    final nurseName = _order.nurseData?['name']?.toString() ?? '';
    final nursePhone = _order.nurseData?['phone']?.toString() ?? '';
    final nurseRating = _order.nurseData?['averageRating'];
    final nurseTotalRatings = _order.nurseData?['totalRatings'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.assignedNurse,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nurseName.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    nurseName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                ),
                // Nurse rating display
                if (nurseRating != null && nurseRating > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          nurseRating is int
                              ? nurseRating.toString()
                              : nurseRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB8860B),
                          ),
                        ),
                        if (nurseTotalRatings != null && nurseTotalRatings > 0) ...[
                          const SizedBox(width: 2),
                          Text(
                            '($nurseTotalRatings)',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFFB8860B).withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (nursePhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // Launch phone dialer
                // TODO: Implement url_launcher for phone calls
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nursePhone,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Nurse description (admin-written)
          if (_order.nurseData?['nurseDescription'] != null &&
              _order.nurseData!['nurseDescription'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.gray200,
                  width: 1,
                ),
              ),
              child: Text(
                _order.nurseData!['nurseDescription'].toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.gray700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationMap(AppLocalizations l10n) {
    final latLng = LatLng(_order.location.latitude, _order.location.longitude);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: latLng,
              initialZoom: 15,
              minZoom: 10,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.labgo.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: latLng,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Map label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sampleCollectionLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsCard(AppLocalizations l10n) {
    // Show info alert for prescription-only orders (empty tests)
    if (_order.tests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.1),
              const Color(0xFFF59E0B).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.adminWillReviewPrescription,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gray200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.scheduledTests,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            _order.tests.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == _order.tests.length - 1 ? 0 : 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _order.tests[index].testName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.gray900,
                      ),
                    ),
                  ),
                  Text(
                    _formatPrice(_order.tests[index].price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultsCard(AppLocalizations l10n) {
    final reportUrl = _order.results?['reportUrl']?.toString();
    if (reportUrl == null) return const SizedBox.shrink();

    // Convert relative URL to absolute URL
    final absoluteUrl = _getAbsoluteUrl(reportUrl);

    final isPdf = absoluteUrl.toLowerCase().endsWith('.pdf');
    final isImage = !isPdf && (absoluteUrl.toLowerCase().endsWith('.jpg') ||
        absoluteUrl.toLowerCase().endsWith('.jpeg') ||
        absoluteUrl.toLowerCase().endsWith('.png') ||
        absoluteUrl.toLowerCase().endsWith('.gif') ||
        absoluteUrl.toLowerCase().endsWith('.webp'));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.success.withValues(alpha: 0.1),
            AppTheme.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppTheme.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.testResults,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.resultReady,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _launchReportUrl(absoluteUrl),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: AppTheme.success,
                ),
                tooltip: l10n.viewResult,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Preview Section
          GestureDetector(
            onTap: () => _showResultPreview(context, absoluteUrl, isPdf),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isImage
                    ? _buildImagePreview(absoluteUrl)
                    : _buildPdfPreview(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convert relative URL to absolute URL
  String _getAbsoluteUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiService.baseUrl}$url';
    }
    return '${ApiService.baseUrl}/$url';
  }

  Widget _buildImagePreview(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.error),
              SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.failedToLoadImage, style: TextStyle(color: AppTheme.gray600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.gray50,
            AppTheme.gray100,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 48,
              color: AppTheme.error,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PDF Document',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to view',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }

  void _showResultPreview(BuildContext context, String url, bool isPdf) {
    if (isPdf) {
      // Open PDF directly in browser
      _launchReportUrl(url);
    } else {
      // Show full-screen image preview with zoom
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _ResultPreviewScreen(url: url, isPdf: isPdf),
        ),
      );
    }
  }

  Future<void> _launchReportUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPricingCard(AppLocalizations l10n) {
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
        children: [
          _buildPricingRow(
            l10n.subtotal,
            _formatPrice(_order.tests.fold(0, (sum, t) => sum + t.price)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.gray300),
          ),
          _buildPricingRow(
            l10n.totalAmount,
            _formatPrice(_order.tests.fold(0, (sum, t) => sum + t.price)),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.gray900 : AppTheme.gray600,
          ),
        ),
        Text(
          '$value IQD',
          style: TextStyle(
            fontSize: isTotal ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: isTotal ? AppTheme.primaryColor : AppTheme.gray900,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.info;
      case 'nurse_assigned':
      case 'sample_collected':
      case 'at_lab':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.gray500;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'nurse_assigned':
        return Icons.person_search_rounded;
      case 'sample_collected':
        return Icons.check_box_rounded;
      case 'at_lab':
        return Icons.biotech_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusDisplayName(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'confirmed':
        return l10n.confirmed;
      case 'nurse_assigned':
        return l10n.nurseAssigned;
      case 'sample_collected':
        return l10n.sampleCollected;
      case 'at_lab':
        return l10n.atLab;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  String _formatPrice(int price) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }
}

class _ResultPreviewScreen extends StatelessWidget {
  final String url;
  final bool isPdf;

  const _ResultPreviewScreen({required this.url, required this.isPdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: Center(
        child: isPdf ? _buildPdfViewer(context) : _buildImageViewer(),
      ),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorWidget: (context, url, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 60, color: Colors.white),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.failedToLoadImage,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            size: 80,
            color: AppTheme.error,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'PDF Document',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download_rounded),
          label: Text(AppLocalizations.of(context)!.downloadViewPdf),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

extension on Order {
  bool get canCancel {
    return (status == 'pending' || status == 'confirmed') && !isCancelled;
  }

  bool get canRate {
    return status == 'completed' && rating?['ratedAt'] == null;
  }

  bool get hasBeenRated {
    return rating?['ratedAt'] != null;
  }
}
