import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../screens/order/location_selection_screen.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

const Color _kPinkAccent = Color(0xFFD8509B);
const Color _kLavenderBg = Color(0xFFF6F4FD);

/// Show the therapeutic prescription sheet. Call after guest check.
Future<void> showTherapeuticPrescriptionSheet(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: false,
    builder: (context) => const TherapeuticPrescriptionSheet(),
  );

  if (submitted == true && context.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.medicineRequestSubmitted),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class TherapeuticPrescriptionSheet extends StatefulWidget {
  const TherapeuticPrescriptionSheet({super.key});

  @override
  State<TherapeuticPrescriptionSheet> createState() =>
      _TherapeuticPrescriptionSheetState();
}

class _TherapeuticPrescriptionSheetState
    extends State<TherapeuticPrescriptionSheet> {
  OrderLocation? _selectedLocation;
  File? _prescriptionImage;
  bool _isSubmitting = false;

  final ImagePicker _imagePicker = ImagePicker();

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

  @override
  void dispose() {
    _beneficiaryNameController.dispose();
    _beneficiaryPhoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _prescriptionImage = File(image.path));
      }
    } catch (_) {
      // Silently ignore picker errors
    }
  }

  void _showImageSourceSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.selectPrescription,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: TablerIcons.camera,
                      label: l10n.camera,
                      accent: _kPinkAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceOption(
                      icon: TablerIcons.photo,
                      label: l10n.gallery,
                      accent: _kPinkAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_prescriptionImage == null) {
      _showError(l10n.prescriptionRequiredForOrder);
      return;
    }
    if (_selectedLocation == null) {
      _showError(l10n.pleaseEnterAddress);
      return;
    }
    if (_isForOtherPerson) {
      if (_beneficiaryNameController.text.trim().isEmpty) {
        _showError(l10n.pleaseEnterBeneficiaryName);
        return;
      }
      if (_beneficiaryPhoneController.text.trim().isEmpty) {
        _showError(l10n.pleaseEnterBeneficiaryPhone);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
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

      // Medicine delivery order: the admin prices the prescription and the
      // patient approves it; no sample collection or visit scheduling.
      final result = await OrderService.createNurseRequest(
        location: _selectedLocation!,
        prescriptionImage: _prescriptionImage,
        beneficiary: beneficiaryData,
        medicine: true,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showError(result['message'] as String? ?? l10n.orderCreationFailed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(l10n.orderCreationFailed);
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.92;
    final title = l10n.therapeuticPrescription;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: _kLavenderBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kPinkAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      TablerIcons.pill,
                      color: _kPinkAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gray900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.gray700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    _buildPrescriptionSection(l10n),
                    const SizedBox(height: 12),
                    _buildLocationSection(l10n),
                    const SizedBox(height: 12),
                    _buildBeneficiarySection(l10n),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildStickyButton(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyButton(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPinkAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kPinkAccent.withValues(alpha: 0.5),
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
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l10n.confirmOrder,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? trailing,
    Color? iconColor,
    Color? iconBg,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg ?? AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor ?? AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray500,
            ),
          ),
      ],
    );
  }

  Widget _buildPrescriptionSection(AppLocalizations l10n) {
    final hasImage = _prescriptionImage != null;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: hasImage ? TablerIcons.check : TablerIcons.pill,
            title: l10n.uploadPrescription,
            iconColor: hasImage ? AppTheme.success : _kPinkAccent,
            iconBg: hasImage
                ? AppTheme.success.withValues(alpha: 0.12)
                : _kPinkAccent.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          Text(
            hasImage
                ? l10n.prescriptionUploaded
                : l10n.prescriptionRequired,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasImage ? AppTheme.success : AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 14),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _prescriptionImage!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (hasImage) ...[
                GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _prescriptionImage = null),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      TablerIcons.trash,
                      size: 18,
                      color: AppTheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _showImageSourceSheet,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kPinkAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _kPinkAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasImage ? TablerIcons.refresh : TablerIcons.upload,
                          size: 18,
                          color: _kPinkAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.selectPrescription,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kPinkAccent,
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

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: hasLocation ? TablerIcons.check : TablerIcons.truck_delivery,
            title: l10n.deliveryLocation,
            iconColor: hasLocation ? AppTheme.success : AppTheme.primaryColor,
            iconBg: hasLocation
                ? AppTheme.success.withValues(alpha: 0.12)
                : AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _isSubmitting ? null : _selectLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasLocation
                    ? AppTheme.success.withValues(alpha: 0.06)
                    : _kLavenderBg,
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
                        if (_selectedLocation!.phone != null &&
                            _selectedLocation!.phone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _selectedLocation!.phone!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.gray700,
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
                            color: AppTheme.primaryColor.withValues(alpha: 0.9),
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

  Widget _buildBeneficiarySection(AppLocalizations l10n) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _isSubmitting
                ? null
                : () =>
                    setState(() => _isForOtherPerson = !_isForOtherPerson),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor.withValues(alpha: 0.12)
                        : AppTheme.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    TablerIcons.user_plus,
                    size: 18,
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor
                        : AppTheme.gray600,
                  ),
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
                          fontWeight: FontWeight.w700,
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
            const SizedBox(height: 16),
            Text(
              l10n.beneficiaryInfo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _beneficiaryNameController,
              hint: l10n.enterYourFullName,
              icon: TablerIcons.user,
            ),
            const SizedBox(height: 10),
            _textField(
              controller: _beneficiaryPhoneController,
              hint: l10n.enterYourPhoneNumber,
              icon: TablerIcons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _genderOption(
                    label: l10n.male,
                    value: 'male',
                    icon: Icons.male_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _genderOption(
                    label: l10n.female,
                    value: 'female',
                    icon: Icons.female_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isSubmitting ? null : _selectBeneficiaryBirthDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _kLavenderBg,
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
                          ? _formatDate(_beneficiaryBirthDate!)
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _kLavenderBg,
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
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
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

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kLavenderBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        enabled: !_isSubmitting,
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.gray900,
        ),
      ),
    );
  }

  Widget _genderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _beneficiaryGender == value;
    return GestureDetector(
      onTap: _isSubmitting
          ? null
          : () => setState(() => _beneficiaryGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : _kLavenderBg,
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
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: accent),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
