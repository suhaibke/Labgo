import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

/// A catalog entry: an item name/category grouping how many units exist
/// and how many are currently available to request.
class CustodyCatalogEntry {
  final String name;
  final String category;
  final int total;
  final int available;

  CustodyCatalogEntry({
    required this.name,
    required this.category,
    required this.total,
    required this.available,
  });

  factory CustodyCatalogEntry.fromJson(Map<String, dynamic> json) {
    return CustodyCatalogEntry(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      total: json['total'] is num ? (json['total'] as num).toInt() : 0,
      available: json['available'] is num ? (json['available'] as num).toInt() : 0,
    );
  }
}

/// A nurse's custody request, tracking its lifecycle from submission
/// through approval, delivery, and return.
class CustodyRequestModel {
  final String id;
  final String itemName;
  final String? itemCode;
  final int requestedDurationDays;
  final String status;
  final DateTime? requestedAt;
  final DateTime? expectedReturnDate;
  final String? returnCode;
  final String? rejectionReason;

  CustodyRequestModel({
    required this.id,
    required this.itemName,
    this.itemCode,
    required this.requestedDurationDays,
    required this.status,
    this.requestedAt,
    this.expectedReturnDate,
    this.returnCode,
    this.rejectionReason,
  });

  factory CustodyRequestModel.fromJson(Map<String, dynamic> json) {
    final itemId = json['itemId'];
    return CustodyRequestModel(
      id: json['_id']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemCode: (itemId is Map) ? itemId['code']?.toString() : null,
      requestedDurationDays: json['requestedDurationDays'] is num
          ? (json['requestedDurationDays'] as num).toInt()
          : 0,
      status: json['status']?.toString() ?? 'pending',
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'].toString())
          : null,
      expectedReturnDate: json['expectedReturnDate'] != null
          ? DateTime.tryParse(json['expectedReturnDate'].toString())
          : null,
      returnCode: json['returnCode']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }
}

class CustodyService {
  /// Browse the custody catalog (item types with available counts).
  static Future<Map<String, dynamic>> getCatalog() async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.get(
        '${ApiEndpoints.nurseCustody}/catalog',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = data['data']?['catalog'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'catalog': list
              .map((e) => CustodyCatalogEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load catalog'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  /// Request a custody item, specifying how long it will be needed.
  static Future<Map<String, dynamic>> createRequest({
    required String itemName,
    required int requestedDurationDays,
    String? notes,
  }) async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.post(
        '${ApiEndpoints.nurseCustody}/requests',
        token: token,
        body: {
          'itemName': itemName,
          'requestedDurationDays': requestedDurationDays,
          if (notes != null) 'notes': notes,
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to submit request'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  /// Get the logged-in nurse's own custody requests.
  static Future<Map<String, dynamic>> getMyRequests() async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.get(
        '${ApiEndpoints.nurseCustody}/requests',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = data['data']?['requests'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'requests': list
              .map((e) => CustodyRequestModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to load requests'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  /// Initiate a return - the server generates a one-time code the nurse
  /// shows the admin (as a QR) to confirm the item is physically back.
  static Future<Map<String, dynamic>> initiateReturn(String requestId) async {
    try {
      final token = await AuthService().getToken();
      final response = await ApiService.post(
        '${ApiEndpoints.nurseCustody}/requests/$requestId/initiate-return',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final request = CustodyRequestModel.fromJson(
          data['data']['request'] as Map<String, dynamic>,
        );
        return {'success': true, 'request': request};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to initiate return'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }
}
