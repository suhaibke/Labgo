import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_service.dart';
import '../../services/auth_service.dart';
import '../order/location_selection_screen.dart' show FullScreenMapPage;
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

  LatLng? _selectedLocation;
  bool _isGettingLocation = false;
  bool _locationMissing = false;

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
        maxWidth: 1600,
        imageQuality: 75,
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
        maxWidth: 1600,
        imageQuality: 75,
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
        maxWidth: 1600,
        imageQuality: 75,
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


  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _locationMissing = false;
        });
        await _reverseGeocode(_selectedLocation!);
      }
    } catch (_) {
      // Silently fail - user can still set the location manually on the map
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _openMapPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMapPage(
          initialLocation: _selectedLocation ?? const LatLng(33.3152, 44.3661),
          onLocationSelected: (location) {
            setState(() {
              _selectedLocation = location;
              _locationMissing = false;
            });
            _reverseGeocode(location);
          },
        ),
      ),
    );
  }

  /// Fills the city/zone/address fields automatically from the picked map point.
  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=14&addressdetails=1',
        ),
        headers: {'User-Agent': 'LabGo App', 'Accept-Language': 'ar'},
      );

      if (response.statusCode != 200 || !mounted) return;

      final data = jsonDecode(response.body);
      final address = data['address'] as Map<String, dynamic>? ?? {};

      final city = address['state'] ?? address['county'] ?? address['city'];
      final zone = address['suburb'] ?? address['neighbourhood'] ?? address['town'];

      setState(() {
        if (city != null) _cityController.text = city.toString();
        if (zone != null) _zoneController.text = zone.toString();
        if (data['display_name'] != null) _addressController.text = data['display_name'].toString();
      });
    } catch (_) {
      // Silently fail - user can still fill these fields manually
    }
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

    if (_selectedLocation == null) {
      setState(() => _locationMissing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSelectMapLocation),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final existingEmail = _userData?['email']?.toString().trim() ?? '';
    if (existingEmail.isEmpty) {
      final phone = (_userData?['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      final placeholder =
          '${phone.isNotEmpty ? phone : DateTime.now().millisecondsSinceEpoch}@phone.labgo-iq.com';
      await AuthService.updateProfile(email: placeholder);
    }

    final result = await NurseService.submitApplication(
      nationalCardImageFront: _nationalCardImageFront!,
      nationalCardImageBack: _nationalCardImageBack!,
      certificateImage: _certificateImage!,
      city: _cityController.text.trim(),
      zone: _zoneController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
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
          content: Text(_friendlySubmitError(result['message']?.toString(), l10n)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _friendlySubmitError(String? raw, AppLocalizations l10n) {
    final message = (raw ?? '').trim();
    final lower = message.toLowerCase();
    if (lower.contains('complete your profile')) {
      return 'أكمل بيانات حسابك أولاً (الهاتف، الجنس، وتاريخ الميلاد)';
    }
    if (lower.contains('pending application')) {
      return 'لديك طلب قيد المراجعة بالفعل';
    }
    if (lower.contains('timeout') || lower.contains('connection')) {
      return 'تعذر الاتصال. حاول مرة أخرى.';
    }
    if (lower.contains('server error')) {
      return 'تعذر إرسال الطلب حالياً. حاول مرة أخرى.';
    }
    if (message.isEmpty) return l10n.failedToSubmit;
    return message;
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
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  _HeaderButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.applyForNurse,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B3CC4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    _SectionHeader(title: l10n.personalInformation),
                    _Card(
                      child: Column(
                        children: [
                          _InfoRow(label: l10n.fullName, value: _userData?['name'] ?? '—'),
                          const _RowDivider(),
                          _InfoRow(
                            label: l10n.emailAddress,
                            value: (_userData?['email'] as String?)?.trim().isNotEmpty == true
                                ? _userData!['email'].toString()
                                : '—',
                          ),
                          const _RowDivider(),
                          _InfoRow(label: l10n.phoneNumber, value: _userData?['phone'] ?? '—'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(title: l10n.documents),
                    _Card(
                      child: Column(
                        children: [
                          _DocumentUploadTile(
                            title: l10n.nationalCardFront,
                            subtitle: l10n.nationalCardFrontSubtitle,
                            imageFile: _nationalCardImageFront,
                            onTap: _pickNationalCardImageFront,
                          ),
                          const _RowDivider(),
                          _DocumentUploadTile(
                            title: l10n.nationalCardBack,
                            subtitle: l10n.nationalCardBackSubtitle,
                            imageFile: _nationalCardImageBack,
                            onTap: _pickNationalCardImageBack,
                          ),
                          const _RowDivider(),
                          _DocumentUploadTile(
                            title: l10n.nursingCertificate,
                            subtitle: l10n.nursingCertificateSubtitle,
                            imageFile: _certificateImage,
                            onTap: _pickCertificateImage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(title: '${l10n.location} *'),
                    _Card(
                      child: Column(
                        children: [
                          _InputRow(
                            label: l10n.city,
                            controller: _cityController,
                            hint: l10n.enterCity,
                            required: true,
                          ),
                          const _RowDivider(),
                          _InputRow(
                            label: l10n.zone,
                            controller: _zoneController,
                            hint: l10n.enterZone,
                            required: true,
                          ),
                          const _RowDivider(),
                          _InputRow(
                            label: l10n.address,
                            controller: _addressController,
                            hint: l10n.enterAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Card(
                      borderColor: _locationMissing && _selectedLocation == null
                          ? AppTheme.error
                          : null,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedLocation != null
                                    ? Icons.check_circle_rounded
                                    : Icons.location_on_outlined,
                                size: 16,
                                color: _selectedLocation != null
                                    ? AppTheme.success
                                    : (_locationMissing ? AppTheme.error : AppTheme.gray500),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedLocation != null
                                      ? '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}'
                                      : l10n.pleaseSelectMapLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedLocation != null
                                        ? AppTheme.gray900
                                        : (_locationMissing ? AppTheme.error : AppTheme.gray500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 42,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openMapPicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: Text(
                                l10n.setOnMap,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LocationChip(
                            icon: Icons.my_location_rounded,
                            label: l10n.useCurrentLocation,
                            loading: _isGettingLocation,
                            onTap: _isGettingLocation ? null : _useCurrentLocation,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(title: l10n.questionnaire),
                    _Card(
                      child: Column(
                        children: [
                          _BooleanQuestionTile(
                            title: l10n.ownsCarQuestion,
                            value: _ownsCar,
                            onChanged: (value) => setState(() => _ownsCar = value),
                          ),
                          const _RowDivider(),
                          _BooleanQuestionTile(
                            title: l10n.isEmployedQuestion,
                            value: _isEmployed,
                            onChanged: (value) => setState(() => _isEmployed = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(title: l10n.additionalInfo),
                    _TextAreaInput(
                      controller: _additionalInfoController,
                      hint: l10n.tellUsAboutYourself,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.gray300,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(54),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.submitApplication,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE6E2F0)),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 2, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5B3CC4),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const _Card({required this.child, this.padding, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? const Color(0xFFE8E0F8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0ECF8));
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9A93B0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1433),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label + (required ? ' *' : ''),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: required ? AppTheme.primaryColor : const Color(0xFF9A93B0),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFB8B2C8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F5FC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              validator: required
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      return null;
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: imageFile != null
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : const Color(0xFFF3EDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(imageFile!, fit: BoxFit.cover),
                    )
                  : const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1433),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9A93B0),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              imageFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
              size: 18,
              color: imageFile != null ? AppTheme.success : AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const _LocationChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F5FC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 42,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1433),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1433),
              ),
            ),
          ),
          _ToggleButton(label: l10n.no, isSelected: !value, onTap: () => onChanged(false)),
          const SizedBox(width: 6),
          _ToggleButton(label: l10n.yes, isSelected: value, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF7F5FC),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF6F6890),
          ),
        ),
      ),
    );
  }
}

class _TextAreaInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _TextAreaInput({
    required this.controller,
    required this.hint,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E0F8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFB8B2C8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    );
  }
}

