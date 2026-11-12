import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_logo.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../../../l10n/app_localizations.dart';
import 'package:labgo_app/main.dart' as main;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Language data
  static const Map<String, Locale> _languages = {
    'العربية': Locale('ar'),
    'Kurdî': Locale('ku'),
    'Türkçe': Locale('tr'),
    'English': Locale('en'),
  };

  String _selectedLanguage = 'العربية';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.login(
        loginInput: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loginFailed),
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
                  // Logo
                  const SizedBox(height: 80),
                  const AppLogo(height: 100, showText: true),
                  const SizedBox(height: 50),
                  Text(
                    l10n.signInToContinue,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.gray600,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      hintText: l10n.enterYourPhoneNumber,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseEnterYourPhoneNumber;
                      }
                      if (value.length != 11) {
                        return l10n.pleaseEnterAValidPhoneNumber;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      hintText: l10n.enterYourPassword,
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseEnterYourPassword;
                      }
                      if (value.length < 8) {
                        return l10n.passwordMustBeAtLeast8Characters;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Remember Me & Forgot Password
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: !_isLoading
                            ? (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              }
                            : null,
                        activeColor: AppTheme.primaryColor,
                      ),
                      Text(
                        l10n.rememberMe,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: !_isLoading
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ResetPasswordScreen(),
                                  ),
                                );
                              }
                            : null,
                        child: Text(l10n.forgotPassword),
                      ),
                    ],
                  ),

                  const SizedBox(height: 52),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.signIn),
                  ),

                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.dontHaveAccount,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.gray600,
                            ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterScreen(),
                                  ),
                                );
                              },
                        child: Text(l10n.createAccount),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Browse as Guest Button
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            AuthService.setGuestMode(true);
                            Navigator.of(context).pushReplacementNamed('/main');
                          },
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: Text(l10n.browseAsGuest, overflow: TextOverflow.ellipsis, maxLines: 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gray700,
                      side: const BorderSide(color: AppTheme.gray300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
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
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      ),
    ],
    ),
    );
  }
}
