import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../../services/cart_service.dart';
import 'location_selection_screen.dart';
import '../main/main_screen.dart';
import '../../../l10n/app_localizations.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final Cart? cart;
  final File? localPrescriptionImage;
  final bool prescriptionOnly;

  const OrderConfirmationScreen({
    super.key,
    required this.labId,
    required this.labName,
    this.cart,
    this.localPrescriptionImage,
    this.prescriptionOnly = false,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Cart? _cart;
  bool _isLoadingCart = false;
  bool _isCreatingOrder = false;

  OrderLocation? _selectedLocation;
  DateTime? _selectedDate;
  Map<String, String>? _selectedTimeSlot;

  File? _prescriptionImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Beneficiary (order for other person)
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

  final List<Map<String, String>> _timeSlots = [
    {'start': '08:00', 'end': '10:00', 'display': '08:00 - 10:00'},
    {'start': '10:00', 'end': '12:00', 'display': '10:00 - 12:00'},
    {'start': '12:00', 'end': '14:00', 'display': '12:00 - 14:00'},
    {'start': '14:00', 'end': '16:00', 'display': '14:00 - 16:00'},
    {'start': '16:00', 'end': '18:00', 'display': '16:00 - 18:00'},
    {'start': '18:00', 'end': '20:00', 'display': '18:00 - 20:00'},
  ];

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _prescriptionImage = widget.localPrescriptionImage;
    if (_cart == null && !widget.prescriptionOnly) {
      _loadCart();
    }
  }

  @override
  void dispose() {
    _beneficiaryNameController.dispose();
    _beneficiaryPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoadingCart = true);
    final result = await CartService.getCart();
    if (!mounted) return;
    setState(() {
      _cart = result['success'] == true ? result['cart'] as Cart? : null;
      _isLoadingCart = false;
    });
  }

  Future<void> _removeTest(String testId) async {
    final result = await CartService.removeFromCart(testId: testId);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _cart = result['cart'] as Cart?);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Test removed'),
        backgroundColor:
            result['success'] == true ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickPrescriptionImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _prescriptionImage = File(image.path));
      }
    } catch (_) {
      // Ignore picker errors
    }
  }

  Future<void> _removePrescription() async {
    await CartService.removePrescription();
    if (!mounted) return;
    setState(() => _prescriptionImage = null);
  }

  File? get _effectivePrescription =>
      _prescriptionImage ?? widget.localPrescriptionImage;

  int get _totalAmount =>
      widget.prescriptionOnly ? 0 : (_cart?.totalPrice ?? 0);

  String _formatPrice(int price) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
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

  Future<void> _createOrder() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterAddress),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSelectDate),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (widget.prescriptionOnly && _effectivePrescription == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.prescriptionRequiredForOrder),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!widget.prescriptionOnly && (_cart == null || _cart!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cartEmpty),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_isForOtherPerson) {
      if (_beneficiaryNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterBeneficiaryName),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      if (_beneficiaryPhoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterBeneficiaryPhone),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    setState(() => _isCreatingOrder = true);

    final scheduledDateStr = _selectedDate?.toIso8601String();

    Map<String, dynamic>? beneficiaryData;
    if (_isForOtherPerson) {
      beneficiaryData = {
        'name': _beneficiaryNameController.text,
        'phone': _beneficiaryPhoneController.text,
        if (_beneficiaryGender != null) 'gender': _beneficiaryGender,
        if (_beneficiaryBirthDate != null)
          'birthDate': _beneficiaryBirthDate!.toIso8601String(),
        if (_beneficiaryRelationship != null)
          'relationship': _beneficiaryRelationship,
      };
    }

    final result = await OrderService.createOrder(
      location: _selectedLocation!,
      prescriptionImage: _effectivePrescription,
      scheduledDate: scheduledDateStr,
      timeSlot: _selectedTimeSlot,
      labId: widget.labId,
      prescriptionOnly: widget.prescriptionOnly,
      beneficiary: beneficiaryData,
    );

    if (!mounted) return;
    setState(() => _isCreatingOrder = false);

    if (result['success'] == true) {
      if (!widget.prescriptionOnly) {
        await CartService.clearCart();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => _OrderSuccessScreen(
            order: result['order'] as Order?,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Failed to create order',
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        title: Text(l10n.orderConfirmation),
        elevation: 0,
        backgroundColor: AppTheme.backgroundLavender,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingCart
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : (!widget.prescriptionOnly && (_cart == null || _cart!.isEmpty))
              ? _buildEmptyCart(l10n)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabInfo(l10n),
                      const SizedBox(height: 12),
                      if (!widget.prescriptionOnly) ...[
                        _buildTestsSection(l10n),
                        const SizedBox(height: 12),
                        _buildPrescriptionSection(l10n),
                        const SizedBox(height: 12),
                      ],
                      if (widget.prescriptionOnly) ...[
                        _buildPrescriptionSection(l10n, required: true),
                        const SizedBox(height: 12),
                      ],
                      _buildLocationSection(l10n),
                      const SizedBox(height: 12),
                      _buildDateTimeSection(l10n),
                      const SizedBox(height: 12),
                      _buildBeneficiarySection(l10n),
                      const SizedBox(height: 12),
                      _buildPricingSection(l10n),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      bottomNavigationBar: (!_isLoadingCart &&
              (widget.prescriptionOnly || (_cart != null && !_cart!.isEmpty)))
          ? _buildBottomBar(l10n)
          : null,
    );
  }

  Widget _buildEmptyCart(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                TablerIcons.test_pipe,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.cartEmpty,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cartEmptySubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? trailing,
    Color? iconColor,
    Color? iconBg,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.gray900,
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

  Widget _buildLabInfo(AppLocalizations l10n) {
    return _buildSectionCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              TablerIcons.flask,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.laboratories,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.labName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsSection(AppLocalizations l10n) {
    final tests = _cart?.tests ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: TablerIcons.test_pipe,
          title: l10n.scheduledTests,
          trailing: '${tests.length}',
        ),
        const SizedBox(height: 8),
        ...tests.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTestCard(item, l10n),
            )),
      ],
    );
  }

  Widget _buildTestCard(CartItem item, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _removeTest(item.testId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(TablerIcons.trash, size: 14, color: AppTheme.error),
                  const SizedBox(width: 4),
                  Text(
                    l10n.remove,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.testName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                  ),
                ),
                if (item.category != null && item.category!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.category!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${_formatPrice(item.price)} IQD',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              TablerIcons.test_pipe,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection(
    AppLocalizations l10n, {
    bool required = false,
  }) {
    final hasImage = _effectivePrescription != null ||
        (_cart?.hasPrescription ?? false);

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: hasImage ? TablerIcons.check : TablerIcons.upload,
            title: l10n.uploadPrescription,
            trailing: required ? null : l10n.optional,
            iconColor: hasImage ? AppTheme.success : AppTheme.primaryColor,
            iconBg: hasImage
                ? AppTheme.success.withValues(alpha: 0.12)
                : AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          Text(
            hasImage
                ? l10n.prescriptionUploaded
                : (required
                    ? l10n.prescriptionRequired
                    : l10n.prescriptionOptional),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasImage ? AppTheme.success : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 8),
          if (_effectivePrescription != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _effectivePrescription!,
                height: 96,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (!hasImage)
                Expanded(
                  child: GestureDetector(
                    onTap: _pickPrescriptionImage,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            TablerIcons.upload,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.selectPrescription,
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
                )
              else
                Expanded(
                  child: GestureDetector(
                    onTap: _removePrescription,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            TablerIcons.trash,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.remove,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(AppLocalizations l10n) {
    final hasLocation = _selectedLocation != null;

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: hasLocation ? TablerIcons.check : TablerIcons.map_pin,
            title: l10n.sampleCollectionLocation,
            iconColor: hasLocation ? AppTheme.success : AppTheme.primaryColor,
            iconBg: hasLocation
                ? AppTheme.success.withValues(alpha: 0.12)
                : AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: hasLocation
                    ? AppTheme.success.withValues(alpha: 0.06)
                    : AppTheme.backgroundLavender,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasLocation
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : AppTheme.primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: hasLocation
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLocation!.address,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.gray900,
                          ),
                        ),
                        if (_selectedLocation!.landmark != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _selectedLocation!.landmark!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.gray600,
                            ),
                          ),
                        ],
                        if (_selectedLocation!.buildingName != null ||
                            _selectedLocation!.apartmentNumber != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_selectedLocation!.buildingName != null)
                                _chip(_selectedLocation!.buildingName!),
                              if (_selectedLocation!.apartmentNumber != null)
                                _chip(_selectedLocation!.apartmentNumber!),
                            ],
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          TablerIcons.map_pin,
                          size: 18,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.selectLocation,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.9),
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

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(AppLocalizations l10n) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: TablerIcons.calendar,
            title: l10n.scheduleVisit,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: _pickerTile(
                    icon: TablerIcons.calendar,
                    value: _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : l10n.selectDate,
                    label: l10n.date,
                    selected: _selectedDate != null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _selectTimeSlot,
                  child: _pickerTile(
                    icon: TablerIcons.clock,
                    value: _selectedTimeSlot != null
                        ? _selectedTimeSlot!['display']!
                        : l10n.selectTime,
                    label: l10n.time,
                    selected: _selectedTimeSlot != null,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedDate != null || _selectedTimeSlot != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = null;
                    _selectedTimeSlot = null;
                  });
                },
                child: Text(
                  l10n.clearDateTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String value,
    required String label,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : AppTheme.backgroundLavender,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? AppTheme.primaryColor : AppTheme.gray600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.gray500),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.gray900 : AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiarySection(AppLocalizations l10n) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _isForOtherPerson = !_isForOtherPerson),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor.withValues(alpha: 0.12)
                        : AppTheme.gray100,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    TablerIcons.user_plus,
                    size: 16,
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor
                        : AppTheme.gray600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.orderForOtherPerson,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l10n.orderForOtherPersonSubtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isForOtherPerson
                          ? AppTheme.primaryColor
                          : AppTheme.gray400,
                      width: 2,
                    ),
                  ),
                  child: _isForOtherPerson
                      ? const Icon(
                          TablerIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
          if (_isForOtherPerson) ...[
            const SizedBox(height: 10),
            Text(
              l10n.beneficiaryInfo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _beneficiaryNameController,
              hint: l10n.enterYourFullName,
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _beneficiaryPhoneController,
              hint: l10n.enterYourPhoneNumber,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildGenderOption(
                    label: l10n.male,
                    value: 'male',
                    icon: Icons.male_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildGenderOption(
                    label: l10n.female,
                    value: 'female',
                    icon: Icons.female_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectBeneficiaryBirthDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      TablerIcons.calendar,
                      size: 18,
                      color: _beneficiaryBirthDate != null
                          ? AppTheme.primaryColor
                          : AppTheme.gray500,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _beneficiaryBirthDate != null
                          ? _formatBirthDate(_beneficiaryBirthDate!)
                          : l10n.selectDateOfBirth,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _beneficiaryBirthDate != null
                            ? AppTheme.gray900
                            : AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.gray500,
                  ),
                  items: _relationshipOptions.map((rel) {
                    return DropdownMenuItem<String>(
                      value: rel,
                      child: Text(_getRelationshipLabel(rel, l10n)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _beneficiaryRelationship = value);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.gray500,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.gray500),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.gray900,
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _beneficiaryGender == value;
    return GestureDetector(
      onTap: () => setState(() => _beneficiaryGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.backgroundLavender,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: isSelected ? 1.5 : 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryColor : AppTheme.gray600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : AppTheme.gray700,
              ),
            ),
          ],
        ),
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

  Future<void> _selectBeneficiaryBirthDate() async {
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
    if (picked != null) {
      setState(() => _beneficiaryBirthDate = picked);
    }
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTimeSlot() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.selectTimeSlot,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.gray100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.gray700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                itemCount: _timeSlots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final slot = _timeSlots[index];
                  final isSelected =
                      _selectedTimeSlot?['start'] == slot['start'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedTimeSlot = slot);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.gray200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.clock,
                            size: 20,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.gray600,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            slot['display']!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.gray900,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                TablerIcons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildPricingSection(AppLocalizations l10n) {
    if (widget.prescriptionOnly) {
      return _buildSectionCard(
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.info,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
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

    return _buildSectionCard(
      child: Column(
        children: [
          _buildPricingRow(
            l10n.subtotal,
            _formatPrice(_cart?.totalPrice ?? 0),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppTheme.gray200),
          ),
          _buildPricingRow(
            l10n.totalAmount,
            _formatPrice(_totalAmount),
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
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.gray900 : AppTheme.gray600,
          ),
        ),
        Text(
          '$value IQD',
          style: TextStyle(
            fontSize: isTotal ? 17 : 14,
            fontWeight: FontWeight.w800,
            color: isTotal ? AppTheme.primaryColor : AppTheme.gray900,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isCreatingOrder ? null : _createOrder,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isCreatingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.confirmOrder,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              TablerIcons.check,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSuccessScreen extends StatelessWidget {
  final Order? order;

  const _OrderSuccessScreen({this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    TablerIcons.check,
                    size: 50,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.orderCreated,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gray900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.orderPendingMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (order?.qrCode != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.qrCode,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order!.qrCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) =>
                                const MainScreen(initialIndex: 2),
                          ),
                          (route) => false,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            l10n.viewOrders,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
