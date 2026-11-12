import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';

/// OTP Verification Screen for Phone Number Change
/// Handles phone number change verification using OTP code sent via SMS
class PhoneChangeOtpScreen extends StatefulWidget {
  /// New phone number to verify
  final String newPhone;

  /// Message ID from sendPhoneChangeOtp response
  final String messageId;

  const PhoneChangeOtpScreen({
    super.key,
    required this.newPhone,
    required this.messageId,
  });

  @override
  State<PhoneChangeOtpScreen> createState() => _PhoneChangeOtpScreenState();
}

class _PhoneChangeOtpScreenState extends State<PhoneChangeOtpScreen> {
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
  String _currentMessageId = '';

  @override
  void initState() {
    super.initState();
    _currentMessageId = widget.messageId;
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
          content: Text(l10n.pleaseEnterAValidOtp),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.verifyPhoneChange(
        code: code,
        messageId: _currentMessageId,
        newPhone: widget.newPhone,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Show success and return to edit profile
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.profileUpdated),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
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
      final result = await AuthService.sendPhoneChangeOtp(
        newPhone: widget.newPhone,
      );

      if (mounted) {
        if (result['success'] == true) {
          _currentMessageId = result['messageId'];
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

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
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
                l10n.enterThe6DigitCodeSentTo(_formatPhoneDisplay(widget.newPhone)),
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
                          LengthLimitingTextInputFormatter(1),
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
    );
  }
}
