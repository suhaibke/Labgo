import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'notification_service.dart';

class AuthService {
  // Secure storage for tokens
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _viewModeKey = 'view_mode'; // 'nurse' or 'patient'

  // Guest mode flag (in-memory, not persisted)
  static bool _isGuestMode = false;

  /// Whether the user is browsing as a guest (not logged in)
  static bool get isGuestMode => _isGuestMode;

  /// Enable or disable guest mode
  static void setGuestMode(bool value) {
    _isGuestMode = value;
  }

  /// Returns true only if the user is fully authenticated (not a guest)
  static Future<bool> isAuthenticated() async {
    if (_isGuestMode) return false;
    final authService = AuthService();
    return await authService.isLoggedIn();
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String loginInput,
    required String password,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.login,
        body: {
          'loginInput': loginInput,
          'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Clear guest mode on successful login
        _isGuestMode = false;

        // Store token
        await _storage.write(key: _tokenKey, value: data['token']);

        // Store user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        await prefs.setBool(_isLoggedInKey, true);

        // Get FCM token and subscribe to topics (non-blocking, don't fail login)
        try {
          final notificationService = NotificationService();
          await notificationService.getAndSaveToken();
          await notificationService.subscribeToUserTopics(data['user']);
        } catch (_) {}

        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String gender,
    required String birthDate,
    required String password,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.register,
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'gender': gender,
          'birthDate': birthDate,
          'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Store token
        await _storage.write(key: _tokenKey, value: data['token']);

        // Store user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        await prefs.setBool(_isLoggedInKey, true);

        // Get FCM token and subscribe to topics
        final notificationService = NotificationService();
        await notificationService.getAndSaveToken();
        await notificationService.subscribeToUserTopics(data['user']);

        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Register with OTP verification
  /// Completes registration after verifying OTP code
  static Future<Map<String, dynamic>> registerWithOtp({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String gender,
    required String birthDate,
    required String password,
    required String code,
    required String messageId,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.registerWithOtp,
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'city': city,
          'gender': gender,
          'birthDate': birthDate,
          'password': password,
          'code': code,
          'messageId': messageId,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Store token
        await _storage.write(key: _tokenKey, value: data['token']);

        // Store user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        await prefs.setBool(_isLoggedInKey, true);

        // Get FCM token and subscribe to topics
        final notificationService = NotificationService();
        await notificationService.getAndSaveToken();
        await notificationService.subscribeToUserTopics(data['user']);

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Unsubscribe from FCM topics and remove token
      final notificationService = NotificationService();
      await notificationService.unsubscribeFromAllTopics();
      await notificationService.removeTokenFromBackend();
    } catch (e) {
      // Ignore notification cleanup errors
    }

    try {
      final token = await getToken();
      if (token != null) {
        await ApiService.post(ApiEndpoints.logout, token: token);
      }
    } catch (e) {
      // Ignore logout API errors
    } finally {
      // Clear local storage
      await _storage.delete(key: _tokenKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.setBool(_isLoggedInKey, false);
      await prefs.remove(_viewModeKey); // Clear view mode on logout
      _isGuestMode = false; // Clear guest mode on logout
    }
  }

  // ============================================================================
  // View Mode Methods (for nurses to switch to patient view)
  // ============================================================================

  /// Get current view mode ('nurse' or 'patient')
  /// Returns null if not set (defaults to user's actual role)
  static Future<String?> getViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewModeKey);
  }

  /// Set view mode ('nurse' or 'patient')
  static Future<void> setViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode);
  }

  /// Clear view mode (return to actual role)
  static Future<void> clearViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_viewModeKey);
  }

  // Get Token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Get User Data
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      return jsonDecode(userJson);
    }

    return null;
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (isLoggedIn) {
      final token = await getToken();
      return token != null;
    }

    return false;
  }

  // Refresh user data
  Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await ApiService.get(ApiEndpoints.me, token: token);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return data['user'];
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  // ============================================================================
  // OTP Methods
  // ============================================================================

  /// Send OTP to the specified phone number
  /// [phone] - Phone number to send OTP to
  /// [purpose] - Purpose of OTP: 'register', 'login', or 'reset'
  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String purpose = 'register',
  }) async {
    print('=== AUTH SERVICE SEND OTP ===');
    print('Phone: $phone');
    print('Purpose: $purpose');
    print('URL: ${ApiService.baseUrl}${ApiService.apiVersion}${ApiEndpoints.sendOtp}');

    try {
      final response = await ApiService.post(
        ApiEndpoints.sendOtp,
        body: {
          'phone': phone,
          'purpose': purpose,
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);
      print('Parsed data: $data');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messageId': data['messageId'],
          'expiresIn': data['expiresIn'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
          'cooldown': data['cooldown'],
        };
      }
    } catch (e, stackTrace) {
      print('=== SEND OTP EXCEPTION ===');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Verify OTP code
  /// [phone] - Phone number
  /// [code] - OTP code entered by user
  /// [messageId] - Message ID received from sendOtp
  /// [purpose] - Purpose of OTP: 'register', 'login', or 'reset'
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    required String messageId,
    String purpose = 'register',
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.verifyOtp,
        body: {
          'phone': phone,
          'code': code,
          'messageId': messageId,
          'purpose': purpose,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Store token
        await _storage.write(key: _tokenKey, value: data['token']);

        // Store user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));
        await prefs.setBool(_isLoggedInKey, true);

        // Get FCM token and subscribe to topics
        final notificationService = NotificationService();
        await notificationService.getAndSaveToken();
        await notificationService.subscribeToUserTopics(data['user']);

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed',
          'remainingAttempts': data['remainingAttempts'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Resend OTP to the specified phone number
  /// [phone] - Phone number to resend OTP to
  /// [purpose] - Purpose of OTP: 'register', 'login', or 'reset'
  static Future<Map<String, dynamic>> resendOtp({
    required String phone,
    String purpose = 'register',
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.resendOtp,
        body: {
          'phone': phone,
          'purpose': purpose,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messageId': data['messageId'],
          'expiresIn': data['expiresIn'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to resend OTP',
          'cooldown': data['cooldown'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // ============================================================================
  // Password Reset Methods
  // ============================================================================

  /// Request password reset - sends OTP to phone number
  /// [phone] - Phone number to send OTP to
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String phone,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.requestPasswordReset,
        body: {
          'phone': phone,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messageId': data['messageId'],
          'expiresIn': data['expiresIn'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
          'cooldown': data['cooldown'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Verify OTP for password reset
  /// [phone] - Phone number
  /// [code] - OTP code entered by user
  /// [messageId] - Message ID received from requestPasswordReset
  static Future<Map<String, dynamic>> verifyPasswordResetOtp({
    required String phone,
    required String code,
    required String messageId,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.verifyPasswordResetOtp,
        body: {
          'phone': phone,
          'code': code,
          'messageId': messageId,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'resetToken': data['resetToken'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed',
          'remainingAttempts': data['remainingAttempts'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Confirm password reset with new password
  /// [resetToken] - Reset token received from verifyPasswordResetOtp
  /// [newPassword] - New password to set
  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.confirmPasswordReset,
        body: {
          'resetToken': resetToken,
          'newPassword': newPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Password reset failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Change password (while logged in)
  /// [currentPassword] - Current password for verification
  /// [newPassword] - New password to set
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await ApiService.post(
        ApiEndpoints.changePassword,
        token: token,
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // ============================================================================
  // Profile Update Methods
  // ============================================================================

  /// Update user profile (non-phone fields)
  /// [name] - New name (optional)
  /// [email] - New email (optional)
  /// [gender] - New gender (optional)
  /// [city] - New city (optional)
  /// [birthDate] - New birth date (optional)
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? city,
    String? birthDate,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (gender != null) body['gender'] = gender;
      if (city != null) body['city'] = city;
      if (birthDate != null) body['birthDate'] = birthDate;

      final response = await ApiService.put(
        ApiEndpoints.updateProfile,
        token: token,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update local user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Send OTP to new phone number for phone change
  /// [newPhone] - New phone number to verify
  static Future<Map<String, dynamic>> sendPhoneChangeOtp({
    required String newPhone,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await ApiService.post(
        ApiEndpoints.sendPhoneChangeOtp,
        token: token,
        body: {
          'newPhone': newPhone,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messageId': data['messageId'],
          'expiresIn': data['expiresIn'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP',
          'cooldown': data['cooldown'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Verify OTP and update phone number
  /// [code] - OTP code entered by user
  /// [messageId] - Message ID received from sendPhoneChangeOtp
  /// [newPhone] - New phone number to set
  static Future<Map<String, dynamic>> verifyPhoneChange({
    required String code,
    required String messageId,
    required String newPhone,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await ApiService.post(
        ApiEndpoints.verifyPhoneChange,
        token: token,
        body: {
          'code': code,
          'messageId': messageId,
          'newPhone': newPhone,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update local user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(data['user']));

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed',
          'remainingAttempts': data['remainingAttempts'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Delete user account
  /// [password] - Optional password for confirmation
  static Future<Map<String, dynamic>> deleteAccount({
    String? password,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      // For DELETE with body, we need to use a custom request
      final url = Uri.parse('${ApiService.baseUrl}${ApiService.apiVersion}${ApiEndpoints.deleteAccount}');
      final request = http.Request('DELETE', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      
      if (password != null) {
        request.body = jsonEncode({'password': password});
      }

      final streamedResponse = await request.send().timeout(ApiService.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Clear local auth data
        await authService.logout();

        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Delete failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }
}

