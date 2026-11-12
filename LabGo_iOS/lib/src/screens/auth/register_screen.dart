import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../widgets/app_logo.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/cities.dart';
import 'login_screen.dart';
import 'otp_screen.dart';
import '../../../l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedGender = 'male';  // Internal value, not displayed
  String? _selectedCity;  // City selection (stores Arabic name for backend)
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  // Gender data: internal value -> localized display value
  static const Map<String, String> _genderValues = {
    'male': 'Male',
    'female': 'Female',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 13 * 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: AppTheme.white,
              surface: AppTheme.white,
              onSurface: AppTheme.gray900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
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

  Future<void> _handleRegister() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseAgreeToTheTermsAndConditions),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phone = _phoneController.text.trim();

      // Step 1: Send OTP first
      final otpResult = await AuthService.sendOtp(
        phone: phone,
        purpose: 'register',
      );

      if (otpResult['success'] == true) {
        // Step 2: Navigate to OTP screen with registration data
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Store registration data temporarily (you could use a more sophisticated approach)
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                phone: phone,
                messageId: otpResult['messageId'],
                purpose: 'register',
                userData: {
                  'name': _nameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': phone,
                  'gender': _selectedGender,
                  'city': _selectedCity,
                  'birthDate': _selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                      : '',
                  'password': _passwordController.text,
                },
              ),
            ),
          );
        }
      } else {
        // Handle OTP send failure - show actual error message
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(otpResult['message'] ?? l10n.failedToSendOtp),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show actual error for debugging
        print('=== REGISTER ERROR ===');
        print('Exception: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.connectionError),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const AppLogo(height: 80, showText: false),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    l10n.createAccount,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    l10n.joinLabGoToday,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.gray600,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.fullName,
                      hintText: l10n.enterYourFullName,
                      prefixIcon: const Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseEnterYourName;
                      }
                      if (value.length < 2) {
                        return l10n.nameMustBeAtLeast2Characters;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.emailAddress,
                      hintText: l10n.enterYourEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseEnterYourEmail;
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return l10n.pleaseEnterAValidEmail;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Phone
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

                  // Gender
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: l10n.gender,
                      prefixIcon: const Icon(Icons.wc_outlined),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'male',
                        child: Text(l10n.male),
                      ),
                      DropdownMenuItem<String>(
                        value: 'female',
                        child: Text(l10n.female),
                      ),
                    ],
                    onChanged: !_isLoading
                        ? (String? newValue) {
                            setState(() {
                              _selectedGender = newValue!;
                            });
                          }
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // City
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: l10n.selectCity,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                    items: iraqiCities.map((city) {
                      final locale = Localizations.localeOf(context).languageCode;
                      return DropdownMenuItem<String>(
                        value: city.nameAr,  // Store Arabic name for backend
                        child: Text(city.getLocalizedName(locale)),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.pleaseSelectCity;
                      }
                      return null;
                    },
                    onChanged: !_isLoading
                        ? (String? newValue) {
                            setState(() {
                              _selectedCity = newValue;
                            });
                          }
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Date of Birth
                  InkWell(
                    onTap: _isLoading ? null : _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        border: Border.all(
                          color: _selectedDate != null
                              ? AppTheme.primaryColor
                              : AppTheme.gray200,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cake_outlined,
                            color: AppTheme.gray400,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate!)
                                  : l10n.selectDateOfBirth,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: _selectedDate != null
                                        ? AppTheme.gray900
                                        : AppTheme.gray400,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      hintText: l10n.createAPassword,
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

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      hintText: l10n.reEnterYourPassword,
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

                  const SizedBox(height: 16),

                  // Terms & Conditions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: !_isLoading
                            ? (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              }
                            : null,
                        activeColor: AppTheme.primaryColor,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            children: [
                              Text(
                                l10n.iAgreeToThe,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(l10n.termsAndConditions),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Register Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.createAccount),
                  ),

                  const SizedBox(height: 24),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAnAccount,
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
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                        child: Text(l10n.signIn),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
