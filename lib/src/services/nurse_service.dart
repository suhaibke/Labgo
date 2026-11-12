import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

// Nurse Application Models
class NurseApplication {
  final String id;
  final Map<String, dynamic> personalInfo;
  final String nationalCardImageFront;
  final String nationalCardImageBack;
  final String certificateImage;
  final NurseApplicationLocation location;
  final NurseQuestionnaire questionnaire;
  final String status;
  final DateTime submittedAt;
  final Map<String, dynamic>? reviewDetails;
  final String? additionalInfo;

  NurseApplication({
    required this.id,
    required this.personalInfo,
    required this.nationalCardImageFront,
    required this.nationalCardImageBack,
    required this.certificateImage,
    required this.location,
    required this.questionnaire,
    required this.status,
    required this.submittedAt,
    this.reviewDetails,
    this.additionalInfo,
  });

  factory NurseApplication.fromJson(Map<String, dynamic> json) {
    return NurseApplication(
      id: json['_id']?.toString() ?? '',
      personalInfo: json['personalInfo'] is Map ? json['personalInfo'] as Map<String, dynamic> : {},
      nationalCardImageFront: json['nationalCardImageFront']?.toString() ?? (json['nationalCardImage']?.toString() ?? ''),
      nationalCardImageBack: json['nationalCardImageBack']?.toString() ?? '',
      certificateImage: json['certificateImage']?.toString() ?? '',
      location: NurseApplicationLocation.fromJson(json['location'] is Map ? json['location'] as Map<String, dynamic> : {}),
      questionnaire: NurseQuestionnaire.fromJson(json['questionnaire'] is Map ? json['questionnaire'] as Map<String, dynamic> : {}),
      status: json['status']?.toString() ?? 'pending',
      submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt'].toString()) : DateTime.now(),
      reviewDetails: json['reviewDetails'] is Map ? json['reviewDetails'] as Map<String, dynamic> : null,
      additionalInfo: json['additionalInfo']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isUnderReview => status == 'under_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isOnHold => status == 'on_hold';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'on_hold':
        return 'On Hold';
      default:
        return status;
    }
  }
}

class NurseApplicationLocation {
  final String city;
  final String zone;
  final String? address;
  final double? latitude;
  final double? longitude;

  NurseApplicationLocation({
    required this.city,
    required this.zone,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory NurseApplicationLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'];
    return NurseApplicationLocation(
      city: json['city']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: coords is Map && coords['latitude'] != null
          ? double.tryParse(coords['latitude'].toString())
          : null,
      longitude: coords is Map && coords['longitude'] != null
          ? double.tryParse(coords['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'zone': zone,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };
  }
}

class NurseQuestionnaire {
  final bool ownsCar;
  final bool isEmployed;

  NurseQuestionnaire({
    required this.ownsCar,
    required this.isEmployed,
  });

  factory NurseQuestionnaire.fromJson(Map<String, dynamic> json) {
    return NurseQuestionnaire(
      ownsCar: json['ownsCar'] == true,
      isEmployed: json['isEmployed'] == true,
    );
  }
}

// Nurse Application Service
class NurseService {
  /// Submit a nurse application
  static Future<Map<String, dynamic>> submitApplication({
    required File nationalCardImageFront,
    required File nationalCardImageBack,
    required File certificateImage,
    required String city,
    required String zone,
    String? address,
    double? latitude,
    double? longitude,
    required bool ownsCar,
    required bool isEmployed,
    String? additionalInfo,
  }) async {
    try {
      final token = await AuthService().getToken();

      final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/api/nurse/apply'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['city'] = city;
      request.fields['zone'] = zone;
      if (address != null) request.fields['address'] = address;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      request.fields['ownsCar'] = ownsCar.toString();
      request.fields['isEmployed'] = isEmployed.toString();
      if (additionalInfo != null) request.fields['additionalInfo'] = additionalInfo;

      request.files.add(await http.MultipartFile.fromPath(
        'nationalCardImageFront',
        nationalCardImageFront.path,
        filename: 'national-card-front.jpg',
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'nationalCardImageBack',
        nationalCardImageBack.path,
        filename: 'national-card-back.jpg',
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'certificateImage',
        certificateImage.path,
        filename: 'certificate.jpg',
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) data = decoded;
        }
      } catch (_) {
        return {
          'success': false,
          'message': 'Failed to submit application (${response.statusCode})',
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Application submitted successfully',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to submit application',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get current user's nurse application
  static Future<Map<String, dynamic>> getMyApplication() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/my-application',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'application': NurseApplication.fromJson(data['data']['application']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get application',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Check if user has pending application
  static Future<bool> hasPendingApplication() async {
    final result = await getMyApplication();
    if (result['success'] == true && result['application'] != null) {
      final app = result['application'] as NurseApplication;
      return app.isPending || app.isUnderReview || app.isOnHold;
    }
    return false;
  }
}
