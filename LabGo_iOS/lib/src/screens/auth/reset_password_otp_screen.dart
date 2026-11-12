import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import 'reset_password_new_password_screen.dart';
import 'package:labgo_app/main.dart' as main;

class ResetPasswordOtpScreen extends StatefulWidget {
  final String phone;
  final String messageId;

  const ResetPasswordOtpScreen({
    super.key,
    required this.phone,
    required this.messageId,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
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
    _startCooldownTimer();
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

  String _formatPhoneDisplay(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length > 10) {
      return '+${cleaned.substring(0, 3)} ${cleaned.substring(3, 5)} ${cleaned.substring(5, 8)} ${cleaned.substring(8)}';
    }
    return phone;
  }

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

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (value.isNotEmpty && _isOtpComplete()) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoading) {
          _verifyOtp();
        }
      });
    }
  }

  bool _isOtpComplete() {
    return _otpControllers.every((controller) => controller.text.length == 1);
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

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
      final result = await AuthService.verifyPasswordResetOtp(
        phone: widget.phone,
        code: code,
        messageId: widget.messageId,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Navigate to new password screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResetPasswordNewPasswordScreen(
                resetToken: result['resetToken'],
              ),
            ),
          );
        } else {
          setState(() {
            _remainingAttempts = result['remainingAttempts'] ?? _remainingAttempts - 1;
          });

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

  Future<void> _resendOtp() async {
    final l10n = AppLocalizations.of(context)!;

    if (_resendCooldown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthService.requestPasswordReset(
        phone: widget.phone,
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
                  const AppLogo(height: 80, showText: false),
                  const SizedBox(height: 32),
                  Text(
                    l10n.otpVerification,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.enterThe6DigitCodeSentTo(_formatPhoneDisplay(widget.phone)),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.gray600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // OTP Input Fields (LTR directionality)
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
