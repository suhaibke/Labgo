import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

class CouponService {
  /// Validates a coupon code against the given order total (no side
  /// effects - the server re-validates again for real at order creation).
  static Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required int orderTotal,
  }) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/orders/validate-coupon',
        token: token,
        body: {
          'code': code,
          'orderTotal': orderTotal,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final discountAmount = data['data']?['discountAmount'] is int
            ? data['data']['discountAmount']
            : int.tryParse(data['data']?['discountAmount']?.toString() ?? '0') ?? 0;
        final newTotal = data['data']?['newTotal'] is int
            ? data['data']['newTotal']
            : int.tryParse(data['data']?['newTotal']?.toString() ?? '0') ?? 0;
        return {
          'success': true,
          'discountAmount': discountAmount,
          'newTotal': newTotal,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'رمز القسيمة غير صالح',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ بالاتصال. حاول مرة أخرى.',
      };
    }
  }
}
