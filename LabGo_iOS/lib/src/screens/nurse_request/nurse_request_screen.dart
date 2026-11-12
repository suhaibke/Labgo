import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../order/location_selection_screen.dart';
import '../main/main_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Nurse Request Screen - allows patients to request a nurse visit
/// without selecting a specific lab. Admin will assign the lab later.
class NurseRequestScreen extends StatefulWidget {
  const NurseRequestScreen({super.key});

  @override
  State<NurseRequestScreen> createState() => _NurseRequestScreenState();
}

class _NurseRequestScreenState extends State<NurseRequestScreen> {
  OrderLocation? _selectedLocation;
  bool _isCreatingOrder = false;
  DateTime? _selectedDate;
  Map<String, String>? _selectedTimeSlot;
  File? _prescriptionImage;
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<void> _pickPrescriptionImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
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

  Future<void> _takePrescriptionPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
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

  void _showImageSourceDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 20),
              Text(
                l10n.selectPrescription,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: l10n.camera,
                      onTap: () {
                        Navigator.pop(context);
                        _takePrescriptionPhoto();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: l10n.gallery,
                      onTap: () {
                        Navigator.pop(context);
                        _pickPrescriptionImage();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNurseRequest() async {
    final l10n = AppLocalizations.of(context)!;

    // Validate location
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterAddress),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Validate prescription image
    if (_prescriptionImage == null) {
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
      if (_beneficiaryNameController.text.trim().isEmpty) {
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
      if (_beneficiaryPhoneController.text.trim().isEmpty) {
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

    try {
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

      final result = await OrderService.createNurseRequest(
        location: _selectedLocation!,
        prescriptionImage: _prescriptionImage,
        scheduledDate: scheduledDateStr,
        timeSlot: _selectedTimeSlot,
        beneficiary: beneficiaryData,
      );

      if (!mounted) return;

      setState(() => _isCreatingOrder = false);

      if (result['success'] == true) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _SuccessDialog(l10n: l10n),
        );

        if (mounted) {
          // Navigate back to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? l10n.orderCreationFailed),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.orderCreationFailed),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
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

  void _showTimeSlotPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectTimeSlot,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
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
                            color: isSelected ? AppTheme.primaryColor : AppTheme.gray600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            slot['display']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.gray900,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
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

  Future<void> _selectBeneficiaryBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _beneficiaryBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.requestANurse),
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
            // Header Info
            _buildHeaderInfo(l10n),

            const SizedBox(height: 24),

            // Prescription Image Upload
            _buildPrescriptionSection(l10n),

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

            // Info Box
            _buildInfoBox(l10n),

            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(l10n),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF4A900).withValues(alpha: 0.1),
            const Color(0xFFF4A900).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF4A900).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4A900).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: Color(0xFFF4A900),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.requestANurse,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeVisitSampleCollection,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection(AppLocalizations l10n) {
    final hasPrescription = _prescriptionImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasPrescription
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.gray200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasPrescription
                    ? Icons.check_rounded
                    : Icons.assignment_rounded,
                size: 18,
                color: hasPrescription ? AppTheme.success : AppTheme.gray600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.uploadPrescription,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.required,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasPrescription
                  ? AppTheme.success.withValues(alpha: 0.05)
                  : AppTheme.gray50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPrescription
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.gray200,
                width: 1.5,
              ),
            ),
            child: hasPrescription
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _prescriptionImage!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.prescriptionUploaded,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.success,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Text(
                              l10n.change,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.selectPrescription,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.uploadPrescriptionSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.gray500,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ),
      ],
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
                                  color: AppTheme.gray100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedLocation!.buildingName!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.gray700,
                                  ),
                                ),
                              ),
                            if (_selectedLocation!.floorNumber != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gray100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${l10n.floor}: ${_selectedLocation!.floorNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.gray700,
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
                                  color: AppTheme.gray100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${l10n.apartment}: ${_selectedLocation!.apartmentNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.gray700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_location_rounded,
                            size: 16,
                            color: AppTheme.primaryColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.change,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
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
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: _selectedDate != null
                            ? AppTheme.primaryColor
                            : AppTheme.gray500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : l10n.selectDate,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _selectedDate != null
                              ? AppTheme.primaryColor
                              : AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Time Picker
            Expanded(
              child: GestureDetector(
                onTap: _showTimeSlotPicker,
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
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: _selectedTimeSlot != null
                            ? AppTheme.primaryColor
                            : AppTheme.gray500,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _selectedTimeSlot != null
                              ? _selectedTimeSlot!['display']!
                              : l10n.selectTimeSlot,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _selectedTimeSlot != null
                                ? AppTheme.primaryColor
                                : AppTheme.gray500,
                          ),
                          overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = null;
                _selectedTimeSlot = null;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppTheme.gray500,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.clearDateTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray500,
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
        // Toggle for ordering for another person
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _isForOtherPerson = !_isForOtherPerson);
          },
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isForOtherPerson
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.gray200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                        ),
                      ),
                      Text(
                        l10n.orderForOtherPersonSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isForOtherPerson,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _isForOtherPerson = value);
                  },
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),

        // Beneficiary form (shown when toggle is on)
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
                // Name Field
                _buildTextField(
                  controller: _beneficiaryNameController,
                  label: l10n.beneficiaryName,
                  icon: Icons.person_outline_rounded,
                  required: true,
                ),
                const SizedBox(height: 16),
                // Phone Field
                _buildTextField(
                  controller: _beneficiaryPhoneController,
                  label: l10n.beneficiaryPhone,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  required: true,
                ),
                const SizedBox(height: 16),
                // Gender Selection
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
                const SizedBox(height: 16),
                // Birth Date
                GestureDetector(
                  onTap: _selectBeneficiaryBirthDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                          Icons.cake_outlined,
                          size: 20,
                          color: AppTheme.gray500,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _beneficiaryBirthDate != null
                                ? '${_beneficiaryBirthDate!.day}/${_beneficiaryBirthDate!.month}/${_beneficiaryBirthDate!.year}'
                                : l10n.selectBirthDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: _beneficiaryBirthDate != null
                                  ? AppTheme.gray900
                                  : AppTheme.gray500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppTheme.gray400,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Relationship Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      value: _beneficiaryRelationship,
                      hint: Row(
                        children: [
                          Icon(
                            Icons.family_restroom_rounded,
                            size: 20,
                            color: AppTheme.gray500,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.selectRelationship,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.gray400,
                      ),
                      items: _relationshipOptions.map((relationship) {
                        String displayName;
                        switch (relationship) {
                          case 'spouse':
                            displayName = l10n.spouse;
                            break;
                          case 'child':
                            displayName = l10n.child;
                            break;
                          case 'parent':
                            displayName = l10n.parent;
                            break;
                          case 'sibling':
                            displayName = l10n.sibling;
                            break;
                          case 'other':
                            displayName = l10n.other;
                            break;
                          default:
                            displayName = relationship;
                        }
                        return DropdownMenuItem(
                          value: relationship,
                          child: Row(
                            children: [
                              Icon(
                                Icons.family_restroom_rounded,
                                size: 20,
                                color: AppTheme.gray500,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.gray900,
                                ),
                              ),
                            ],
                          ),
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
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
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
          labelText: required ? '$label *' : label,
          labelStyle: const TextStyle(
            fontSize: 14,
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
            vertical: 12,
          ),
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
              color: isSelected ? AppTheme.primaryColor : AppTheme.gray500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.info.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nurseRequestInfoTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.nurseRequestInfoDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCreatingOrder ? null : _createNurseRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.gray300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isCreatingOrder
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                l10n.submitRequest,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// Image Source Option Widget
class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Success Dialog Widget
class _SuccessDialog extends StatelessWidget {
  final AppLocalizations l10n;

  const _SuccessDialog({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.nurseRequestSubmitted,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.nurseRequestSubmittedDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.done,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
