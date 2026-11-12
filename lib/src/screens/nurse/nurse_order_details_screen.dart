import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_orders_service.dart';
import '../../services/order_service.dart';
import '../../widgets/tracking_map.dart';
import '../../../l10n/app_localizations.dart';
import '../order/sample_label_screen.dart';
import 'widgets/qr_manual_input_sheet.dart';

/// Parses a {latitude, longitude} map (as returned by the API) into a LatLng.
LatLng? _parseLatLng(dynamic coords) {
  if (coords is! Map) return null;
  final lat = coords['latitude'];
  final lng = coords['longitude'];
  if (lat == null || lng == null) return null;
  final latNum = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
  final lngNum = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
  if (latNum == null || lngNum == null) return null;
  return LatLng(latNum, lngNum);
}

/// Nurse order details screen with accept button and workflow actions
class NurseOrderDetailsScreen extends StatefulWidget {
  final Order order;
  final Future<void> Function() onRefresh;

  const NurseOrderDetailsScreen({
    super.key,
    required this.order,
    required this.onRefresh,
  });

  @override
  State<NurseOrderDetailsScreen> createState() =>
      _NurseOrderDetailsScreenState();
}

class _NurseOrderDetailsScreenState extends State<NurseOrderDetailsScreen> {
  late Order _order;
  bool _isAccepting = false;
  bool _isUpdating = false;
  bool _isCancelling = false;
  final GlobalKey _shareButtonKey = GlobalKey();
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _syncLocationPush();
  }

  /// While this order is "nurse_assigned" (nurse is on the way), push the
  /// nurse's current GPS position to the server every ~20s so the patient
  /// can see the nurse moving on the tracking map.
  void _syncLocationPush() {
    final shouldPush = _order.status == 'nurse_assigned';
    if (shouldPush && _locationTimer == null) {
      _pushCurrentLocation();
      _locationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _pushCurrentLocation();
      });
    } else if (!shouldPush && _locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }
  }

  Future<void> _pushCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await NurseOrdersService.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // Silently ignore - will retry on the next tick.
    }
  }

  Future<void> _acceptOrder() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(l10n.acceptOrder),
        content: Text(l10n.confirmAcceptOrder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isAccepting = true);

    final result = await NurseOrdersService.acceptOrder(_order.id);

    if (mounted) {
      setState(() => _isAccepting = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.orderAccepted),
            backgroundColor: AppTheme.success,
          ),
        );
        if (result['order'] != null) {
          setState(() => _order = result['order'] as Order);
          _syncLocationPush();
        }
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? l10n.cancel),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await _showCancelConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    final result = await NurseOrdersService.cancelOrder(_order.id, '');

    if (mounted) {
      setState(() => _isCancelling = false);

      final l10n = AppLocalizations.of(context)!;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.nurseCancelOrderSuccess),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Go back and refresh the list
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to cancel order'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
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
        title: Text(l10n.nurseCancelOrder),
        content: Text(l10n.nurseCancelOrderReason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.nurseCancelOrder),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLocation() async {
    final lat = _order.location.latitude;
    final lng = _order.location.longitude;
    
    // Directly launch Google Maps with the location for navigation
    // This opens Google Maps app if installed, or browser otherwise
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    
    try {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback to geo: URI scheme which lets the system pick a maps app
      final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      try {
        await launchUrl(geoUrl);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.mapsNotAvailable),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _scanPatientQRCode() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const _QRScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() => _isUpdating = true);

      final scanResult = await NurseOrdersService.scanPatientQRCode(
        _order.id,
        result,
      );

      if (mounted) {
        setState(() => _isUpdating = false);

        if (scanResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.sampleCollected),
              backgroundColor: AppTheme.success,
            ),
          );
          if (scanResult['order'] != null) {
            setState(() => _order = scanResult['order'] as Order);
            _syncLocationPush();
          }
          widget.onRefresh();
          _openSampleLabel();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(scanResult['message'] ?? l10n.invalidQRCode),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _enterQRCodeManually() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QRManualInputSheet(
        onSubmit: (qrCode) async {
          // Make API call WITHOUT modifying UI state
          final scanResult = await NurseOrdersService.scanPatientQRCode(
            _order.id,
            qrCode,
          );

          if (!mounted) return qrCode;

          // Update state after API completes
          if (scanResult['success'] == true) {
            // Update order state
            if (scanResult['order'] != null) {
              _order = scanResult['order'] as Order;
              _syncLocationPush();
            }
            // Return success - QRManualInputSheet will handle navigation
            return qrCode;
          } else {
            // Show error and throw to prevent QRManualInputSheet from closing
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(scanResult['message'] ?? l10n.invalidQRCode),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            });
            throw Exception(scanResult['message'] ?? l10n.invalidQRCode);
          }
        },
      ),
    );

    // Show success message after bottom sheet closes
    if (result != null && mounted) {
      setState(() {}); // Trigger rebuild to show updated order
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sampleCollected),
          backgroundColor: AppTheme.success,
        ),
      );
      widget.onRefresh();
      _openSampleLabel();
    }
  }

  void _openSampleLabel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SampleLabelScreen(order: _order),
      ),
    );
  }

  Future<void> _copyQRCode() async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: _order.qrCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.qrCodeCopied),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _calculateAge(dynamic birthDate) {
    if (birthDate == null) return '';

    DateTime dob;
    if (birthDate is String) {
      dob = DateTime.tryParse(birthDate) ?? DateTime.now();
    } else if (birthDate is DateTime) {
      dob = birthDate;
    } else {
      return '';
    }

    final today = DateTime.now();
    int age = today.year - dob.year;

    // Adjust if birthday hasn't occurred yet this year
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }

    return '$age';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.info;
      case 'nurse_assigned':
        return AppTheme.primaryColor;
      case 'sample_collected':
        return Colors.orange;
      case 'at_lab':
        return Colors.cyan;
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
        return Icons.bloodtype_rounded;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(_order.status);
    final statusIcon = _getStatusIcon(_order.status);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        title: Text(l10n.orderDetails),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 24,
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
                              fontSize: 12,
                              color: AppTheme.gray600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusDisplayName(_order.status, l10n),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_order.status == 'sample_collected' ||
                        _order.status == 'at_lab' ||
                        _order.status == 'completed')
                      Text(
                        '#${_order.qrCode}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray500,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Sample label for lab (show when sample is collected)
              if (_order.status == 'sample_collected' ||
                  _order.status == 'at_lab' ||
                  _order.status == 'completed')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E0F8)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3EDFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: _order.qrCode,
                              version: QrVersions.auto,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.sampleLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.gray900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.stickOnSample,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: AppTheme.gray600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '#${_order.qrCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
                                onPressed: _copyQRCode,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: Text(l10n.copyQRCode, overflow: TextOverflow.ellipsis, maxLines: 1),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _openSampleLabel,
                                icon: const Icon(Icons.print_outlined, size: 16),
                                label: Text(l10n.printLabel, overflow: TextOverflow.ellipsis, maxLines: 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Payment Breakdown (shown after payment is collected)
              if (_order.paymentCollected != null &&
                  _order.paymentCollected!['collected'] == true &&
                  _order.financials != null)
                _buildPaymentBreakdownSection(context),

              const SizedBox(height: 12),

              // Patient Information
              _buildSectionTitle(l10n.patientInfo, Icons.person_rounded),
              const SizedBox(height: 8),
              _buildInfoCard(
                children: [
                  if (_order.patientData != null) ...[
                    if (_order.patientData!['name'] != null)
                      _buildInfoRow(
                        Icons.person_rounded,
                        l10n.fullName,
                        _order.patientData!['name'],
                      ),
                    if (_order.patientData!['phone'] != null)
                      _buildInfoRow(
                        Icons.phone_rounded,
                        l10n.phoneNumber,
                        _order.patientData!['phone'],
                      ),
                    if (_order.patientData!['birthDate'] != null)
                      _buildInfoRow(
                        Icons.cake_rounded,
                        l10n.age,
                        _calculateAge(_order.patientData!['birthDate']),
                      ),
                  ],
                  _buildInfoRow(
                    Icons.receipt_long_rounded,
                    l10n.tests,
                    '${_order.tests.length}',
                  ),
                  _buildInfoRow(
                    Icons.attach_money_rounded,
                    l10n.totalAmount,
                    '${_order.formattedTotalPrice} IQD',
                  ),
                ],
              ),

              // Beneficiary Info (if ordering for another person)
              if (_order.isForOtherPerson) ...[
                const SizedBox(height: 12),
                _buildSectionTitle(l10n.orderForOtherPerson, Icons.person_add_alt_1_rounded),
                const SizedBox(height: 8),
                _buildBeneficiaryCard(l10n),
              ],

              const SizedBox(height: 12),

              // Lab Information
              if (_order.labData != null) ...[
                _buildSectionTitle(l10n.labInfo, Icons.science_rounded),
                const SizedBox(height: 8),
                _buildInfoCard(
                  children: [
                    if (_order.labData!['name'] != null)
                      _buildInfoRow(
                        Icons.business_rounded,
                        'Lab Name',
                        _order.labData!['name'],
                      ),
                    if (_order.labData!['address'] != null)
                      _buildInfoRow(
                        Icons.location_on_rounded,
                        l10n.address,
                        _order.labData!['address'],
                      ),
                    if (_order.labData!['phone'] != null)
                      _buildInfoRow(
                        Icons.phone_rounded,
                        'Phone',
                        _order.labData!['phone'],
                      ),
                    if (_order.labData!['city'] != null)
                      _buildInfoRow(
                        Icons.location_city_rounded,
                        l10n.city,
                        _order.labData!['city'],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Collection Location
              _buildSectionTitle(l10n.collectionLocation, Icons.location_on_rounded),
              const SizedBox(height: 8),
              _buildLocationCard(l10n),

              const SizedBox(height: 12),

              // Tests List
              _buildSectionTitle(l10n.scheduledTests, Icons.biotech_rounded),
              const SizedBox(height: 8),
              _buildTestsCard(l10n),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(l10n),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.gray900,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final financials = _order.financials!;
    final numberFormat = NumberFormat('#,###', 'en_US');

    // Calculate admin commission (lab commission)
    final totalPrice = _order.totalPrice;
    final labAmount = financials.labAmount;
    final nurseEarning = financials.nurseEarning;
    final adminCommission = totalPrice - labAmount - nurseEarning;

    // Calculate commission rate percentage for admin
    final adminCommissionRate = totalPrice > 0 ? (adminCommission / totalPrice * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.15),
            AppTheme.success.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.15),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: AppTheme.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.paymentBreakdown,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.success),
          const SizedBox(height: 16),

          // Payment collected row
          _buildBreakdownRow(
            l10n.paymentCollected,
            '${_order.formattedTotalPrice} IQD',
            Icons.account_balance_wallet_rounded,
            AppTheme.gray700,
          ),
          const SizedBox(height: 12),

          // Lab amount row
          _buildBreakdownRow(
            l10n.payToLab,
            '${numberFormat.format(labAmount.toInt())} IQD',
            Icons.science_rounded,
            AppTheme.info,
            highlighted: true,
          ),
          const SizedBox(height: 12),

          // Lab commission (admin commission) row - GREEN SUCCESS
          _buildBreakdownRow(
            '${l10n.labCommission} (${adminCommissionRate.toStringAsFixed(1)}%)',
            '${numberFormat.format(adminCommission.toInt())} IQD',
            Icons.trending_up_rounded,
            AppTheme.success,
            highlighted: true,
            isCommission: true,
          ),

          if (!financials.labSettled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.rememberPayLab,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.gray800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool highlighted = false,
    bool isCommission = false,
  }) {
    return Container(
      padding: highlighted ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: isCommission
                  ? AppTheme.success.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: isCommission
                  ? Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                      width: 1.5,
                    )
                  : null,
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isCommission ? AppTheme.success : color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: highlighted ? AppTheme.gray900 : AppTheme.gray600,
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCommission ? AppTheme.success : (highlighted ? color : AppTheme.gray900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.gray500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryCard(AppLocalizations l10n) {
    final name = _order.beneficiary?['name']?.toString() ?? '';
    final phone = _order.beneficiary?['phone']?.toString() ?? '';
    final gender = _order.beneficiary?['gender']?.toString();
    final relationship = _order.beneficiary?['relationship']?.toString();

    String getRelationshipLabel(String value) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty)
            _buildInfoRow(Icons.person_rounded, l10n.beneficiaryName, name),
          if (phone.isNotEmpty)
            _buildInfoRow(Icons.phone_rounded, l10n.beneficiaryPhone, phone),
          if (gender != null)
            _buildInfoRow(Icons.wc_rounded, l10n.gender, gender == 'male' ? l10n.male : l10n.female),
          if (relationship != null)
            _buildInfoRow(Icons.family_restroom_rounded, l10n.relationship, getRelationshipLabel(relationship)),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview - shows the lab and the patient's collection point
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TrackingMap(
              labLocation: _parseLatLng(_order.labData?['coordinates']),
              patientLocation: LatLng(
                _order.location.latitude,
                _order.location.longitude,
              ),
              height: 120,
            ),
          ),

          const SizedBox(height: 10),

          // Share Location button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: _shareButtonKey,
              onPressed: _shareLocation,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(l10n.shareLocation, overflow: TextOverflow.ellipsis, maxLines: 1),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Address details
          _buildInfoRow(
            Icons.location_on_rounded,
            l10n.address,
            _order.location.address,
          ),
          if (_order.location.landmark != null)
            _buildInfoRow(
              Icons.landscape_rounded,
              l10n.landmark,
              _order.location.landmark!,
            ),
          if (_order.location.buildingName != null)
            _buildInfoRow(
              Icons.apartment_rounded,
              l10n.buildingName,
              _order.location.buildingName!,
            ),
          if (_order.location.floorNumber != null)
            _buildInfoRow(
              Icons.layers_rounded,
              l10n.floor,
              _order.location.floorNumber!,
            ),
          if (_order.location.apartmentNumber != null)
            _buildInfoRow(
              Icons.door_front_door_rounded,
              l10n.apartment,
              _order.location.apartmentNumber!,
            ),
          if (_order.location.instructions != null)
            _buildInfoRow(
              Icons.info_rounded,
              l10n.enterInstructions,
              _order.location.instructions!,
            ),
        ],
      ),
    );
  }

  Widget _buildTestsCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: _order.tests.map((test) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.testName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                        ),
                      ),
                      if (test.category != null)
                        Text(
                          test.category!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${test.price} IQD',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomActionBar(AppLocalizations l10n) {
    // Show accept button for confirmed orders without nurse
    if (_order.status == 'confirmed' && _order.nurseId == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isAccepting ? null : _acceptOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              child: _isAccepting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.acceptOrder),
            ),
          ),
        ),
      );
    }

    // Show Scan QR button for nurse_assigned status
    if (_order.status == 'nurse_assigned' && _order.nurseId != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primary: Scan button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isUpdating || _isCancelling) ? null : _scanPatientQRCode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l10n.scanPatientQR, overflow: TextOverflow.ellipsis, maxLines: 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Row with manual input and cancel button
              Row(
                children: [
                  // Manual QR input
                  Expanded(
                    child: TextButton.icon(
                      onPressed: (_isUpdating || _isCancelling) ? null : _enterQRCodeManually,
                      icon: const Icon(Icons.keyboard_rounded, size: 16),
                      label: Text(
                        l10n.enterQRManually,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                  ),
                  // Cancel order button
                  Expanded(
                    child: TextButton.icon(
                      onPressed: (_isUpdating || _isCancelling) ? null : _cancelOrder,
                      icon: _isCancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.error),
                      label: Text(
                        l10n.nurseCancelOrder,
                        style: TextStyle(
                          fontSize: 13,
                          color: _isCancelling ? AppTheme.gray400 : AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // No action button for other statuses - lab handles the rest
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}

/// QR Scanner Screen using mobile_scanner package
class _QRScannerScreen extends StatefulWidget {
  const _QRScannerScreen();

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  MobileScannerController? _controller;
  bool _hasScanned = false;
  bool _isTorchOn = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? scannedValue = barcodes.first.rawValue;
    if (scannedValue == null || scannedValue.isEmpty) return;

    setState(() => _hasScanned = true);

    // Haptic feedback for successful scan
    HapticFeedback.mediumImpact();

    // Return the scanned value
    Navigator.pop(context, scannedValue);
  }

  void _toggleTorch() async {
    if (_controller == null) return;
    
    try {
      await _controller!.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (e) {
      // Torch not available
    }
  }

  void _switchCamera() async {
    if (_controller == null) return;
    
    try {
      await _controller!.switchCamera();
    } catch (e) {
      // Camera switch not available
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.scanQRCode),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        actions: [
          // Torch toggle
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.white,
            ),
          ),
          // Camera switch
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorView(l10n)
          : Stack(
              children: [
                // Camera preview
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_hasError) {
                        setState(() {
                          _hasError = true;
                          _errorMessage = error.errorDetails?.message ??
                              'Camera permission denied or unavailable';
                        });
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
                // Scanner overlay
                _ScannerOverlayWidget(scanWindow: _getScanWindowRect(context)),
                // Instructions at bottom
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.scanPatientQR,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.keyboard_rounded,
                          color: Colors.white70,
                        ),
                        label: Text(
                          l10n.enterQRManually,
                          style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Rect _getScanWindowRect(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanWindowSize = screenSize.width * 0.7;
    return Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2 - 50),
      width: scanWindowSize,
      height: scanWindowSize,
    );
  }

  Widget _buildErrorView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Access Required',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Please enable camera access in your device settings to scan QR codes.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(l10n.enterQRManually),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                    });
                    _controller?.dispose();
                    _initializeScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom scanner overlay with animated frame
class _ScannerOverlayWidget extends StatelessWidget {
  final Rect scanWindow;

  const _ScannerOverlayWidget({required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(scanWindow: scanWindow),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  const _ScannerOverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent overlay
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final scanWindowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanWindowPath,
    );

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw scan window border
    final borderPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      borderPaint,
    );

    // Draw corner accents
    final cornerPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    const cornerRadius = 16.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top + cornerRadius + cornerLength),
      Offset(scanWindow.left, scanWindow.top + cornerRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left + cornerRadius, scanWindow.top),
      Offset(scanWindow.left + cornerRadius + cornerLength, scanWindow.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.top + cornerRadius + cornerLength),
      Offset(scanWindow.right, scanWindow.top + cornerRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right - cornerRadius, scanWindow.top),
      Offset(scanWindow.right - cornerRadius - cornerLength, scanWindow.top),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom - cornerRadius - cornerLength),
      Offset(scanWindow.left, scanWindow.bottom - cornerRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left + cornerRadius, scanWindow.bottom),
      Offset(scanWindow.left + cornerRadius + cornerLength, scanWindow.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.bottom - cornerRadius - cornerLength),
      Offset(scanWindow.right, scanWindow.bottom - cornerRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right - cornerRadius, scanWindow.bottom),
      Offset(scanWindow.right - cornerRadius - cornerLength, scanWindow.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) => 
      scanWindow != oldDelegate.scanWindow;
}
