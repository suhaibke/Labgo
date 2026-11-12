import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ApiService {
  // Production server URL
  static const String baseUrl = 'https://www.labgo-iq.com';
  // Android emulator uses 10.0.2.2 to access host machine's localhost
  // static const String baseUrl = 'http://10.0.2.2:3000';
  // static const String baseUrl = 'http://localhost:3000';
  static const String apiVersion = '/api';

  // Timeout duration
  static const Duration timeout = Duration(seconds: 30);

  // Global navigator key for logout navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// The backend stores uploaded media (logos, prescriptions, profile
  /// pictures, ...) as a bare R2 path like '/uploads/profilePictures/x.jpg',
  /// not a full URL - resolve it against [baseUrl] so it's actually loadable.
  /// Already-absolute URLs are returned unchanged.
  static String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return path;
    if (path.startsWith('http')) return path;
    return path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
  }

  // Track if logout is in progress to prevent multiple logout calls
  static bool _isLoggingOut = false;

  // Headers
  static Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Handle token expiration by logging out the user
  static Future<void> _handleTokenExpiration() async {
    if (_isLoggingOut) return;

    _isLoggingOut = true;

    try {
      // Clear auth data
      final authService = AuthService();
      await authService.logout();

      // Navigate to login screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      // Ignore errors during logout
    } finally {
      _isLoggingOut = false;
    }
  }

  // Handle blocked user by logging out and navigating to blocked screen
  static Future<void> _handleUserBlocked(String blockReason) async {
    if (_isLoggingOut) return;

    _isLoggingOut = true;

    try {
      // Store block reason for display on blocked screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('block_reason', blockReason);

      // Clear auth data
      final authService = AuthService();
      await authService.logout();

      // Navigate to blocked screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/blocked',
          (route) => false,
        );
      }
    } catch (e) {
      // Ignore errors during logout
    } finally {
      _isLoggingOut = false;
    }
  }

  // Check if response indicates token expiration
  static bool _isTokenExpiredError(int statusCode, Map<String, dynamic>? data) {
    if (statusCode == 401) {
      final message = data?['message']?.toString().toLowerCase() ?? '';
      return message.contains('expired') ||
             message.contains('invalid token') ||
             message.contains('no token provided') ||
             message.contains('access denied');
    }
    return false;
  }

  // Check if response indicates user is blocked
  static bool _isUserBlockedError(int statusCode, Map<String, dynamic>? data) {
    if (statusCode == 403 && data?['userBlocked'] == true) {
      return true;
    }
    return false;
  }

  // Check response for token expiration or blocked user (with safe JSON parsing)
  static void _checkForAuthErrors(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      // Check for blocked user first (403)
      if (_isUserBlockedError(response.statusCode, data)) {
        final blockReason = data['blockReason']?.toString() ?? 'No reason provided';
        _handleUserBlocked(blockReason);
        return;
      }
      
      // Check for token expiration (401)
      if (_isTokenExpiredError(response.statusCode, data)) {
        _handleTokenExpiration();
      }
    } catch (e) {
      // If JSON parsing fails, just check status code
      if (response.statusCode == 401) {
        _handleTokenExpiration();
      }
    }
  }

  // GET Request
  static Future<http.Response> get(
    String endpoint, {
    String? token,
    Map<String, dynamic>? queryParams,
  }) async {
    Uri url = Uri.parse('$baseUrl$apiVersion$endpoint');

    if (queryParams != null) {
      // Convert all query parameter values to strings
      final stringParams = <String, String>{};
      queryParams.forEach((key, value) {
        stringParams[key] = value?.toString() ?? '';
      });
      url = url.replace(queryParameters: stringParams);
    }

    try {
      final response = await http
          .get(url, headers: _headers(token: token))
          .timeout(timeout);

      // Check for token expiration
      if (token != null) {
        _checkForAuthErrors(response);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST Request
  static Future<http.Response> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$baseUrl$apiVersion$endpoint');

    // Debug logging
    print('=== API POST DEBUG ===');
    print('URL: $url');
    print('Headers: ${_headers(token: token)}');
    print('Body: ${body != null ? jsonEncode(body) : 'null'}');

    try {
      final response = await http
          .post(
            url,
            headers: _headers(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Check for token expiration
      if (token != null) {
        _checkForAuthErrors(response);
      }

      return response;
    } catch (e, stackTrace) {
      print('=== API POST ERROR ===');
      print('Exception: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // PUT Request
  static Future<http.Response> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$baseUrl$apiVersion$endpoint');

    try {
      final response = await http
          .put(
            url,
            headers: _headers(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      // Check for token expiration
      if (token != null) {
        _checkForAuthErrors(response);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // DELETE Request
  static Future<http.Response> delete(
    String endpoint, {
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl$apiVersion$endpoint');

    try {
      final response = await http
          .delete(url, headers: _headers(token: token))
          .timeout(timeout);

      // Check for token expiration
      if (token != null) {
        _checkForAuthErrors(response);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Multipart Request (for file uploads)
  static Future<http.Response> multipart(
    String endpoint, {
    String? token,
    required Map<String, String> fields,
    Map<String, http.MultipartFile>? files,
  }) async {
    final url = Uri.parse('$baseUrl$apiVersion$endpoint');

    try {
      final request = http.MultipartRequest('POST', url);

      // Add headers
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields
      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      // Add files
      if (files != null) {
        files.forEach((key, file) {
          request.files.add(file);
        });
      }

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      // Check for token expiration
      if (token != null) {
        _checkForAuthErrors(response);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }
}

class ApiEndpoints {
  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String registerWithOtp = '/auth/register-with-otp';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // OTP endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';

  // Password reset endpoints
  static const String requestPasswordReset = '/auth/password-reset/request';
  static const String verifyPasswordResetOtp = '/auth/password-reset/verify-otp';
  static const String confirmPasswordReset = '/auth/password-reset/confirm';
  static const String changePassword = '/auth/change-password';

  // Profile update endpoints
  static const String updateProfile = '/auth/update-profile';
  static const String uploadProfilePicture = '/auth/profile-picture';
  static const String sendPhoneChangeOtp = '/auth/send-phone-change-otp';
  static const String verifyPhoneChange = '/auth/verify-phone-change';
  static const String deleteAccount = '/auth/delete-account';

  // Lab endpoints
  static const String labs = '/app/labs';
  static const String labDetails = '/app/labs';
  static const String labTests = '/app/labs';
  static const String labSpecializations = '/app/labs/meta/specializations';

  // FCM Notification endpoints
  static const String registerFcmToken = '/notifications/register-token';
  static const String unregisterFcmToken = '/notifications/unregister-token';
  static const String clientDebugLog = '/notifications/client-debug-log';
  static const String notifications = '/notifications';

  // Nurse custody endpoints
  static const String nurseCustody = '/nurse/custody';

  // Quick services endpoints
  static const String appServices = '/app/services';
  static const String appPackages = '/app/packages';
  static const String appBanners = '/app/banners';
}

