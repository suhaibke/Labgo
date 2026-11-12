import 'dart:convert';
import 'api_service.dart';
import 'auth_service.dart';

class CartService {
  // Cart item model
  static CartItem fromJson(Map<String, dynamic> json) {
    return CartItem(
      testId: json['testId']?.toString() ?? '',
      testName: json['testName']?.toString() ?? '',
      testCode: json['testCode']?.toString() ?? '',
      category: json['category']?.toString(),
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price']?.toString() ?? '0') ?? 0,
      originalPrice: json['originalPrice'] is int
          ? json['originalPrice']
          : int.tryParse(json['originalPrice']?.toString() ?? ''),
      packageId: json['packageId']?.toString(),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'].toString())
          : null,
    );
  }

  // Cart model
  static Cart fromCartJson(Map<String, dynamic> json) {
    final testsList = json['tests'] as List?;
    final tests = testsList
        ?.map((item) => fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    return Cart(
      labId: json['labId']?.toString(),
      tests: tests,
      prescriptionImage: json['prescriptionImage']?.toString(),
      totalPrice: json['totalPrice'] is int
          ? json['totalPrice']
          : int.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
    );
  }

  /// Add test to cart
  /// [labId] - The lab ID where the test belongs
  /// [testId] - The test ID to add
  /// [discountedPrice] - Optional discounted price to use instead of original
  static Future<Map<String, dynamic>> addToCart({
    required String labId,
    required String testId,
    int? discountedPrice,
  }) async {
    try {
      final token = await AuthService().getToken();

      final body = {
        'labId': labId,
        'testId': testId,
      };
      
      // Add discounted price if provided
      if (discountedPrice != null) {
        body['discountedPrice'] = discountedPrice.toString();
      }

      final response = await ApiService.post(
        '/cart/add',
        token: token,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Test added to cart',
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add test to cart',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Add a whole Package (bundle of a lab's tests) to cart, priced at the
  /// package's combined price rather than the sum of individual test prices.
  static Future<Map<String, dynamic>> addPackage({
    required String labId,
    required String packageId,
  }) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/cart/add-package',
        token: token,
        body: {
          'labId': labId,
          'packageId': packageId,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Package added to cart',
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add package to cart',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Remove test from cart
  /// [testId] - The test ID to remove
  static Future<Map<String, dynamic>> removeFromCart({
    required String testId,
  }) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.delete(
        '/cart/remove/$testId',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Test removed from cart',
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to remove test from cart',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get cart contents
  static Future<Map<String, dynamic>> getCart() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/cart/',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get cart',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Clear entire cart
  static Future<Map<String, dynamic>> clearCart() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.delete(
        '/cart/clear',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Cart cleared',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to clear cart',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Set prescription image in cart
  /// [imageUrl] - The URL of the uploaded prescription image
  static Future<Map<String, dynamic>> setPrescription({
    required String imageUrl,
  }) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/cart/prescription',
        token: token,
        body: {
          'imageUrl': imageUrl,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Prescription added to cart',
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add prescription',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Remove prescription image from cart
  static Future<Map<String, dynamic>> removePrescription() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.delete(
        '/cart/prescription',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Prescription removed from cart',
          'cart': data['data'] != null
              ? fromCartJson(data['data']['cart'] ?? data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to remove prescription',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Check if a specific test is in the cart
  /// [testId] - The test ID to check
  static Future<bool> isTestInCart(String testId) async {
    try {
      final result = await getCart();
      if (result['success'] == true && result['cart'] != null) {
        final cart = result['cart'] as Cart;
        return cart.tests.any((test) => test.testId == testId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// Cart model class
class Cart {
  final String? labId;
  final List<CartItem> tests;
  final String? prescriptionImage;
  final int totalPrice;
  final DateTime? lastUpdated;

  Cart({
    this.labId,
    this.tests = const [],
    this.prescriptionImage,
    this.totalPrice = 0,
    this.lastUpdated,
  });

  int get testCount => tests.length;

  bool get hasPrescription => prescriptionImage != null && prescriptionImage!.isNotEmpty;

  bool get isEmpty => tests.isEmpty;
}

// Cart item model class
class CartItem {
  final String testId;
  final String testName;
  final String testCode;
  final String? category;
  final int price;
  final int? originalPrice; // Original price before discount (if discounted)
  final String? packageId; // Set when this item is part of a Package bundle
  final DateTime? addedAt;

  CartItem({
    required this.testId,
    required this.testName,
    required this.testCode,
    this.category,
    required this.price,
    this.originalPrice,
    this.packageId,
    this.addedAt,
  });

  bool get isPartOfPackage => packageId != null && packageId!.isNotEmpty;

  // Check if item has a discount applied
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  
  // Get discount percentage
  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'testName': testName,
      'testCode': testCode,
      'category': category,
      'price': price,
      'originalPrice': originalPrice,
      'packageId': packageId,
      'addedAt': addedAt?.toIso8601String(),
    };
  }

  String get formattedPrice {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }
  
  String get formattedOriginalPrice {
    if (originalPrice == null) return formattedPrice;
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return originalPrice.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }
}
