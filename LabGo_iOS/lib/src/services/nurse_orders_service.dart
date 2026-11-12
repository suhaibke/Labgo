import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';
import 'order_service.dart';

/// Service for nurse-specific order operations
class NurseOrdersService {
  /// Get available confirmed orders for nurses to accept
  static Future<Map<String, dynamic>> getAvailableOrders({
    String status = 'confirmed',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getToken();

      final queryParams = <String, dynamic>{
        'status': status,
        'page': page,
        'limit': limit,
      };

      final response = await ApiService.get(
        '/nurse/orders/available-orders',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final ordersList = data['data']?['orders'] as List<dynamic>? ?? [];

        final List<Order> parsedOrders = ordersList
            .map((orderData) => Order.fromJson(orderData as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'orders': parsedOrders,
          'total': data['data']?['total'] ?? 0,
          'page': data['data']?['page'] ?? 1,
          'pages': data['data']?['pages'] ?? 1,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get available orders',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get orders assigned to this nurse
  static Future<Map<String, dynamic>> getMyOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getToken();

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await ApiService.get(
        '/nurse/orders/my-orders',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final ordersList = data['data']?['orders'] as List<dynamic>? ?? [];

        final List<Order> parsedOrders = ordersList
            .map((orderData) => Order.fromJson(orderData as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'orders': parsedOrders,
          'total': data['data']?['total'] ?? 0,
          'page': data['data']?['page'] ?? 1,
          'pages': data['data']?['pages'] ?? 1,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get orders',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get order details for nurse
  static Future<Map<String, dynamic>> getNurseOrderDetails(String orderId) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/orders/order/$orderId',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'order': Order.fromJson(data['data']?['order'] ?? data['data']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get order details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Accept/Confirm order (nurse accepts assignment)
  static Future<Map<String, dynamic>> acceptOrder(
    String orderId, {
    DateTime? estimatedArrival,
  }) async {
    try {
      final token = await AuthService().getToken();

      final body = <String, dynamic>{};
      if (estimatedArrival != null) {
        body['estimatedArrival'] = estimatedArrival.toIso8601String();
      }

      final response = await ApiService.post(
        '/nurse/orders/order/$orderId/accept',
        token: token,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Order accepted successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to accept order',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Update order status (nurse workflow actions)
  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status, {
    String? notes,
  }) async {
    try {
      final token = await AuthService().getToken();

      final body = <String, dynamic>{
        'status': status,
      };
      if (notes != null) {
        body['notes'] = notes;
      }

      final response = await ApiService.post(
        '/nurse/orders/order/$orderId/update-status',
        token: token,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Order status updated successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update order status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Add nurse notes to order
  static Future<Map<String, dynamic>> addNurseNotes(
    String orderId,
    String notes,
  ) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/nurse/orders/order/$orderId/notes',
        token: token,
        body: {'notes': notes},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Notes added successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add notes',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Scan patient's QR code to confirm sample collection
  static Future<Map<String, dynamic>> scanPatientQRCode(
    String orderId,
    String scannedQRCode,
  ) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/nurse/orders/order/$orderId/scan-qr',
        token: token,
        body: {'qrCode': scannedQRCode},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Sample collected successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to verify QR code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Cancel order (nurse releases order back to available)
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/nurse/orders/order/$orderId/cancel',
        token: token,
        body: {'reason': reason},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Order cancelled successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to cancel order',
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
