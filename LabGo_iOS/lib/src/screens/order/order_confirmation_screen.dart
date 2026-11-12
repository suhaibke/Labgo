import 'package:flutter/material.dart';
import 'dart:io';
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
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  OrderLocation? _selectedLocation;
  bool _isCreatingOrder = false;
  DateTime? _selectedDate;
  Map<String, String>? _selectedTimeSlot;

  // Beneficiary (order for other person)
  bool _isForOtherPerson = false;
  final TextEditingController _beneficiaryNameController = TextEditingController();
  final TextEditingController _beneficiaryPhoneController = TextEditingController();
  String? _beneficiaryGender;
  DateTime? _beneficiaryBirthDate;
  String? _beneficiaryRelationship;

  // Relationship options
  final List<String> _relationshipOptions = ['spouse', 'child', 'parent', 'sibling', 'other'];

  // Available time slots
  final List<Map<String, String>> _timeSlots = [
    {'start': '08:00', 'end': '10:00', 'display': '08:00 - 10:00'},
    {'start': '10:00', 'end': '12:00', 'display': '10:00 - 12:00'},
    {'start': '12:00', 'end': '14:00', 'display': '12:00 - 14:00'},
    {'start': '14:00', 'end': '16:00', 'display': '14:00 - 16:00'},
    {'start': '16:00', 'end': '18:00', 'display': '16:00 - 18:00'},
    {'start': '18:00', 'end': '20:00', 'display': '18:00 - 20:00'},
  ];

  @override
  void dispose() {
    _beneficiaryNameController.dispose();
    _beneficiaryPhoneController.dispose();
    super.dispose();
  }

  // Home collection fee removed - now showing only test prices
  // For prescription-only orders, price will be determined by admin
  int get _totalAmount => widget.prescriptionOnly ? 0 : (widget.cart?.totalPrice ?? 0);

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
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterAddress),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // For prescription-only orders, validate prescription image
    if (widget.prescriptionOnly && widget.localPrescriptionImage == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.prescriptionRequiredForOrder),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Validate beneficiary info if ordering for another person
    if (_isForOtherPerson) {
      final l10n = AppLocalizations.of(context)!;
      if (_beneficiaryNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterBeneficiaryName),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isCreatingOrder = true);

    // Format date as ISO string if selected
    final scheduledDateStr = _selectedDate != null
        ? _selectedDate!.toIso8601String()
        : null;

    // Build beneficiary data if ordering for another person
    Map<String, dynamic>? beneficiaryData;
    if (_isForOtherPerson) {
      beneficiaryData = {
        'name': _beneficiaryNameController.text,
        'phone': _beneficiaryPhoneController.text,
        if (_beneficiaryGender != null) 'gender': _beneficiaryGender,
        if (_beneficiaryBirthDate != null) 'birthDate': _beneficiaryBirthDate!.toIso8601String(),
        if (_beneficiaryRelationship != null) 'relationship': _beneficiaryRelationship,
      };
    }

    final result = await OrderService.createOrder(
      location: _selectedLocation!,
      prescriptionImage: widget.localPrescriptionImage,
      scheduledDate: scheduledDateStr,
      timeSlot: _selectedTimeSlot,
      labId: widget.labId,
      prescriptionOnly: widget.prescriptionOnly,
      beneficiary: beneficiaryData,
    );

    setState(() => _isCreatingOrder = false);

    if (!mounted) return;

    if (result['success'] == true) {
      // Clear cart only for non-prescription orders after successful order
      if (!widget.prescriptionOnly) {
        await CartService.clearCart();
      }

      // Show success screen
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.orderConfirmation),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lab Info
            _buildLabInfo(l10n),

            const SizedBox(height: 24),

            // Location Selection
            _buildLocationSection(l10n),

            const SizedBox(height: 24),

            // Date & Time Selection (Optional)
            _buildDateTimeSection(l10n),

            const SizedBox(height: 24),

            // Order for Other Person
            _buildBeneficiarySection(l10n),

            const SizedBox(height: 24),

            // Tests Summary - only show for non-prescription orders
            if (!widget.prescriptionOnly) _buildTestsSection(l10n),

            if (!widget.prescriptionOnly) const SizedBox(height: 24),

            // Pricing
            _buildPricingSection(l10n),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(l10n),
    );
  }

  Widget _buildLabInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.biotech_rounded,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 16,
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

  Widget _buildLocationSection(AppLocalizations l10n) {
    final hasLocation = _selectedLocation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasLocation
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.gray200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasLocation
                    ? Icons.check_rounded
                    : Icons.location_on_outlined,
                size: 18,
                color: hasLocation ? AppTheme.success : AppTheme.gray600,
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
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectLocation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasLocation
                  ? AppTheme.success.withValues(alpha: 0.05)
                  : AppTheme.gray50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasLocation
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.gray200,
                width: 1.5,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedLocation!.buildingName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_selectedLocation!.apartmentNumber != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedLocation!.apartmentNumber!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_location_alt_rounded,
                        size: 20,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.selectLocation,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(AppLocalizations l10n) {
    final hasDateTime = _selectedDate != null || _selectedTimeSlot != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasDateTime
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.gray200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasDateTime
                    ? Icons.schedule_rounded
                    : Icons.event_available_outlined,
                size: 18,
                color: hasDateTime ? AppTheme.primaryColor : AppTheme.gray600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.scheduleVisit,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const Spacer(),
            Text(
              l10n.optional,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Date Picker
            Expanded(
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedDate != null
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : AppTheme.gray50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedDate != null
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.gray200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: _selectedDate != null
                            ? AppTheme.primaryColor
                            : AppTheme.gray600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedDate != null
                            ? _formatDate(_selectedDate!)
                            : l10n.selectDate,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedDate != null
                              ? AppTheme.gray900
                              : AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Time Slot Picker
            Expanded(
              child: GestureDetector(
                onTap: _selectTimeSlot,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedTimeSlot != null
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : AppTheme.gray50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedTimeSlot != null
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.gray200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: _selectedTimeSlot != null
                            ? AppTheme.primaryColor
                            : AppTheme.gray600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedTimeSlot != null
                            ? _selectedTimeSlot!['display']!
                            : l10n.selectTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedTimeSlot != null
                              ? AppTheme.gray900
                              : AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedDate != null || _selectedTimeSlot != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = null;
                _selectedTimeSlot = null;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: 16,
                  color: AppTheme.gray600,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.clearDateTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBeneficiarySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        GestureDetector(
          onTap: () => setState(() => _isForOtherPerson = !_isForOtherPerson),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isForOtherPerson
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : AppTheme.gray50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isForOtherPerson
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.gray200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
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
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.orderForOtherPerson,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.orderForOtherPersonSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 22,
                  color: _isForOtherPerson
                      ? AppTheme.primaryColor
                      : AppTheme.gray500,
                ),
              ],
            ),
          ),
        ),

        // Beneficiary form (shown when checkbox is checked)
        if (_isForOtherPerson) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.gray200,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.beneficiaryInfo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                _buildTextField(
                  controller: _beneficiaryNameController,
                  label: l10n.beneficiaryName,
                  hint: l10n.enterYourFullName,
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),

                // Phone field
                _buildTextField(
                  controller: _beneficiaryPhoneController,
                  label: l10n.beneficiaryPhone,
                  hint: l10n.enterYourPhoneNumber,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // Gender selection
                Row(
                  children: [
                    Expanded(
                      child: _buildGenderOption(
                        label: l10n.male,
                        value: 'male',
                        icon: Icons.male_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGenderOption(
                        label: l10n.female,
                        value: 'female',
                        icon: Icons.female_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Birth date picker
                GestureDetector(
                  onTap: _selectBeneficiaryBirthDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.gray200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
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
                const SizedBox(height: 12),

                // Relationship dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.gray200,
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _beneficiaryRelationship,
                      hint: Row(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 20,
                            color: AppTheme.gray500,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.relationship,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
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
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gray200,
          width: 1,
        ),
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
          prefixIcon: Icon(
            icon,
            size: 20,
            color: AppTheme.gray500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.gray200,
            width: isSelected ? 2 : 1,
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
    final firstDate = DateTime(1900);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _beneficiaryBirthDate ?? DateTime(now.year - 30),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
                      decoration: BoxDecoration(
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
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final slot = _timeSlots[index];
                  final isSelected = _selectedTimeSlot?['start'] == slot['start'];
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
                            Icons.access_time_rounded,
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
                                Icons.check_rounded,
                                size: 14,
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
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildTestsSection(AppLocalizations l10n) {
    if (widget.cart == null || widget.cart!.tests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
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
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.gray50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.gray200,
              width: 1,
            ),
          ),
          child: Column(
            children: List.generate(
              widget.cart!.tests.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: index == widget.cart!.tests.length - 1 ? 14 : 10,
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
                        widget.cart!.tests[index].testName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatPrice(widget.cart!.tests[index].price)} IQD',
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
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection(AppLocalizations l10n) {
    // For prescription-only orders, show message that admin will determine price
    if (widget.prescriptionOnly) {
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.info,
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
          _buildPricingRow(l10n.subtotal, _formatPrice(widget.cart?.totalPrice ?? 0)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.gray300),
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

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          height: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isCreatingOrder ? null : _createOrder,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.check_rounded,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Animation
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
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
                      color: AppTheme.gray50,
                      borderRadius: BorderRadius.circular(16),
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

                // View Orders Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Navigate to MainScreen with Tests tab selected (index 2)
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(initialIndex: 2),
                          ),
                          (route) => false,
                        );
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
