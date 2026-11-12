import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import 'package:labgo_app/main.dart' as main;

class ResetPasswordNewPasswordScreen extends StatefulWidget {
  final String resetToken;

  const ResetPasswordNewPasswordScreen({
    super.key,
    required this.resetToken,
  });

  @override
  State<ResetPasswordNewPasswordScreen> createState() => _ResetPasswordNewPasswordScreenState();
}

class _ResetPasswordNewPasswordScreenState extends State<ResetPasswordNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l10n.pleaseEnterAPassword;
    }
    if (value.length < 8) {
      return l10n.passwordMustBeAtLeast8Characters;
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return l10n.passwordMustContainAtLeastOneUppercaseLetter;
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return l10n.passwordMustContainAtLeastOneLowercaseLetter;
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return l10n.passwordMustContainAtLeastOneNumber;
    }
    return null;
  }

  Future<void> _handleResetPassword() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.confirmPasswordReset(
        resetToken: widget.resetToken,
        newPassword: _passwordController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Show success dialog then navigate to login
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 64,
              ),
              title: Text(l10n.passwordResetSuccessful),
              content: Text(l10n.passwordResetSuccessfulMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).popUntil((route) => route.isFirst); // Go to login
                  },
                  child: Text(l10n.backToLogin),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? l10n.passwordResetFailed),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      const AppLogo(height: 80, showText: false),
                      const SizedBox(height: 32),
                      Text(
                        l10n.enterNewPassword,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.enterNewPasswordDescription,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.gray600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // New Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: l10n.newPassword,
                          hintText: l10n.enterNewPasswordHint,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) => _validatePassword(value, context),
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: l10n.confirmNewPassword,
                          hintText: l10n.confirmNewPasswordHint,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.pleaseConfirmYourPassword;
                          }
                          if (value != _passwordController.text) {
                            return l10n.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Reset Password Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(l10n.resetPassword),
                      ),

                      const SizedBox(height: 24),

                      // Cancel Button
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
                ),
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
                    padding: const EdgeInsets.all(12),
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
