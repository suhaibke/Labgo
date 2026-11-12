import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/coupon_service.dart';
import '../../services/lab_service.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map_tiles.dart';
import '../../widgets/bilingual_test_name.dart';
import 'location_selection_screen.dart';
import 'order_details_screen.dart';

class NewOrderFlowScreen extends StatefulWidget {
  const NewOrderFlowScreen({super.key});

  @override
  State<NewOrderFlowScreen> createState() => _NewOrderFlowScreenState();
}

class _NewOrderFlowScreenState extends State<NewOrderFlowScreen> {
  static const _iconTints = [
    Color(0xFFEAE7FB),
    Color(0xFFFFE8D6),
    Color(0xFFE4F6EC),
    Color(0xFFE8F1FF),
    Color(0xFFFDE8F3),
  ];
  static const _iconColors = [
    AppTheme.primaryColor,
    Color(0xFFEFA24B),
    Color(0xFF2FA36B),
    Color(0xFF4B8EDC),
    Color(0xFFD8509B),
  ];
  static const _testIcons = [
    TablerIcons.heartbeat,
    TablerIcons.bolt,
    TablerIcons.heart,
    TablerIcons.droplet,
    TablerIcons.test_pipe,
  ];

  int _step = 0;
  bool _isSubmitting = false;
  Order? _createdOrder;

  List<Lab> _labs = [];
  bool _loadingLabs = true;
  Lab? _selectedLab;
  LatLng? _userLocation;

  bool _loadingTests = false;
  final Set<String> _selectedTestIds = {};
  final TextEditingController _testSearchController = TextEditingController();
  String _testSearchQuery = '';

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedTime;

  OrderLocation? _selectedLocation;
  File? _prescriptionImage;
  final ImagePicker _imagePicker = ImagePicker();
  String? _profilePhotoUrl;
  String? _profileName;

  final TextEditingController _couponController = TextEditingController();
  String? _appliedCouponCode;
  int _couponDiscount = 0;
  bool _isValidatingCoupon = false;
  String? _couponError;

  bool _isForOtherPerson = false;
  final TextEditingController _beneficiaryNameController =
      TextEditingController();
  final TextEditingController _beneficiaryPhoneController =
      TextEditingController();
  String? _beneficiaryGender;
  DateTime? _beneficiaryBirthDate;
  String? _beneficiaryRelationship;

  final List<String> _relationshipOptions = [
    'spouse',
    'child',
    'parent',
    'sibling',
    'other',
  ];

  final List<String> _timeSlots = [
    for (var h = 8; h <= 20; h++)
      for (final m in (h == 20 ? [0] : [0, 30]))
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadLabs();
    _loadUserLocation();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getUserData();
    if (!mounted || user == null) return;
    setState(() {
      _profilePhotoUrl = ApiService.resolveMediaUrl(user['profilePicture']?.toString());
      _profileName = user['name']?.toString();
    });
  }

  @override
  void dispose() {
    _beneficiaryNameController.dispose();
    _beneficiaryPhoneController.dispose();
    _couponController.dispose();
    _testSearchController.dispose();
    super.dispose();
  }

  List<LabTest> get _tests => _selectedLab?.testObjects ?? const [];

