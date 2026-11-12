import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

/// An admin-managed quick service (e.g. "Vitamin D") shown as a shortcut
/// card on the home page.
class QuickService {
  final String id;
  final String name;
  final String? nameAr;
  final String? subtitle;
  final String icon;

  QuickService({
    required this.id,
    required this.name,
    this.nameAr,
    this.subtitle,
    required this.icon,
  });

  factory QuickService.fromJson(Map<String, dynamic> json) {
    // Convert relative icon paths to full URLs, same as Lab.logo.
    String iconUrl = json['icon']?.toString() ?? '';
    if (iconUrl.isNotEmpty && !iconUrl.startsWith('http')) {
      iconUrl = iconUrl.startsWith('/')
          ? '${ApiService.baseUrl}$iconUrl'
          : '${ApiService.baseUrl}/$iconUrl';
    }

    return QuickService(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      subtitle: json['subtitle']?.toString(),
      icon: iconUrl,
    );
  }

  /// Localized display name - falls back to the English name.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && (nameAr?.isNotEmpty ?? false)) return nameAr!;
    return name;
  }
}

/// A lab offering a specific quick service, with that service's price at
/// this lab.
class ServiceLab {
  final String id;
  final String name;
  final String? logo;
  final String? city;
  final String? address;
  final double? averageRating;
  final int? totalRatings;
  final String? testId;
  final String? testName;
  final num? price;

  ServiceLab({
    required this.id,
    required this.name,
    this.logo,
    this.city,
    this.address,
    this.averageRating,
    this.totalRatings,
    this.testId,
    this.testName,
    this.price,
  });

  factory ServiceLab.fromJson(Map<String, dynamic> json) {
    final test = json['test'] as Map<String, dynamic>?;

    // Convert relative logo paths to full URLs, same as Lab.logo.
    String? logoUrl = json['logo']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty && !logoUrl.startsWith('http')) {
      logoUrl = logoUrl.startsWith('/')
          ? '${ApiService.baseUrl}$logoUrl'
          : '${ApiService.baseUrl}/$logoUrl';
    }

    return ServiceLab(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: logoUrl,
      city: json['city']?.toString(),
      address: json['address']?.toString(),
      averageRating: json['averageRating'] is num ? (json['averageRating'] as num).toDouble() : null,
      totalRatings: json['totalRatings'] is num ? (json['totalRatings'] as num).toInt() : null,
      testId: test?['_id']?.toString(),
      testName: test?['name']?.toString(),
      price: test?['price'] is num ? test!['price'] as num : null,
    );
  }
}

class QuickServiceApi {
  static Future<Map<String, dynamic>> getServices() async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.get(ApiEndpoints.appServices, token: token);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = data['data']?['services'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'services': list.map((e) => QuickService.fromJson(e as Map<String, dynamic>)).toList(),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load services'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> getLabsForService(String serviceId, {String? city}) async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.get(
        '${ApiEndpoints.appServices}/$serviceId/labs',
        token: token,
        queryParams: (city != null && city.isNotEmpty) ? {'city': city} : null,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = data['data']?['labs'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'labs': list.map((e) => ServiceLab.fromJson(e as Map<String, dynamic>)).toList(),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load labs'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }
}
