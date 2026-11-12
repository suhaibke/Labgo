import 'dart:convert';
import 'package:intl/intl.dart';
import 'api_service.dart';

class LabService {
  // Get all labs
  static Future<Map<String, dynamic>> getAllLabs({
    String? token,
    Map<String, dynamic>? filters,
    String? search,
    String? city,
    String? specialization,
  }) async {
    try {
      // Build query params
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        queryParams.addAll(filters);
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }
      if (specialization != null && specialization.isNotEmpty) {
        queryParams['specialization'] = specialization;
      }

      final response = await ApiService.get(
        ApiEndpoints.labs,
        token: token,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Handle response format { success: true, data: { labs: [], pagination: {} } }
        if (data['success'] == true && data['data'] != null) {
          final dataMap = data['data'] as Map;
          return {
            'success': true,
            'data': dataMap,
            'labs': dataMap['labs'] ?? [],
            'pagination': dataMap['pagination'],
          };
        }
        // Handle legacy format
        return {
          'success': true,
          'labs': data['data'] ?? data['labs'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load labs',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Get lab details
  static Future<Map<String, dynamic>> getLabDetails({
    required String labId,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '${ApiEndpoints.labDetails}/$labId',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'lab': data['data'] ?? data['lab'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load lab details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Get labs with active offers
  static Future<Map<String, dynamic>> getLabsWithOffers({
    String? token,
    String? city,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      final response = await ApiService.get(
        '${ApiEndpoints.labs}/offers/active',
        token: token,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final dataMap = data['data'] as Map?;
        return {
          'success': true,
          'labs': dataMap?['labs'] ?? [],
          'count': dataMap?['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load labs with offers',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Get featured labs (selected by admin)
  static Future<Map<String, dynamic>> getFeaturedLabs({
    String? token,
    int limit = 10,
    String? city,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city;
      }

      final response = await ApiService.get(
        '${ApiEndpoints.labs}/featured',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final dataMap = data['data'] as Map?;
        return {
          'success': true,
          'labs': dataMap?['labs'] ?? [],
          'count': dataMap?['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load featured labs',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  // Get offers for a specific lab
  static Future<Map<String, dynamic>> getLabOffers({
    required String labId,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '${ApiEndpoints.labDetails}/$labId/offers',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final dataMap = data['data'] as Map?;
        return {
          'success': true,
          'offers': dataMap?['offers'] ?? [],
          'labName': dataMap?['labName'],
          'count': dataMap?['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load lab offers',
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

class LabTest {
  final String id;
  final String name;
  final String? nameAr;
  final String code;
  final int price;
  final String? description;
  final String? instructions;
  final String? category;
  final String? image;

  LabTest({
    required this.id,
    required this.name,
    this.nameAr,
    required this.code,
    required this.price,
    this.description,
    this.instructions,
    this.category,
    this.image,
  });

  factory LabTest.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('/')) {
        imageUrl = '${ApiService.baseUrl}$imageUrl';
      } else if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiService.baseUrl}/$imageUrl';
      }
    } else {
      imageUrl = null;
    }

    return LabTest(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      code: json['code']?.toString() ?? '',
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
      category: json['category']?.toString(),
      image: imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'nameAr': nameAr,
      'code': code,
      'price': price,
      'description': description,
      'instructions': instructions,
      'category': category,
      'image': image,
    };
  }

  String get arabicName {
    final ar = nameAr?.trim() ?? '';
    if (ar.isNotEmpty) return ar;
    return name.trim();
  }

  String get englishName => name.trim();

  bool get hasEnglishSubtitle {
    final en = englishName;
    return en.isNotEmpty && en.toLowerCase() != arabicName.toLowerCase();
  }

  bool get hasImage => image != null && image!.isNotEmpty;

  // Format price for display (IQD with thousand separators)
  String get formattedPrice {
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(price)} IQD';
  }
}

// Offer model for lab discounts
class LabOffer {
  final String id;
  final String name;
  final String? nameAr;
  final String? nameKu;
  final String label;
  final String? labelAr;
  final String? labelKu;
  final String? description;
  final String? descriptionAr;
  final String? descriptionKu;
  final String discountType; // 'percentage' or 'fixed'
  final int discountValue;
  final bool applyToAllTests;
  final List<ApplicableTest>? applicableTests;
  final int minOrderAmount;
  final int maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool isStarred;
  final DateTime? starredAt;

  LabOffer({
    required this.id,
    required this.name,
    this.nameAr,
    this.nameKu,
    required this.label,
    this.labelAr,
    this.labelKu,
    this.description,
    this.descriptionAr,
    this.descriptionKu,
    required this.discountType,
    required this.discountValue,
    this.applyToAllTests = false,
    this.applicableTests,
    this.minOrderAmount = 0,
    this.maxDiscount = 0,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.isStarred = false,
    this.starredAt,
  });

  factory LabOffer.fromJson(Map<String, dynamic> json) {
    return LabOffer(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      nameKu: json['nameKu']?.toString(),
      label: json['label']?.toString() ?? '',
      labelAr: json['labelAr']?.toString(),
      labelKu: json['labelKu']?.toString(),
      description: json['description']?.toString(),
      descriptionAr: json['descriptionAr']?.toString(),
      descriptionKu: json['descriptionKu']?.toString(),
      discountType: json['discountType']?.toString() ?? 'percentage',
      discountValue: json['discountValue'] is int
          ? json['discountValue']
          : int.tryParse(json['discountValue']?.toString() ?? '0') ?? 0,
      applyToAllTests: json['applyToAllTests'] ?? false,
      applicableTests: json['applicableTests'] != null
          ? (json['applicableTests'] as List)
              .map((t) => ApplicableTest.fromJson(Map<String, dynamic>.from(t)))
              .toList()
          : null,
      minOrderAmount: json['minOrderAmount'] is int
          ? json['minOrderAmount']
          : int.tryParse(json['minOrderAmount']?.toString() ?? '0') ?? 0,
      maxDiscount: json['maxDiscount'] is int
          ? json['maxDiscount']
          : int.tryParse(json['maxDiscount']?.toString() ?? '0') ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      isActive: json['isActive'] ?? true,
      isStarred: json['isStarred'] ?? false,
      starredAt: json['starredAt'] != null
          ? DateTime.tryParse(json['starredAt'].toString())
          : null,
    );
  }

  // Get localized name based on locale
  String getLocalizedName(String locale) {
    if (locale == 'ar' && nameAr != null && nameAr!.isNotEmpty) return nameAr!;
    if (locale == 'ku' && nameKu != null && nameKu!.isNotEmpty) return nameKu!;
    return name;
  }

  // Get localized label
  String getLocalizedLabel(String locale) {
    if (locale == 'ar' && labelAr != null && labelAr!.isNotEmpty) return labelAr!;
    if (locale == 'ku' && labelKu != null && labelKu!.isNotEmpty) return labelKu!;
    return label;
  }

  // Get localized description
  String? getLocalizedDescription(String locale) {
    if (locale == 'ar' && descriptionAr != null && descriptionAr!.isNotEmpty) return descriptionAr;
    if (locale == 'ku' && descriptionKu != null && descriptionKu!.isNotEmpty) return descriptionKu;
    return description;
  }

  // Calculate discounted price (uses global discount - for backward compatibility)
  int calculateDiscountedPrice(int originalPrice) {
    if (discountType == 'percentage') {
      final discount = (originalPrice * discountValue / 100).round();
      final actualDiscount = maxDiscount > 0 && discount > maxDiscount ? maxDiscount : discount;
      return originalPrice - actualDiscount;
    } else {
      return originalPrice - discountValue;
    }
  }

  // Calculate discounted price for a specific test (with per-test discount support)
  int calculateDiscountedPriceForTest(int originalPrice, String testId, String testCode) {
    // If applyToAllTests, use global discount
    if (applyToAllTests) {
      return calculateDiscountedPrice(originalPrice);
    }
    
    // Find specific test discount
    if (applicableTests != null && applicableTests!.isNotEmpty) {
      final testDiscount = applicableTests!.firstWhere(
        (t) => t.testId == testId || t.testCode == testCode,
        orElse: () => ApplicableTest(discountValue: discountValue.toDouble(), discountType: discountType),
      );
      
      final discType = testDiscount.discountType ?? discountType;
      final discValue = testDiscount.discountValue ?? discountValue.toDouble();
      
      if (discType == 'percentage') {
        final discount = (originalPrice * discValue / 100).round();
        final actualDiscount = maxDiscount > 0 && discount > maxDiscount ? maxDiscount : discount;
        return originalPrice - actualDiscount;
      } else {
        return (originalPrice - discValue).toInt();
      }
    }
    
    return calculateDiscountedPrice(originalPrice);
  }

  // Get discount value for a specific test
  double getDiscountValueForTest(String testId, String testCode) {
    if (applyToAllTests) return discountValue.toDouble();
    if (applicableTests == null || applicableTests!.isEmpty) return discountValue.toDouble();
    
    final testDiscount = applicableTests!.firstWhere(
      (t) => t.testId == testId || t.testCode == testCode,
      orElse: () => ApplicableTest(discountValue: discountValue.toDouble()),
    );
    
    return testDiscount.discountValue ?? discountValue.toDouble();
  }

  // Get discount type for a specific test
  String getDiscountTypeForTest(String testId, String testCode) {
    if (applyToAllTests) return discountType;
    if (applicableTests == null || applicableTests!.isEmpty) return discountType;
    
    final testDiscount = applicableTests!.firstWhere(
      (t) => t.testId == testId || t.testCode == testCode,
      orElse: () => ApplicableTest(discountType: discountType),
    );
    
    return testDiscount.discountType ?? discountType;
  }

  // Get formatted discount text
  String get formattedDiscount {
    if (discountType == 'percentage') {
      return '$discountValue%';
    } else {
      final formatter = NumberFormat('#,###', 'en_US');
      return '${formatter.format(discountValue)} IQD';
    }
  }

  // Check if offer is valid (active and within date range)
  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  // Check if offer applies to a specific test
  bool appliesToTest(String testId, String testCode) {
    if (applyToAllTests) return true;
    if (applicableTests == null || applicableTests!.isEmpty) return true;
    return applicableTests!.any((t) => t.testId == testId || t.testCode == testCode);
  }
}

class ApplicableTest {
  final String? testId;
  final String? testCode;
  final String? discountType;
  final double? discountValue;

  ApplicableTest({
    this.testId, 
    this.testCode, 
    this.discountType,
    this.discountValue,
  });

  factory ApplicableTest.fromJson(Map<String, dynamic> json) {
    return ApplicableTest(
      testId: json['testId']?.toString(),
      testCode: json['testCode']?.toString(),
      discountType: json['discountType']?.toString() ?? 'percentage',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Lab {
  final String id;
  final String name;
  final String? logo;
  final String? coverImage;
  final String? city;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? specialization;
  final List<String>? tests; // Deprecated - Use testObjects instead
  final List<LabTest>? testObjects;
  final List<LabOffer>? offers;
  final List<LabOffer>? activeOffers; // Pre-filtered active offers from API
  final int? offerCount;
  final int? bestDiscount;
  final int? totalPatientsServed;
  final int? totalTestsPerformed;
  final double? averageRating;
  final int? totalReviews;
  final bool? isVerified;
  final String? status;
  final String? address;
  final String? description;
  final double? latitude;
  final double? longitude;

  Lab({
    required this.id,
    required this.name,
    this.logo,
    this.coverImage,
    this.city,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.specialization,
    this.tests,
    this.testObjects,
    this.offers,
    this.activeOffers,
    this.offerCount,
    this.bestDiscount,
    this.totalPatientsServed,
    this.totalTestsPerformed,
    this.averageRating,
    this.totalReviews,
    this.isVerified,
    this.status,
    this.address,
    this.description,
    this.latitude,
    this.longitude,
  });

  factory Lab.fromJson(Map<String, dynamic> json) {
    // Handle tests array - extract test names if available (legacy support)
    List<String>? testList;
    if (json['tests'] != null) {
      if (json['tests'] is List) {
        testList = (json['tests'] as List)
            .map((test) => test is String ? test : test['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }

    // Handle test objects with full details
    List<LabTest>? testObjectList;
    if (json['tests'] != null && json['tests'] is List) {
      testObjectList = (json['tests'] as List)
          .map((test) => test is Map ? LabTest.fromJson(Map<String, dynamic>.from(test)) : null)
          .whereType<LabTest>()
          .toList();
    }

    // Handle logo URL - convert relative path to full URL if needed
    String? logoUrl = json['logo']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      // If logo is a relative path starting with /, prepend the base URL
      if (logoUrl.startsWith('/')) {
        logoUrl = '${ApiService.baseUrl}$logoUrl';
      }
      // If logo doesn't start with http, prepend the base URL
      else if (!logoUrl.startsWith('http')) {
        logoUrl = '${ApiService.baseUrl}/$logoUrl';
      }
    }

    // Handle offers array
    List<LabOffer>? offersList;
    if (json['offers'] != null && json['offers'] is List) {
      offersList = (json['offers'] as List)
          .map((offer) => offer is Map ? LabOffer.fromJson(Map<String, dynamic>.from(offer)) : null)
          .whereType<LabOffer>()
          .toList();
    }

    // Handle activeOffers array (from offers/active endpoint)
    List<LabOffer>? activeOffersList;
    if (json['activeOffers'] != null && json['activeOffers'] is List) {
      activeOffersList = (json['activeOffers'] as List)
          .map((offer) => offer is Map ? LabOffer.fromJson(Map<String, dynamic>.from(offer)) : null)
          .whereType<LabOffer>()
          .toList();
    }

    return Lab(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: logoUrl,
      coverImage: ApiService.resolveMediaUrl(json['coverImage']?.toString()),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      specialization: json['specialization']?.toString(),
      tests: testList,
      testObjects: testObjectList,
      offers: offersList,
      activeOffers: activeOffersList,
      offerCount: json['offerCount'] is int
          ? json['offerCount']
          : int.tryParse(json['offerCount']?.toString() ?? '0'),
      bestDiscount: json['bestDiscount'] is int
          ? json['bestDiscount']
          : int.tryParse(json['bestDiscount']?.toString() ?? '0'),
      totalPatientsServed: json['totalPatientsServed'] is int
          ? json['totalPatientsServed']
          : int.tryParse(json['totalPatientsServed']?.toString() ?? '0'),
      totalTestsPerformed: json['totalTestsPerformed'] is int
          ? json['totalTestsPerformed']
          : int.tryParse(json['totalTestsPerformed']?.toString() ?? '0'),
      averageRating: json['averageRating'] is double
          ? json['averageRating']
          : double.tryParse(json['averageRating']?.toString() ?? '0.0'),
      totalReviews: json['totalReviews'] is int
          ? json['totalReviews']
          : int.tryParse(json['totalReviews']?.toString() ?? '0'),
      isVerified: json['isVerified'] ?? json['verified'] ?? false,
      status: json['status']?.toString(),
      address: json['address']?.toString(),
      description: json['description']?.toString(),
      latitude: json['coordinates'] is Map
          ? double.tryParse(json['coordinates']['latitude']?.toString() ?? '')
          : null,
      longitude: json['coordinates'] is Map
          ? double.tryParse(json['coordinates']['longitude']?.toString() ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'logo': logo,
      'city': city,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'specialization': specialization,
      'tests': tests,
      'testObjects': testObjects?.map((t) => t.toJson()).toList(),
      'offers': offers,
      'activeOffers': activeOffers,
      'offerCount': offerCount,
      'bestDiscount': bestDiscount,
      'totalPatientsServed': totalPatientsServed,
      'totalTestsPerformed': totalTestsPerformed,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'isVerified': isVerified,
      'status': status,
      'address': address,
      'description': description,
    };
  }

  // Check if lab has any active offers
  bool get hasActiveOffers {
    if (activeOffers != null && activeOffers!.isNotEmpty) return true;
    if (offerCount != null && offerCount! > 0) return true;
    if (offers != null) {
      return offers!.any((o) => o.isValid);
    }
    return false;
  }

  // Get valid offers
  List<LabOffer> get validOffers {
    if (activeOffers != null && activeOffers!.isNotEmpty) return activeOffers!;
    if (offers != null) {
      return offers!.where((o) => o.isValid).toList();
    }
    return [];
  }

  // Get best offer label to display
  String? get bestOfferLabel {
    final valid = validOffers;
    if (valid.isEmpty) return null;
    // Return the offer with highest percentage discount
    final best = valid.reduce((a, b) {
      if (a.discountType == 'percentage' && b.discountType == 'percentage') {
        return a.discountValue > b.discountValue ? a : b;
      }
      return a.discountType == 'percentage' ? a : b;
    });
    return best.label.isNotEmpty ? best.label : best.formattedDiscount;
  }

  // Get full address
  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isNotEmpty ? parts.join(', ') : 'Address not available';
  }

  // Get rating stars
  List<bool> get ratingStars {
    if (averageRating == null) return [false, false, false, false, false];

    final fullStars = averageRating!.floor();
    final hasHalfStar = (averageRating! - fullStars) >= 0.5;

    final stars = <bool>[];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(true);
      } else if (i == fullStars && hasHalfStar) {
        stars.add(true);
      } else {
        stars.add(false);
      }
    }
    return stars;
  }

  // Get display logo - returns either the URL or a default asset path
  String? get displayLogo {
    if (logo != null && logo!.isNotEmpty) {
      return logo;
    }
    return null; // Return null to use default icon fallback
  }

  // Check if lab has a valid logo
  bool get hasValidLogo => logo != null && logo!.isNotEmpty;
  bool get hasValidCoverImage => coverImage != null && coverImage!.isNotEmpty;

  // Check if lab has valid map coordinates
  bool get hasCoordinates => latitude != null && longitude != null;

  // Format test count
  String get testCountDisplay {
    if (tests == null) return '0 Tests';
    final count = tests!.length;
    return '$count Test${count == 1 ? '' : 's'}';
  }
}
