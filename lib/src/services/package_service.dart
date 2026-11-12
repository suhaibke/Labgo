import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

/// A lab-managed bundle of that lab's own tests sold at one combined price
/// (distinct from a discount [LabOffer]).
class Package {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameKu;
  final String? description;
  final String? descriptionAr;
  final String category;
  final int testCount;
  final int price;
  final String? icon;
  final bool isMostRequested;
  final String labId;
  final String labName;
  final String? labCity;
  final String? labLogo;
  final double? labAverageRating;

  Package({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameKu,
    this.description,
    this.descriptionAr,
    required this.category,
    required this.testCount,
    required this.price,
    this.icon,
    this.isMostRequested = false,
    required this.labId,
    required this.labName,
    this.labCity,
    this.labLogo,
    this.labAverageRating,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    final lab = json['lab'] as Map<String, dynamic>? ?? {};
    return Package(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      nameKu: json['nameKu']?.toString(),
      description: json['description']?.toString(),
      descriptionAr: json['descriptionAr']?.toString(),
      category: json['category']?.toString() ?? 'General',
      testCount: json['testCount'] is int
          ? json['testCount']
          : int.tryParse(json['testCount']?.toString() ?? '0') ?? 0,
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      icon: json['icon']?.toString(),
      isMostRequested: json['isMostRequested'] ?? false,
      labId: lab['_id']?.toString() ?? '',
      labName: lab['name']?.toString() ?? '',
      labCity: lab['city']?.toString(),
      labLogo: lab['logo']?.toString(),
      labAverageRating: lab['averageRating'] is num ? (lab['averageRating'] as num).toDouble() : null,
    );
  }

  /// Localized display name - falls back to the English name.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && (nameAr?.isNotEmpty ?? false)) return nameAr!;
    return name;
  }
}

/// A single test within a package's detail view.
class PackageTest {
  final String id;
  final String name;
  final String? nameAr;
  final int price;

  PackageTest({required this.id, required this.name, this.nameAr, required this.price});

  factory PackageTest.fromJson(Map<String, dynamic> json) {
    return PackageTest(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      price: json['price'] is int ? json['price'] : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Full package details, including its resolved constituent tests.
class PackageDetails extends Package {
  final List<PackageTest> tests;

  PackageDetails({
    required super.id,
    required super.name,
    super.nameAr,
    super.nameKu,
    super.description,
    super.descriptionAr,
    required super.category,
    required super.price,
    super.icon,
    super.isMostRequested,
    required super.labId,
    required super.labName,
    super.labCity,
    super.labLogo,
    super.labAverageRating,
    required this.tests,
  }) : super(testCount: tests.length);

  factory PackageDetails.fromJson(Map<String, dynamic> json) {
    final lab = json['lab'] as Map<String, dynamic>? ?? {};
    final testsList = (json['tests'] as List? ?? [])
        .map((t) => PackageTest.fromJson(Map<String, dynamic>.from(t)))
        .toList();
    return PackageDetails(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      nameKu: json['nameKu']?.toString(),
      description: json['description']?.toString(),
      descriptionAr: json['descriptionAr']?.toString(),
      category: json['category']?.toString() ?? 'General',
      price: json['price'] is int ? json['price'] : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      icon: json['icon']?.toString(),
      isMostRequested: json['isMostRequested'] ?? false,
      labId: lab['_id']?.toString() ?? '',
      labName: lab['name']?.toString() ?? '',
      labCity: lab['city']?.toString(),
      labLogo: lab['logo']?.toString(),
      labAverageRating: lab['averageRating'] is num ? (lab['averageRating'] as num).toDouble() : null,
      tests: testsList,
    );
  }
}

class PackageApi {
  static Future<Map<String, dynamic>> getPackages({
    String? search,
    String? category,
    String? city,
    String? labId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getToken();
      final query = <String, dynamic>{'page': page, 'limit': limit};
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (category != null && category.isNotEmpty) query['category'] = category;
      if (city != null && city.isNotEmpty) query['city'] = city;
      if (labId != null && labId.isNotEmpty) query['labId'] = labId;

      final response = await ApiService.get(ApiEndpoints.appPackages, token: token, queryParams: query);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = data['data']?['packages'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'packages': list.map((e) => Package.fromJson(e as Map<String, dynamic>)).toList(),
          'pagination': data['data']?['pagination'],
          'labCount': data['data']?['labCount'] ?? 0,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load packages'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> getPackageDetails(String id) async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.get('${ApiEndpoints.appPackages}/$id', token: token);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'package': PackageDetails.fromJson(data['data']['package'] as Map<String, dynamic>),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load package'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }
}