  List<LabTest> get _visibleTests {
    final query = _testSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _tests;
    return _tests.where((test) {
      return test.name.toLowerCase().contains(query) ||
          (test.nameAr?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<LabTest> get _selectedTests =>
      _tests.where((t) => _selectedTestIds.contains(t.id)).toList();

  int get _totalPrice =>
      _selectedTests.fold<int>(0, (sum, test) => sum + test.price);

  String _money(int price, AppLocalizations l10n) {
    final formatted = NumberFormat('#,###', 'en_US').format(price);
    return '$formatted ${l10n.iqd}';
  }

  int get _finalTotal => (_totalPrice - _couponDiscount).clamp(0, _totalPrice);

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    final result = await CouponService.validateCoupon(code: code, orderTotal: _totalPrice);
    if (!mounted) return;

    setState(() {
      _isValidatingCoupon = false;
      if (result['success'] == true) {
        _appliedCouponCode = code.toUpperCase();
        _couponDiscount = result['discountAmount'] as int;
        _couponError = null;
      } else {
        _appliedCouponCode = null;
        _couponDiscount = 0;
        _couponError = result['message']?.toString();
      }
    });
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0;
      _couponController.clear();
      _couponError = null;
    });
  }

  Future<void> _loadLabs() async {
    setState(() => _loadingLabs = true);
    try {
      final token = await AuthService().getToken();

      // A lab in a different governorate can't serve this patient, so keep
      // this list scoped the same way the Labs browse screen is.
      String? userCity;
      if (!AuthService.isGuestMode) {
        final userData = await AuthService().getUserData();
        userCity = userData?['city'] as String?;
      }

      final result = await LabService.getAllLabs(token: token, city: userCity);
      if (!mounted) return;
      if (result['success'] == true) {
        final labsData = result['labs'] as List? ?? [];
        setState(() {
          _labs = labsData
              .whereType<Map>()
              .map((json) => Lab.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          if (_labs.isNotEmpty && _selectedLab == null) {
            _selectedLab = _labs.first;
          }
          _loadingLabs = false;
        });
      } else {
        setState(() => _loadingLabs = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLabs = false);
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Distance is optional.
    }
  }

  String? _distanceLabel(Lab lab) {
    if (_userLocation == null || !lab.hasCoordinates) return null;
    final km = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(lab.latitude!, lab.longitude!),
      _userLocation!,
    );
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _selectLab(Lab lab) async {
    setState(() {
      _selectedLab = lab;
      _selectedTestIds.clear();
    });
  }

  Future<void> _ensureLabTests() async {
    final lab = _selectedLab;
    if (lab == null) return;

    setState(() => _loadingTests = true);
    final token = await AuthService().getToken();
    final result = await LabService.getLabDetails(labId: lab.id, token: token);
    if (!mounted) return;
    if (result['success'] == true && result['lab'] != null) {
      final raw = result['lab'];
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final source = map.containsKey('name')
          ? map
          : Map<String, dynamic>.from(map['lab'] as Map? ?? map);
      setState(() {
        _selectedLab = Lab.fromJson(source);
        _loadingTests = false;
      });
    } else {
      setState(() => _loadingTests = false);
    }
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _goNext() async {
    final l10n = AppLocalizations.of(context)!;
    if (_step == 0) {
      if (_selectedLab == null) {
        _snack(l10n.pleaseSelectLab);
        return;
      }
      setState(() => _step = 1);
      await _ensureLabTests();
      return;
    }
    if (_step == 1) {
      if (_selectedTestIds.isEmpty && _prescriptionImage == null) {
        _snack(l10n.pleaseSelectTests);
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (_selectedDate == null || _selectedTime == null) {
        _snack(l10n.pleaseSelectDate);
        return;
      }
      setState(() => _step = 3);
      return;
    }
    if (_step == 3) {
      await _submitOrder();
    }
  }

  void _goBack() {
    if (_createdOrder != null) {
      Navigator.pop(context);
      return;
    }
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  Map<String, String> _timeSlotPayload(String start) {
    final parts = start.split(':');
    var hour = int.parse(parts[0]) + 2;
    final minute = parts[1];
    if (hour > 22) hour = 22;
    return {
      'start': start,
      'end': '${hour.toString().padLeft(2, '0')}:$minute',
    };
  }

  Future<void> _submitOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedLocation == null) {
      _snack(l10n.pleaseEnterAddress);
      return;
    }
    if (_isForOtherPerson) {
      if (_beneficiaryNameController.text.trim().isEmpty) {
        _snack(l10n.pleaseEnterBeneficiaryName);
        return;
      }
      if (_beneficiaryPhoneController.text.trim().isEmpty) {
        _snack(l10n.pleaseEnterBeneficiaryPhone);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // No tests picked but a prescription attached: send as a
    // prescription-only order. The admin reads the prescription, sets a
    // price, and the patient approves it before the normal flow continues.
    final isPrescriptionOnly =
        _selectedTests.isEmpty && _prescriptionImage != null;

    await CartService.clearCart();
    for (final test in _selectedTests) {
      final added = await CartService.addToCart(
        labId: _selectedLab!.id,
        testId: test.id,
      );
      if (added['success'] != true) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _snack(added['message']?.toString() ?? l10n.pleaseSelectTests);
        return;
      }
    }

    Map<String, dynamic>? beneficiaryData;
    if (_isForOtherPerson) {
      beneficiaryData = {
        'name': _beneficiaryNameController.text.trim(),
        'phone': _beneficiaryPhoneController.text.trim(),
        if (_beneficiaryGender != null) 'gender': _beneficiaryGender,
        if (_beneficiaryBirthDate != null)
          'birthDate': _beneficiaryBirthDate!.toIso8601String(),
        if (_beneficiaryRelationship != null)
          'relationship': _beneficiaryRelationship,
      };
    }

    final result = await OrderService.createOrder(
      location: _selectedLocation!,
      prescriptionImage: _prescriptionImage,
      scheduledDate: _selectedDate?.toIso8601String(),
      timeSlot: _selectedTime == null ? null : _timeSlotPayload(_selectedTime!),
      labId: _selectedLab!.id,
      prescriptionOnly: isPrescriptionOnly,
      beneficiary: beneficiaryData,
      patientNotes: !_isForOtherPerson && (_selectedLocation?.phone?.isNotEmpty ?? false)
          ? 'هاتف التواصل: ${_selectedLocation!.phone}'
          : null,
      couponCode: isPrescriptionOnly ? null : _appliedCouponCode,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await CartService.clearCart();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _createdOrder = result['order'] as Order?;
        _step = 4;
      });
    } else {
      setState(() => _isSubmitting = false);
      _snack(result['message']?.toString() ?? 'Failed to create order');
    }
  }

  Future<void> _selectLocation() async {
    final location = await Navigator.push<OrderLocation>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectionScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );
    if (location != null) {
      setState(() => _selectedLocation = location);
    }
  }

  Future<void> _pickPrescription() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _prescriptionImage = File(image.path));
      }
    } catch (_) {}
  }

  Future<void> _openOrder({required bool invoice}) async {
    final order = _createdOrder;
    if (order == null) {
      Navigator.pop(context);
      return;
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(
          order: order,
          showInvoiceOnOpen: invoice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: _step == 0 || _createdOrder != null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLavender,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(child: _buildBody(l10n)),
              if (_step < 4) _buildFooter(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _roundIconButton(Icons.arrow_forward_ios_rounded, _goBack),
              Expanded(
                child: Text(
                  l10n.newRequest,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1444),
                  ),
                ),
              ),
              const SizedBox(width: 42),
            ],
          ),
          const SizedBox(height: 18),
          _OrderStepper(
            currentStep: _step,
            labels: [
              l10n.chooseLaboratory,
              l10n.chooseTests,
              l10n.chooseAppointment,
              l10n.orderInformation,
              l10n.confirmation,
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 16, color: const Color(0xFF1B1444)),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _buildLabsStep(l10n);
      case 1:
        return _buildTestsStep(l10n);
      case 2:
        return _buildAppointmentStep(l10n);
      case 3:
        return _buildInfoStep(l10n);
      default:
        return _buildSuccessStep(l10n);
    }
  }

  Widget _buildLabsStep(AppLocalizations l10n) {
    if (_loadingLabs) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (_labs.isEmpty) {
      return Center(child: Text(l10n.noLabsFound));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chooseLaboratory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1444),
                  ),
                ),
              ),
              Text(
                l10n.labsCount(_labs.length),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _labs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final lab = _labs[index];
              final selected = _selectedLab?.id == lab.id;
              return _labCard(lab, selected);
            },
          ),
        ),
      ],
    );
  }

  Widget _labCard(Lab lab, bool selected) {
    final rating = lab.averageRating;
    final distance = _distanceLabel(lab);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectLab(lab),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : const Color(0xFFE8E4F5),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _radio(selected),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lab.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1444),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (rating != null && rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFF5B942),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray700,
                            ),
                          ),
                        ],
                        if (distance != null) ...[
                          if (rating != null && rating > 0)
                            const Text(
                              '  •  ',
                              style: TextStyle(color: AppTheme.gray400),
                            ),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.gray600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: lab.logo != null && lab.logo!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: lab.logo!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _labFallback(),
                        )
                      : _labFallback(),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppTheme.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labFallback() {
    return Container(
      color: const Color(0xFFEAE7FB),
      child: const Icon(TablerIcons.flask, color: AppTheme.primaryColor),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.primaryColor : AppTheme.gray300,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTestsStep(AppLocalizations l10n) {
    if (_loadingTests) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (_tests.isEmpty) {
      return Center(child: Text(l10n.noTestsAvailable));
    }

    final visibleTests = _visibleTests;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildPrescriptionCard(l10n),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chooseTests,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1444),
                  ),
                ),
              ),
              Text(
                l10n.testsSelectedCount(_selectedTestIds.length),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _testSearchController,
              onChanged: (value) => setState(() => _testSearchQuery = value),
              style: const TextStyle(fontSize: 14, color: AppTheme.gray900),
              decoration: InputDecoration(
                hintText: l10n.searchTests,
                hintStyle: const TextStyle(fontSize: 14, color: AppTheme.gray400),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.gray400, size: 20),
                suffixIcon: _testSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.gray400),
                        onPressed: () {
                          _testSearchController.clear();
                          setState(() => _testSearchQuery = '');
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: visibleTests.isEmpty
              ? Center(
                  child: Text(
                    l10n.noTestsAvailable,
                    style: const TextStyle(color: AppTheme.gray500, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: visibleTests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _testCard(
                    visibleTests[index],
                    _tests.indexOf(visibleTests[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _testCard(LabTest test, int index) {
    final selected = _selectedTestIds.contains(test.id);
    final tint = _iconTints[index % _iconTints.length];
    final color = _iconColors[index % _iconColors.length];
    final icon = _testIcons[index % _testIcons.length];
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedTestIds.remove(test.id);
            } else {
              _selectedTestIds.add(test.id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: test.hasImage
                    ? CachedNetworkImage(
                        imageUrl: test.image!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: color, size: 22),
                      )
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilingualTestName(
                      test: test,
                      arabicSize: 15,
                      englishSize: 11.5,
                      arabicWeight: FontWeight.w800,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _money(test.price, l10n),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _checkCircle(selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkCircle(bool selected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.primaryColor : Colors.transparent,
        border: Border.all(
          color: selected ? AppTheme.primaryColor : AppTheme.gray300,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _buildAppointmentStep(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _card(
          child: Column(
            children: [
              Row(
                children: [
                  _roundIconButton(
                    Icons.chevron_right_rounded,
                    () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                      );
                    }),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'MMMM yyyy',
                        Localizations.localeOf(context).languageCode,
                      ).format(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1444),
                      ),
                    ),
                  ),
                  _roundIconButton(
                    Icons.chevron_left_rounded,
                    () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _calendarGrid(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.availableTimes,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B1444),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((slot) {
            final selected = _selectedTime == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedTime = slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? AppTheme.primaryColor : AppTheme.gray200,
                  ),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF1B1444),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _calendarGrid() {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = List.generate(7, (i) {
      final date = DateTime(2024, 1, 7 + i);
      final label = DateFormat.E(locale).format(date);
      return label.length > 3 ? label.substring(0, 2) : label;
    });
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[
      for (final label in labels)
        Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray500,
            ),
          ),
        ),
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(
          DateTime(_visibleMonth.year, _visibleMonth.month, day),
          todayDate,
        ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.05,
      children: cells,
    );
  }

  Widget _dayCell(DateTime date, DateTime today) {
    final selected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;
    final last = today.add(const Duration(days: 30));
    final disabled = date.isBefore(today) || date.isAfter(last);

    return GestureDetector(
      onTap: disabled
          ? null
          : () => setState(() => _selectedDate = date),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: disabled
                  ? AppTheme.gray300
                  : selected
                      ? Colors.white
                      : const Color(0xFF1B1444),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        _buildLocationCard(l10n),
        const SizedBox(height: 8),
        _buildBeneficiaryCard(l10n),
        if (_totalPrice > 0) ...[
          const SizedBox(height: 8),
          _buildCouponCard(l10n),
        ],
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7257D8).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    String? trailing,
    Color? color,
  }) {
    final accent = color ?? AppTheme.primaryColor;
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1444),
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
      ],
    );
  }

  Widget _buildLocationCard(AppLocalizations l10n) {
    final hasLocation = _selectedLocation != null;
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLocation)
            SizedBox(
              height: 96,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: FlutterMap(
                  key: ValueKey(
                    '${_selectedLocation!.latitude}_${_selectedLocation!.longitude}',
                  ),
                  options: MapOptions(
                    initialCenter: LatLng(
                      _selectedLocation!.latitude,
                      _selectedLocation!.longitude,
                    ),
                    initialZoom: 15.6,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    const AppMapTileLayer(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selectedLocation!.latitude,
                            _selectedLocation!.longitude,
                          ),
                          width: 52,
                          height: 66,
                          child: MapCenterPin(
                            size: 40,
                            photoUrl: _profilePhotoUrl,
                            name: _profileName,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  icon: hasLocation ? TablerIcons.check : TablerIcons.map_pin,
                  title: l10n.sampleCollectionLocation,
                  color: hasLocation ? AppTheme.success : AppTheme.primaryColor,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: hasLocation
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation!.address,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1444),
                                ),
                              ),
                              if (_selectedLocation!.landmark != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _selectedLocation!.landmark!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                              if (_selectedLocation!.phone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _selectedLocation!.phone!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            l10n.selectLocation,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(AppLocalizations l10n) {
    final hasImage = _prescriptionImage != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: hasImage ? TablerIcons.check : TablerIcons.upload,
            title: l10n.uploadPrescription,
            trailing: l10n.optional,
            color: hasImage ? AppTheme.success : AppTheme.primaryColor,
          ),
          const SizedBox(height: 8),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _prescriptionImage!,
                height: 72,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: hasImage
                ? () => setState(() => _prescriptionImage = null)
                : _pickPrescription,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: hasImage
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                hasImage ? l10n.remove : l10n.selectPrescription,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasImage ? AppTheme.error : AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(AppLocalizations l10n) {
    final applied = _appliedCouponCode != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: applied ? TablerIcons.check : TablerIcons.discount_2,
            title: 'قسيمة الخصم',
            trailing: l10n.optional,
            color: applied ? AppTheme.success : AppTheme.primaryColor,
          ),
          const SizedBox(height: 8),
          if (applied) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_appliedCouponCode · خصم ${_money(_couponDiscount, l10n)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الخصم',
                      hintStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isValidatingCoupon ? null : _applyCoupon,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isValidatingCoupon
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'تطبيق',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(_couponError!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBeneficiaryCard(AppLocalizations l10n) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _isForOtherPerson = !_isForOtherPerson),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderForOtherPerson,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1444),
                    ),
                  ),
                ),
                _checkCircle(_isForOtherPerson),
              ],
            ),
          ),
          if (_isForOtherPerson) ...[
            const SizedBox(height: 10),
            _field(
              controller: _beneficiaryNameController,
              hint: l10n.enterOtherPersonName,
            ),
            const SizedBox(height: 8),
            _field(
              controller: _beneficiaryPhoneController,
              hint: l10n.enterOtherPersonPhone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _genderChip(l10n.male, 'male')),
                const SizedBox(width: 8),
                Expanded(child: _genderChip(l10n.female, 'female')),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBirthDate,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _beneficiaryBirthDate != null
                      ? DateFormat.yMMMd().format(_beneficiaryBirthDate!)
                      : l10n.selectDateOfBirth,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _beneficiaryBirthDate != null
                        ? AppTheme.gray900
                        : AppTheme.gray500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _beneficiaryRelationship,
                  hint: Text(
                    l10n.relationship,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray500,
                    ),
                  ),
                  items: _relationshipOptions
                      .map(
                        (rel) => DropdownMenuItem(
                          value: rel,
                          child: Text(_relationshipLabel(rel, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _beneficiaryRelationship = value),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.gray500,
          ),
          filled: true,
          fillColor: AppTheme.backgroundLavender,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _genderChip(String label, String value) {
    final selected = _beneficiaryGender == value;
    return GestureDetector(
      onTap: () => setState(() => _beneficiaryGender = value),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.backgroundLavender,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppTheme.primaryColor : AppTheme.gray700,
          ),
        ),
      ),
    );
  }

  String _relationshipLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'spouse':
        return l10n.spouse;
      case 'child':
        return l10n.child;
      case 'parent':
        return l10n.parent;
      case 'sibling':
        return l10n.sibling;
      default:
        return l10n.other;
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _beneficiaryBirthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.gray900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _beneficiaryBirthDate = picked);
  }

  Widget _buildSuccessStep(AppLocalizations l10n) {
    final order = _createdOrder;
    final code = order?.qrCode.isNotEmpty == true
        ? order!.qrCode
        : (order?.id.substring(0, order.id.length.clamp(0, 6)) ?? '—');
    final price = order?.totalPrice ?? _totalPrice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.orderConfirmedTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1444),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.orderConfirmedSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  l10n.orderNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#$code',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1444),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(price, l10n),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _openOrder(invoice: false),
              icon: const Icon(TablerIcons.map_pin, size: 20),
              label: Text(
                l10n.trackOrder,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              overflow: TextOverflow.ellipsis, maxLines: 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _openOrder(invoice: true),
              icon: const Icon(TablerIcons.file_text, size: 20),
              label: Text(
                l10n.viewInvoice,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              overflow: TextOverflow.ellipsis, maxLines: 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 1 && _selectedTestIds.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.testsSelectedLabel(_selectedTestIds.length),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1444),
                      ),
                    ),
                  ),
                  Text(
                    _money(_totalPrice, l10n),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          if (_step == 3 && _totalPrice > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  if (_couponDiscount > 0) ...[
                    Row(
                      children: [
                        Text(
                          'المجموع الفرعي',
                          style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                        ),
                        const Spacer(),
                        Text(
                          _money(_totalPrice, l10n),
                          style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'الخصم',
                          style: TextStyle(fontSize: 12, color: AppTheme.success),
                        ),
                        const Spacer(),
                        Text(
                          '- ${_money(_couponDiscount, l10n)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.success),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1),
                    ),
                  ],
                  Row(
                    children: [
                      const Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1444),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _money(_finalTotal, l10n),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _goNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
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
                        Text(
                          _step == 3 ? l10n.confirmOrder : l10n.next,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_back_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStepper extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const _OrderStepper({
    required this.currentStep,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Positioned(
            top: 13,
            left: 28,
            right: 28,
            child: Row(
              children: List.generate(n - 1, (i) {
                return Expanded(
                  child: Container(
                    height: 3,
                    color: i < currentStep
                        ? AppTheme.primaryColor
                        : const Color(0xFFE4DEF6),
                  ),
                );
              }),
            ),
          ),
          Row(
            children: List.generate(n, (i) {
              final done = i < currentStep;
              final active = i == currentStep;
              return Expanded(
                child: Column(
                  children: [
                    _dot(index: i, done: done, active: active),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: active || done
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: active || done
                            ? AppTheme.primaryColor
                            : AppTheme.gray400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dot({
    required int index,
    required bool done,
    required bool active,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: done || active ? AppTheme.primaryColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color:
              done || active ? AppTheme.primaryColor : const Color(0xFFD9D2F2),
          width: 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppTheme.primaryColor,
              ),
            ),
    );
  }
}
