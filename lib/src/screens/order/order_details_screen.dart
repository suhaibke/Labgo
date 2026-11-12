import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/order_service.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/tracking_map.dart';
import '../../widgets/order_timeline.dart';
import '../../../l10n/app_localizations.dart';
import '../test_results/test_results_screen.dart';
import 'invoice_screen.dart';
import 'sample_label_screen.dart';

/// Parses {latitude, longitude}, {lat, lng}, nested coordinates, or
/// GeoJSON [lng, lat] into a LatLng.
LatLng? _parseLatLng(dynamic coords) {
  if (coords == null) return null;
  if (coords is List && coords.length >= 2) {
    final lng = coords[0] is num ? (coords[0] as num).toDouble() : double.tryParse('${coords[0]}');
    final lat = coords[1] is num ? (coords[1] as num).toDouble() : double.tryParse('${coords[1]}');
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }
  if (coords is! Map) return null;
  if (coords['coordinates'] != null) {
    final nested = _parseLatLng(coords['coordinates']);
    if (nested != null) return nested;
  }
  final latRaw = coords['latitude'] ?? coords['lat'];
  final lngRaw = coords['longitude'] ?? coords['lng'] ?? coords['lon'];
  if (latRaw == null || lngRaw == null) return null;
  final latNum = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw.toString());
  final lngNum = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw.toString());
  if (latNum == null || lngNum == null) return null;
  return LatLng(latNum, lngNum);
}

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  final bool showInvoiceOnOpen;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.showInvoiceOnOpen = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _order;
  bool _isCancelling = false;
  bool _hasShownRatingDialog = false;
  bool _isRespondingToQuote = false;
  Timer? _liveTrackingTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRatingDialogIfNeeded();
      if (widget.showInvoiceOnOpen) {
        // _openInvoice() already awaits its own fresh fetch before
        // pushing, so it doesn't need a separate _refreshOrder() here too.
        _openInvoice();
      } else {
        _refreshOrder();
      }
    });
    _syncLiveTracking();
  }

  @override
  void dispose() {
    _liveTrackingTimer?.cancel();
    super.dispose();
  }

  /// While the nurse is on the way, poll the order every 15s so the
  /// nurse's live location marker on the map keeps moving.
  void _syncLiveTracking() {
    final shouldTrack = _order.status == 'nurse_assigned';
    if (shouldTrack && _liveTrackingTimer == null) {
      _liveTrackingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _refreshOrder();
      });
    } else if (!shouldTrack && _liveTrackingTimer != null) {
      _liveTrackingTimer!.cancel();
      _liveTrackingTimer = null;
    }
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
      _syncLiveTracking();
    }
  }

  Future<void> _respondToQuote(bool approved) async {
    final l10n = AppLocalizations.of(context)!;

    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.rejectQuote),
          content: Text(l10n.rejectQuoteConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: Size.zero,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.rejectQuote),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isRespondingToQuote = true);

    final result = await OrderService.respondToQuote(_order.id, approved);

    if (!mounted) return;
    setState(() => _isRespondingToQuote = false);

    if (result['success'] == true) {
      setState(() => _order = result['order'] as Order);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? l10n.quoteApproved : l10n.quoteRejected),
          backgroundColor: approved ? AppTheme.success : AppTheme.gray700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? l10n.somethingWentWrong),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatImageUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiService.baseUrl}$raw';
    return '${ApiService.baseUrl}/$raw';
  }

  void _showFullImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _formatImageUrl(imageUrl),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.error),
                        SizedBox(height: 8),
                        Text('تعذر تحميل الصورة', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionQuoteCard(AppLocalizations l10n) {
    final quote = _order.prescriptionQuote!;
    final price = quote['price'];
    final imageUrl = quote['imageUrl'] as String?;
    final quoteTests = (quote['tests'] as List?)
            ?.whereType<Map>()
            .where((t) => (t['name']?.toString().isNotEmpty ?? false))
            .toList() ??
        const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.priceQuoteReceived,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.gray900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Prescription Image in a compact modern container with preview button
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            Material(
              color: const Color(0xFFF6F4FD),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _showFullImageViewer(context, imageUrl),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: _formatImageUrl(imageUrl),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 52,
                            height: 52,
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: AppTheme.gray200,
                            child: const Icon(Icons.image_not_supported_rounded, size: 22, color: AppTheme.gray500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.prescriptionImageTitle,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.gray900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.viewPrescriptionImage,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              l10n.viewPrescriptionImage,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Details (Tests or Medicine)
          if (quoteTests.isNotEmpty) ...[
            for (final test in quoteTests)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        test['name'].toString(),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.gray900),
                      ),
                    ),
                    Text(
                      '${test['price'] is num ? (test['price'] as num).toStringAsFixed(0) : test['price']} ${l10n.iqd}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.gray700),
                    ),
                  ],
                ),
              ),
            const Divider(height: 14),
          ] else ...[
            if ((quote['medicineName'] as String?)?.isNotEmpty == true)
              Text(
                quote['medicineName'],
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.gray900),
              ),
            if ((quote['medicineType'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                quote['medicineType'],
                style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
              ),
            ],
            const SizedBox(height: 8),
          ],

          // Price row with clean badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${price is num ? price.toStringAsFixed(0) : price} ${l10n.iqd}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
              ),
              if ((quote['notes'] as String?)?.isNotEmpty == true)
                Flexible(
                  child: Text(
                    quote['notes'],
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isRespondingToQuote ? null : () => _respondToQuote(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l10n.rejectQuote, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isRespondingToQuote ? null : () => _respondToQuote(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isRespondingToQuote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.approveQuote, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await _showCancelWithReasonDialog(l10n);
    if (reason == null) return; // user dismissed

    setState(() => _isCancelling = true);

    final result = await OrderService.cancelOrder(_order.id, reason);

    setState(() => _isCancelling = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.orderCancelled),
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
          content: Text(result['message']?.toString() ?? l10n.failedToCancelOrder),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Shows a bottom-sheet style dialog asking the user to enter a cancellation
  /// reason. Returns the trimmed reason string, or null if the user cancelled.
  Future<String?> _showCancelWithReasonDialog(AppLocalizations l10n) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_outlined,
                        color: AppTheme.error, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.cancelOrder,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      l10n.cancelOrderReasonHint,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: l10n.cancelReasonPlaceholder,
                        filled: true,
                        fillColor: const Color(0xFFF6F4FD),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 5) {
                          return l10n.cancelReasonRequired;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(color: AppTheme.gray300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.cancel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, reasonController.text.trim());
                    }
                  },
                  child: Text(l10n.confirmCancelOrder,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labName = _order.labData?['name']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${l10n.orders} #${_order.qrCode}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.gray900,
                          ),
                        ),
                        if (labName.isNotEmpty)
                          Text(
                            labName,
                            style: const TextStyle(fontSize: 13, color: AppTheme.gray500),
                          ),
                      ],
                    ),
                  ),
                  if (_order.canCancel)
                    TextButton(
                      onPressed: _isCancelling ? null : _cancelOrder,
                      child: Text(
                        l10n.cancelOrder,
                        style: TextStyle(
                          color: _isCancelling ? AppTheme.gray400 : AppTheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshOrder,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_order.status == 'quoted' && _order.prescriptionQuote != null) ...[
                        _buildPrescriptionQuoteCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      _buildLocationMap(l10n),
                      const SizedBox(height: 10),
                      if (_order.nurseData != null && !_order.isMedicineOrder) ...[
                        _buildNurseInfoCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      OrderTimeline(
                        status: _order.status,
                        statusHistory: _order.statusHistory,
                        medicineFlow: _order.isMedicineOrder,
                      ),
                      if (_order.hasSentResult) ...[
                        const SizedBox(height: 10),
                        _buildTestResultsCard(l10n),
                      ],
                      if (_order.status == 'completed') ...[
                        const SizedBox(height: 10),
                        _buildRatingCard(l10n),
                      ],
                      const SizedBox(height: 10),
                      if (_order.isForOtherPerson) ...[
                        _buildBeneficiaryInfoCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      if (!_order.isMedicineOrder &&
                          (_order.scheduledDate != null || _order.timeSlot != null)) ...[
                        _buildScheduledVisitCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      if (!_order.isMedicineOrder) ...[
                        _buildTestsCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      if (_order.tests.isNotEmpty || (_order.isMedicineOrder && _order.totalPrice > 0)) ...[
                        _buildPricingCard(l10n),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                      _buildLocationCard(l10n),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            _buildTrackingActions(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingActions(AppLocalizations l10n) {
    if (_order.isMedicineOrder) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        color: AppTheme.backgroundLavender,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openInvoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.description_outlined, size: 20),
            label: Text(l10n.invoice, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      color: AppTheme.backgroundLavender,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openSampleLabel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: Text(l10n.sampleLabel, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _openInvoice,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.description_outlined, size: 20),
                label: Text(l10n.invoice, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // widget.order (used to build the initial _order, before the first
  // _refreshOrder() call resolves) can come from a list endpoint that
  // doesn't populate every field - e.g. the patient's own orders list
  // never populated patientId at all. Awaiting a fresh fetch here, instead
  // of pushing whatever _order happens to hold at tap time, is what
  // guarantees the label/invoice always get the fully-populated order
  // (patient name, phone, gender, age...) instead of showing blank rows
  // when the button is tapped before the background refresh finishes.
  Future<void> _openSampleLabel() async {
    await _refreshOrder();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SampleLabelScreen(order: _order),
      ),
    );
  }

  void _openResultsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TestResultsScreen(focusOrderId: _order.id),
      ),
    );
  }

  Future<void> _openInvoice() async {
    await _refreshOrder();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(order: _order),
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
                _order.isMedicineOrder
                    ? l10n.deliveryLocation
                    : l10n.sampleCollectionLocation,
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
          if (_order.location.phone != null &&
              _order.location.phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _order.location.phone!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final photo = ApiService.resolveMediaUrl(_order.nurseData?['profilePicture']?.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEAE7FB),
            backgroundImage: (photo != null && photo.isNotEmpty) ? CachedNetworkImageProvider(photo) : null,
            child: (photo == null || photo.isEmpty)
                ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nurseName.isEmpty ? l10n.assignedNurse : nurseName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.gray900),
                ),
                Text(
                  l10n.sampleCollectionTechnician,
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                ),
                if (nurseRating != null && nurseRating > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                      const SizedBox(width: 3),
                      Text(
                        nurseRating is int ? nurseRating.toString() : nurseRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.gray700),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (nursePhone.isNotEmpty) ...[
            _buildCircleActionButton(
              icon: Icons.chat_bubble_rounded,
              filled: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.chatFeatureComingSoon), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildCircleActionButton(
              icon: Icons.phone_rounded,
              filled: true,
              onTap: () => launchUrl(Uri(scheme: 'tel', path: nursePhone)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? Colors.white : AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildLocationMap(AppLocalizations l10n) {
    final patientLatLng = LatLng(_order.location.latitude, _order.location.longitude);

    // The map reveals points progressively as the order moves along:
    // - Waiting for a nurse: patient only.
    // - Nurse assigned: patient + nurse.
    // - Sample collected (QR scanned + paid) onward: patient + nurse + lab.
    const nurseVisibleStatuses = {'nurse_assigned', 'sample_collected', 'at_lab', 'completed'};
    const labVisibleStatuses = {'sample_collected', 'at_lab', 'completed'};

    final nurseLatLng = nurseVisibleStatuses.contains(_order.status)
        ? (_parseLatLng(_order.nurseMapLocation) ??
            _parseLatLng(_order.nurseData?['currentLocation']) ??
            _parseLatLng(_order.nurseData?['defaultLocation']))
        : null;
    final labLatLng = labVisibleStatuses.contains(_order.status)
        ? _parseLatLng(_order.labData?['coordinates'])
        : null;

    return Container(
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
      child: TrackingMap(
        labLocation: labLatLng,
        patientLocation: patientLatLng,
        nurseLocation: nurseLatLng,
        patientPhotoUrl: ApiService.resolveMediaUrl(_order.patientData?['profilePicture'] as String?),
        nursePhotoUrl: ApiService.resolveMediaUrl(_order.nurseData?['profilePicture'] as String?),
        patientName: _order.patientData?['name'] as String?,
        nurseName: _order.nurseData?['name'] as String?,
        height: 175,
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
    if (!_order.hasSentResult) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gray900,
                      ),
                    ),
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
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openResultsPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: Text(
                l10n.viewResult,
                style: const TextStyle(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(AppLocalizations l10n) {
    final subtotal = _order.tests.isNotEmpty
        ? _order.tests.fold(0, (sum, t) => sum + t.price)
        : _order.totalPrice;
    final total = _order.totalPrice > 0 ? _order.totalPrice : subtotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          _buildPricingRow(
            l10n.subtotal,
            _formatPrice(subtotal),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppTheme.gray200),
          ),
          _buildPricingRow(
            l10n.totalAmount,
            _formatPrice(total),
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
      case 'quoted':
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
      case 'quoted':
        return Icons.request_quote_rounded;
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
      case 'quoted':
        return l10n.priceQuoteReceived;
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

extension on Order {
  bool get canCancel {
    // Allow cancellation while pending, awaiting price approval (quoted),
    // or confirmed — but not once a nurse has been assigned or later.
    return (status == 'pending' ||
            status == 'quoted' ||
            status == 'confirmed') &&
        !isCancelled;
  }

  bool get canRate {
    return status == 'completed' && rating?['ratedAt'] == null;
  }

  bool get hasBeenRated {
    return rating?['ratedAt'] != null;
  }
}
