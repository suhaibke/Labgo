import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import 'package:labgo_app/main.dart' as main;

/// OTP Verification Screen
/// Handles phone number verification using OTP code sent via SMS
class OtpScreen extends StatefulWidget {
  /// Phone number to verify
  final String phone;

  /// Message ID from sendOtp response
  final String messageId;

  /// Purpose: 'register', 'login', or 'reset'
  final String purpose;

  /// User data for registration (only used when purpose is 'register')
  final Map<String, dynamic>? userData;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.messageId,
    this.purpose = 'register',
    this.userData,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  int _remainingAttempts = 3;

  // Language data
  static const Map<String, Locale> _languages = {
    'العربية': Locale('ar'),
    'Kurdî': Locale('ku'),
    'Türkçe': Locale('tr'),
    'English': Locale('en'),
  };

  String _selectedLanguage = 'العربية';

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              onTap: () {
                final appState = main.LabGoApp.of(context);
                appState?.setLocale(entry.value);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Start the first focus node
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Format phone number for display
  String _formatPhoneDisplay(String phone) {
    // Add space formatting for better readability
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length > 10) {
      return '+${cleaned.substring(0, 3)} ${cleaned.substring(3, 5)} ${cleaned.substring(5, 8)} ${cleaned.substring(8)}';
    }
    return phone;
  }

  /// Start the resend cooldown timer
  void _startCooldownTimer() {
    setState(() {
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Handle OTP input change
  void _onOtpChanged(int index, String value) {
    // Pasting the full code lands in whichever field had focus - spread its
    // digits across the remaining fields instead of dropping them.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      final lastFilled = (index + digits.length - 1).clamp(0, 5);
      _focusNodes[lastFilled].requestFocus();

      if (_isOtpComplete()) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isLoading) {
            _verifyOtp();
          }
        });
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field when deleting
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-submit when all fields are filled
    if (value.isNotEmpty && _isOtpComplete()) {
      // Add slight delay for better UX
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoading) {
          _verifyOtp();
        }
      });
    }
  }

  /// Check if all OTP fields are filled
  bool _isOtpComplete() {
    return _otpControllers.every((controller) => controller.text.length == 1);
  }

  /// Get the complete OTP code
  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  /// Verify OTP code
  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _getOtpCode();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterAValidEmail),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;

      // For registration, use registerWithOtp endpoint
      if (widget.purpose == 'register' && widget.userData != null) {
        result = await AuthService.registerWithOtp(
          name: widget.userData!['name'],
          phone: widget.phone,
          city: widget.userData!['city'],
          gender: widget.userData!['gender'],
          birthDate: widget.userData!['birthDate'],
          password: widget.userData!['password'],
          code: code,
          messageId: widget.messageId,
        );
      } else {
        // For login/reset, use verifyOtp endpoint
        result = await AuthService.verifyOtp(
          phone: widget.phone,
          code: code,
          messageId: widget.messageId,
          purpose: widget.purpose,
        );
      }

      if (mounted) {
        if (result['success'] == true) {
          // Navigate to main screen with home tab
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );
        } else {
          setState(() {
            _remainingAttempts = result['remainingAttempts'] ?? _remainingAttempts - 1;
          });

          // Clear all OTP fields
          for (var controller in _otpControllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? l10n.verificationFailed),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Resend OTP
  Future<void> _resendOtp() async {
    final l10n = AppLocalizations.of(context)!;

    if (_resendCooldown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthService.resendOtp(
        phone: widget.phone,
        purpose: widget.purpose,
      );

      if (mounted) {
        if (result['success'] == true) {
          _startCooldownTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.otpSentSuccessfully),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        } else {
          // Handle cooldown from server
          if (result['cooldown'] != null) {
            setState(() {
              _resendCooldown = result['cooldown'];
            });
            _startCooldownTimer();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? l10n.failedToResendOtp),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _selectedLanguage = _languages.entries
        .firstWhere(
          (entry) => entry.value.languageCode == Localizations.localeOf(context).languageCode,
          orElse: () => _languages.entries.first,
        )
        .key;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Logo
                  const AppLogo(height: 80, showText: false),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    l10n.otpVerification,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    l10n.enterThe6DigitCodeSentTo(_formatPhoneDisplay(widget.phone)),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.gray600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // OTP Input Fields
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 50,
                          height: 60,
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !_isLoading,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: AppTheme.gray300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppTheme.gray50,
                            ),
                            onChanged: (value) => _onOtpChanged(index, value),
                            onSubmitted: (_) {
                              if (_isOtpComplete()) {
                                _verifyOtp();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Verify Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.verify),
                  ),

                  const SizedBox(height: 24),

                  // Resend Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.didntReceiveTheCode,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: (_isResending || _resendCooldown > 0)
                            ? null
                            : _resendOtp,
                        child: _isResending
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              )
                            : Text(
                                _resendCooldown > 0
                                    ? l10n.resendIn(_resendCooldown.toString())
                                    : l10n.resend,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _resendCooldown > 0
                                      ? AppTheme.gray400
                                      : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Remaining attempts warning
                  if (_remainingAttempts < 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.remainingAttempts(_remainingAttempts.toString()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Language icon button at top right (inside SafeArea)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.language, size: 28),
                  onPressed: () => _showLanguageDialog(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.gray50,
                    foregroundColor: AppTheme.gray900,
                  ),
                ),
              ),
            ),
          ),
          // Back button at top left
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
