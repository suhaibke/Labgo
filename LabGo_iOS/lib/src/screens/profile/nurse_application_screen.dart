import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_service.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';

class NurseApplicationScreen extends StatefulWidget {
  const NurseApplicationScreen({super.key});

  @override
  State<NurseApplicationScreen> createState() => _NurseApplicationScreenState();
}

class _NurseApplicationScreenState extends State<NurseApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _zoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  File? _nationalCardImageFront;
  File? _nationalCardImageBack;
  File? _certificateImage;
  bool _ownsCar = false;
  bool _isEmployed = false;
  bool _isSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService().getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
      });
    }
  }

  /// Pick image directly from gallery (bypasses iOS 18 modal bottom sheet crash)
  Future<void> _pickNationalCardImageFront() async {
    debugPrint('🟢 [ImagePicker] _pickNationalCardImageFront: START - Direct gallery pick');
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      debugPrint('🟢 [ImagePicker] pickImage returned: ${pickedFile?.path}');
      if (pickedFile != null && mounted) {
        setState(() {
          _nationalCardImageFront = File(pickedFile.path);
        });
        debugPrint('🟢 [ImagePicker] State set successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ImagePicker] ERROR: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    debugPrint('🟢 [ImagePicker] _pickNationalCardImageFront: END');
  }

  /// Pick image directly from gallery (bypasses iOS 18 modal bottom sheet crash)
  Future<void> _pickNationalCardImageBack() async {
    debugPrint('🟡 [ImagePicker] _pickNationalCardImageBack: START - Direct gallery pick');
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      debugPrint('🟡 [ImagePicker] pickImage returned: ${pickedFile?.path}');
      if (pickedFile != null && mounted) {
        setState(() {
          _nationalCardImageBack = File(pickedFile.path);
        });
        debugPrint('🟡 [ImagePicker] State set successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ImagePicker] ERROR: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    debugPrint('🟡 [ImagePicker] _pickNationalCardImageBack: END');
  }

  /// Pick image directly from gallery (bypasses iOS 18 modal bottom sheet crash)
  Future<void> _pickCertificateImage() async {
    debugPrint('🟣 [ImagePicker] _pickCertificateImage: START - Direct gallery pick');
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      debugPrint('🟣 [ImagePicker] pickImage returned: ${pickedFile?.path}');
      if (pickedFile != null && mounted) {
        setState(() {
          _certificateImage = File(pickedFile.path);
        });
        debugPrint('🟣 [ImagePicker] State set successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ImagePicker] ERROR: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    debugPrint('🟣 [ImagePicker] _pickCertificateImage: END');
  }


  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (_nationalCardImageFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseUploadNationalCard),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_nationalCardImageBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseUploadNationalCard),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_certificateImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseUploadCertificate),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await NurseService.submitApplication(
      nationalCardImageFront: _nationalCardImageFront!,
      nationalCardImageBack: _nationalCardImageBack!,
      certificateImage: _certificateImage!,
      city: _cityController.text.trim(),
      zone: _zoneController.text.trim(),
      address: _addressController.text.trim(),
      ownsCar: _ownsCar,
      isEmployed: _isEmployed,
      additionalInfo: _additionalInfoController.text.trim(),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? l10n.failedToSubmit),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
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
                Icons.check_rounded,
                color: AppTheme.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.applicationSubmitted,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.applicationUnderReview,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Return true to signal success
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.done),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _zoneController.dispose();
    _addressController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.gray900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.applyForNurse,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Personal Info Section (Pre-filled)
            _SectionHeader(title: l10n.personalInformation),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _InfoRow(label: l10n.fullName, value: _userData?['name'] ?? 'Loading...'),
                Divider(height: 1, color: AppTheme.gray200),
                _InfoRow(label: l10n.emailAddress, value: _userData?['email'] ?? 'Loading...'),
                Divider(height: 1, color: AppTheme.gray200),
                _InfoRow(label: l10n.phoneNumber, value: _userData?['phone'] ?? 'Loading...'),
              ],
            ),

            const SizedBox(height: 32),

            // Documents Section
            _SectionHeader(title: l10n.documents),
            const SizedBox(height: 12),
            _DocumentsGroup(
              children: [
                _DocumentUploadTile(
                  title: l10n.nationalCardFront,
                  subtitle: l10n.nationalCardFrontSubtitle,
                  imageFile: _nationalCardImageFront,
                  onTap: _pickNationalCardImageFront,
                ),
                Divider(height: 1, color: AppTheme.gray200),
                _DocumentUploadTile(
                  title: l10n.nationalCardBack,
                  subtitle: l10n.nationalCardBackSubtitle,
                  imageFile: _nationalCardImageBack,
                  onTap: _pickNationalCardImageBack,
                ),
                Divider(height: 1, color: AppTheme.gray200),
                _DocumentUploadTile(
                  title: l10n.nursingCertificate,
                  subtitle: l10n.nursingCertificateSubtitle,
                  imageFile: _certificateImage,
                  onTap: _pickCertificateImage,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Location Section
            _SectionHeader(title: l10n.location),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _InputRow(
                  label: l10n.city,
                  controller: _cityController,
                  hint: l10n.enterCity,
                  required: true,
                ),
                Divider(height: 1, color: AppTheme.gray200),
                _InputRow(
                  label: l10n.zone,
                  controller: _zoneController,
                  hint: l10n.enterZone,
                  required: true,
                ),
                Divider(height: 1, color: AppTheme.gray200),
                _InputRow(
                  label: l10n.address,
                  controller: _addressController,
                  hint: l10n.enterAddress,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Questionnaire Section
            _SectionHeader(title: l10n.questionnaire),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _BooleanQuestionTile(
                  title: l10n.ownsCarQuestion,
                  value: _ownsCar,
                  onChanged: (value) => setState(() => _ownsCar = value),
                ),
                Divider(height: 1, color: AppTheme.gray200),
                _BooleanQuestionTile(
                  title: l10n.isEmployedQuestion,
                  value: _isEmployed,
                  onChanged: (value) => setState(() => _isEmployed = value),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Additional Info
            _SectionHeader(title: l10n.additionalInfo),
            const SizedBox(height: 12),
            _TextAreaInput(
              controller: _additionalInfoController,
              hint: l10n.tellUsAboutYourself,
              maxLines: 4,
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.gray300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        l10n.submitApplication,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// Info Group Container
class _InfoGroup extends StatelessWidget {
  final List<Widget> children;

  const _InfoGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

// Documents Group Container
class _DocumentsGroup extends StatelessWidget {
  final List<Widget> children;

  const _DocumentsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

// Info Row (Pre-filled data)
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray400,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Input Row (Editable)
class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;

  const _InputRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (required ? ' *' : ''),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: required ? AppTheme.error : AppTheme.gray400,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.gray400,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

// Document Upload Tile
class _DocumentUploadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? imageFile;
  final VoidCallback onTap;

  const _DocumentUploadTile({
    required this.title,
    required this.subtitle,
    this.imageFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon/Preview
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: imageFile != null ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.gray100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: AppTheme.gray400,
                    ),
            ),

            const SizedBox(width: 14),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),

            // Upload Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Boolean Question Tile
class _BooleanQuestionTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanQuestionTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // iOS-style toggle switches
          Row(
            children: [
              GestureDetector(
                onTap: () => onChanged(false),
                child: _ToggleButton(
                  label: l10n.no,
                  isSelected: !value,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onChanged(true),
                child: _ToggleButton(
                  label: l10n.yes,
                  isSelected: value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Toggle Button
class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.gray200,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.gray600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// Text Area Input
class _TextAreaInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _TextAreaInput({
    required this.controller,
    required this.hint,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.gray400,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
