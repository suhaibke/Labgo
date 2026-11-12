import 'dart:convert';

import 'api_service.dart';

/// One admin-managed promotional slide shown at the top of the home page.
class HomeBanner {
  final String id;
  final String imageUrl;

  HomeBanner({required this.id, required this.imageUrl});

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['_id']?.toString() ?? '',
      imageUrl: ApiService.resolveMediaUrl(json['imageUrl']?.toString()) ?? '',
    );
  }
}

class BannerApi {
  static Future<Map<String, dynamic>> getBanners() async {
    try {
      final response = await ApiService.get(ApiEndpoints.appBanners);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['data']?['banners'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'banners': list.map((e) => HomeBanner.fromJson(e as Map<String, dynamic>)).toList(),
          'durationSeconds': (data['data']?['bannerDurationSeconds'] as num?)?.toInt() ?? 5,
        };
      }
      return {'success': false, 'banners': <HomeBanner>[], 'durationSeconds': 5};
    } catch (e) {
      return {'success': false, 'banners': <HomeBanner>[], 'durationSeconds': 5};
    }
  }
}
