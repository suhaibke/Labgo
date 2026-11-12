import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_service.dart';

// Order models
class OrderLocation {
  final String address;
  final String? landmark;
  final double latitude;
  final double longitude;
  final String? buildingName;
  final String? floorNumber;
  final String? apartmentNumber;
  final String? instructions;
  final String? phone;

  OrderLocation({
    required this.address,
    this.landmark,
    required this.latitude,
    required this.longitude,
    this.buildingName,
    this.floorNumber,
    this.apartmentNumber,
    this.instructions,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      if (landmark != null) 'landmark': landmark,
      'coordinates': {
        'latitude': latitude,
        'longitude': longitude,
      },
      if (buildingName != null) 'buildingName': buildingName,
      if (floorNumber != null) 'floorNumber': floorNumber,
      if (apartmentNumber != null) 'apartmentNumber': apartmentNumber,
      if (phone != null) 'phone': phone,
      if (instructions != null) 'instructions': instructions,
    };
  }
}

class OrderTest {
  final String testId;
  final String testName;
  final String testCode;
  final String? category;
  final int price;

  OrderTest({
    required this.testId,
    required this.testName,
    required this.testCode,
    this.category,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'testName': testName,
      'testCode': testCode,
      if (category != null) 'category': category,
      'price': price,
    };
  }
}

/// Order financial breakdown
class OrderFinancials {
  final double commissionRate;
  final double adminCommission;
  final double labAmount;
  final double nurseEarning;
  final bool labSettled;
  final String? labSettledAt;

  OrderFinancials({
    required this.commissionRate,
    required this.adminCommission,
    required this.labAmount,
    required this.nurseEarning,
    this.labSettled = false,
    this.labSettledAt,
  });

  factory OrderFinancials.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return OrderFinancials(
        commissionRate: 0,
        adminCommission: 0,
        labAmount: 0,
        nurseEarning: 0,
      );
    }
    return OrderFinancials(
      commissionRate: (json['commissionRate'] ?? 0).toDouble(),
      adminCommission: (json['adminCommission'] ?? 0).toDouble(),
      labAmount: (json['labAmount'] ?? 0).toDouble(),
      nurseEarning: (json['nurseEarning'] ?? 0).toDouble(),
      labSettled: json['labSettled'] ?? false,
      labSettledAt: json['labSettledAt']?.toString(),
    );
  }
}

class Order {
  final String id;
  final String patientId;
  final String labId;
  final Map<String, dynamic>? labData;
  final String? nurseId;
  final Map<String, dynamic>? nurseData;
  final Map<String, dynamic>? patientData;
  final Map<String, dynamic>? nurseMapLocation;
  final Map<String, dynamic>? beneficiary; // Beneficiary info when ordering for another person
  final List<OrderTest> tests;
  final String? prescriptionImage;
  final String qrCode;
  final OrderLocation location;
  final String status;
  final String orderType;
  final int totalPrice;
  final String paymentStatus;
  final DateTime? scheduledDate;
  final Map<String, dynamic>? timeSlot;
  final DateTime createdAt;
  final Map<String, dynamic>? adminConfirmation;
  final Map<String, dynamic>? nurseAssignment;
  final Map<String, dynamic>? paymentCollected;
  final List<dynamic>? statusHistory;
  final Map<String, dynamic>? results;
  final Map<String, dynamic>? cancellation;
  final Map<String, dynamic>? notes;
  final Map<String, dynamic>? notifications;
  final Map<String, dynamic>? rating;
  final OrderFinancials? financials;
  final String orderCategory;
  final String prescriptionType;
  final Map<String, dynamic>? prescriptionQuote;

  bool get isMedicineOrder =>
      orderCategory == 'prescription' && prescriptionType == 'medicine';

  Order({
    required this.id,
    required this.patientId,
    required this.labId,
    this.labData,
    this.nurseId,
    this.nurseData,
    this.patientData,
    this.nurseMapLocation,
    this.beneficiary,
    required this.tests,
    this.prescriptionImage,
    required this.qrCode,
    required this.location,
    required this.status,
    required this.orderType,
    required this.totalPrice,
    required this.paymentStatus,
    this.scheduledDate,
    this.timeSlot,
    required this.createdAt,
    this.adminConfirmation,
    this.nurseAssignment,
    this.paymentCollected,
    this.statusHistory,
    this.results,
    this.cancellation,
    this.notes,
    this.notifications,
    this.rating,
    this.financials,
    this.orderCategory = 'test',
    this.prescriptionType = 'lab_test',
    this.prescriptionQuote,
  });

  // Helper function to extract string value from MongoDB extended JSON
  static String _extractString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      // Handle MongoDB $oid format
      if (value.containsKey('\$oid')) return value['\$oid']?.toString() ?? '';
      // Handle other string-like objects
      return value.toString();
    }
    return value.toString();
  }

  // Helper function to extract DateTime from MongoDB extended JSON
  static DateTime? _extractDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      // Handle MongoDB $date format
      if (value.containsKey('\$date')) {
        final dateVal = value['\$date'];
        if (dateVal is String) return DateTime.tryParse(dateVal);
      }
    }
    return null;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle populated fields (MongoDB populate returns objects, not just IDs)
    final patientIdField = json['patientId'];
    final labIdField = json['labId'];
    final nurseIdField = json['nurseId'];

    return Order(
      id: _extractString(json['_id']),
      patientId: _extractString(patientIdField is Map && patientIdField.containsKey('_id')
          ? patientIdField['_id']
          : patientIdField),
      labId: _extractString(labIdField is Map && labIdField.containsKey('_id')
          ? labIdField['_id']
          : labIdField),
      labData: labIdField is Map && !labIdField.containsKey('\$oid')
          ? Map<String, dynamic>.from(labIdField)
          : null,
      patientData: patientIdField is Map && !patientIdField.containsKey('\$oid')
          ? Map<String, dynamic>.from(patientIdField)
          : null,
      nurseId: nurseIdField != null
          ? _extractString(nurseIdField is Map && nurseIdField.containsKey('_id')
              ? nurseIdField['_id']
              : nurseIdField)
          : null,
      nurseData: nurseIdField is Map && !nurseIdField.containsKey('\$oid')
          ? Map<String, dynamic>.from(nurseIdField)
          : null,
      nurseMapLocation: json['nurseMapLocation'] is Map
          ? Map<String, dynamic>.from(json['nurseMapLocation'] as Map)
          : null,
      beneficiary: json['beneficiary'] is Map
          ? Map<String, dynamic>.from(json['beneficiary'])
          : null,
      tests: json['tests'] is List
          ? (json['tests'] as List)
              .map((t) {
                if (t is! Map) return OrderTest(
                  testId: '',
                  testName: t?.toString() ?? '',
                  testCode: '',
                  price: 0,
                );
                return OrderTest(
                  testId: _extractString(t['testId'] ?? t['_id']),
                  testName: t['testName']?.toString() ?? '',
                  testCode: t['testCode']?.toString() ?? '',
                  category: t['category']?.toString(),
                  price: t['price'] is int
                      ? t['price'] as int
                      : int.tryParse(t['price']?.toString() ?? '0') ?? 0,
                );
              })
              .toList()
          : [],
      prescriptionImage: json['prescriptionImage']?.toString(),
      qrCode: json['qrCode']?.toString() ?? '',
      location: OrderLocation(
        address: json['location'] is Map
            ? (json['location']['address']?.toString() ?? '')
            : '',
        landmark: json['location'] is Map
            ? json['location']['landmark']?.toString()
            : null,
        latitude: json['location'] is Map && json['location']['coordinates'] is Map
            ? (json['location']['coordinates']['latitude'] is num
                ? (json['location']['coordinates']['latitude'] as num).toDouble()
                : double.tryParse(json['location']['coordinates']['latitude']?.toString() ?? '') ?? 0.0)
            : 0.0,
        longitude: json['location'] is Map && json['location']['coordinates'] is Map
            ? (json['location']['coordinates']['longitude'] is num
                ? (json['location']['coordinates']['longitude'] as num).toDouble()
                : double.tryParse(json['location']['coordinates']['longitude']?.toString() ?? '') ?? 0.0)
            : 0.0,
        buildingName: json['location'] is Map
            ? json['location']['buildingName']?.toString()
            : null,
        floorNumber: json['location'] is Map
            ? json['location']['floorNumber']?.toString()
            : null,
        apartmentNumber: json['location'] is Map
            ? json['location']['apartmentNumber']?.toString()
            : null,
        instructions: json['location'] is Map
            ? json['location']['instructions']?.toString()
            : null,
        phone: json['location'] is Map
            ? json['location']['phone']?.toString()
            : null,
      ),
      status: json['status']?.toString() ?? 'pending',
      orderType: json['orderType']?.toString() ?? 'home_collection',
      totalPrice: json['pricing'] is Map && json['pricing']['total'] != null
          ? (json['pricing']['total'] is int
              ? json['pricing']['total'] as int
              : int.tryParse(json['pricing']['total']?.toString() ?? '0') ?? 0)
          : (json['prescriptionQuote'] is Map && json['prescriptionQuote']['price'] != null
              ? (json['prescriptionQuote']['price'] is int
                  ? json['prescriptionQuote']['price'] as int
                  : int.tryParse(json['prescriptionQuote']['price']?.toString() ?? '0') ?? 0)
              : 0),
      paymentStatus: json['payment'] is Map
          ? json['payment']['status']?.toString() ?? 'pending'
          : 'pending',
      scheduledDate: _extractDateTime(json['scheduledDate']),
      timeSlot: json['timeSlot'] is Map ? json['timeSlot'] as Map<String, dynamic> : null,
      createdAt: _extractDateTime(json['createdAt']) ?? DateTime.now(),
      adminConfirmation: json['adminConfirmation'] is Map ? json['adminConfirmation'] as Map<String, dynamic> : null,
      nurseAssignment: json['nurseAssignment'] is Map ? json['nurseAssignment'] as Map<String, dynamic> : null,
      paymentCollected: json['paymentCollected'] is Map ? json['paymentCollected'] as Map<String, dynamic> : null,
      statusHistory: json['statusHistory'] is List ? json['statusHistory'] as List<dynamic> : null,
      results: json['results'] is Map ? json['results'] as Map<String, dynamic> : null,
      cancellation: json['cancellation'] is Map ? json['cancellation'] as Map<String, dynamic> : null,
      orderCategory: json['orderCategory']?.toString() ?? 'test',
      prescriptionType: json['prescriptionType']?.toString() ?? 'lab_test',
      prescriptionQuote: json['prescriptionQuote'] is Map ? json['prescriptionQuote'] as Map<String, dynamic> : null,
      notes: json['notes'] is Map ? json['notes'] as Map<String, dynamic> : null,
      notifications: json['notifications'] is Map ? json['notifications'] as Map<String, dynamic> : null,
      rating: json['rating'] is Map ? json['rating'] as Map<String, dynamic> : null,
      financials: json['financials'] is Map ? OrderFinancials.fromJson(json['financials'] as Map<String, dynamic>) : null,
    );
  }

  bool get isConfirmed => adminConfirmation?['confirmed'] == true;
  bool get isPending => status == 'pending';
  bool get isConfirmedStatus => status == 'confirmed';
  bool get isNurseAssigned => status == 'nurse_assigned';
  bool get isSampleCollected => status == 'sample_collected';
  bool get isAtLab => status == 'at_lab';
  bool get isCompleted => status == 'completed';

  bool get hasSentResult {
    final url = results?['reportUrl']?.toString().trim();
    return url != null && url.isNotEmpty;
  }

  String? get reportUrl {
    final url = results?['reportUrl']?.toString().trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }
  bool get isCancelled => status == 'cancelled';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'pending';
      case 'confirmed':
        return 'confirmed';
      case 'nurse_assigned':
        return 'nurseAssigned';
      case 'sample_collected':
        return 'sampleCollected';
      case 'at_lab':
        return 'atLab';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return status;
    }
  }

  String get formattedTotalPrice {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return totalPrice.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  // Helper: Check if order is for another person
  bool get isForOtherPerson => beneficiary?['isForOtherPerson'] == true;

  // Helper: Get beneficiary name (or null if ordering for self)
  String? get beneficiaryName {
    if (!isForOtherPerson) return null;
    return beneficiary?['name']?.toString();
  }

  // Helper: Get beneficiary phone (or null if ordering for self)
  String? get beneficiaryPhone {
    if (!isForOtherPerson) return null;
    return beneficiary?['phone']?.toString();
  }
}

class OrderService {
  /// Create a new order from cart
  static Future<Map<String, dynamic>> createOrder({
    required OrderLocation location,
    File? prescriptionImage,
    String? scheduledDate,
    Map<String, String>? timeSlot,
    String? patientNotes,
    String? labId,
    bool prescriptionOnly = false,
    Map<String, dynamic>? beneficiary,
    String? couponCode,
  }) async {
    try {
      final token = await AuthService().getToken();

      final body = {
        'location': location.toJson(),
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (timeSlot != null) 'timeSlot': timeSlot,
        'orderType': 'home_collection',
        if (patientNotes != null) 'patientNotes': patientNotes,
        if (labId != null) 'labId': labId,
        'prescriptionOnly': prescriptionOnly.toString(),
        if (beneficiary != null) 'beneficiary': beneficiary,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      };

      // If prescription image is provided OR it's a prescription-only order, use multipart
      if (prescriptionImage != null || prescriptionOnly) {
        final response = await ApiService.multipart(
          '/orders/create',
          token: token,
          fields: {
            'location': jsonEncode(location.toJson()),
            if (scheduledDate != null) 'scheduledDate': scheduledDate,
            if (timeSlot != null) 'timeSlot': jsonEncode(timeSlot),
            'orderType': 'home_collection',
            if (patientNotes != null) 'patientNotes': patientNotes,
            if (labId != null) 'labId': labId,
            'prescriptionOnly': prescriptionOnly.toString(),
            if (beneficiary != null) 'beneficiary': jsonEncode(beneficiary),
            if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          },
          files: prescriptionImage != null
              ? {'prescription': await http.MultipartFile.fromPath(
                  'prescription',
                  prescriptionImage.path,
                )}
              : {},
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 201 || response.statusCode == 200) {
          return {
            'success': true,
            'message': data['message'] ?? 'Order created successfully',
            'order': data['data']?['order'] != null
                ? Order.fromJson(data['data']['order'])
                : null,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to create order',
          };
        }
      } else {
        final response = await ApiService.post(
          '/orders/create',
          token: token,
          body: body,
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 201 || response.statusCode == 200) {
          return {
            'success': true,
            'message': data['message'] ?? 'Order created successfully',
            'order': data['data']?['order'] != null
                ? Order.fromJson(data['data']['order'])
                : null,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to create order',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Create a nurse request without selecting a lab
  /// The admin will assign the lab and tests later
  static Future<Map<String, dynamic>> createNurseRequest({
    required OrderLocation location,
    File? prescriptionImage,
    String? scheduledDate,
    Map<String, String>? timeSlot,
    Map<String, dynamic>? beneficiary,
    // Medicine prescription: delivery-only order. The location is a delivery
    // address; admin prices the medicine and patient approval confirms it.
    bool medicine = false,
  }) async {
    try {
      final token = await AuthService().getToken();

      // For nurse requests, we use multipart since prescription image is required
      final response = await ApiService.multipart(
        '/orders/nurse-request',
        token: token,
        fields: {
          'location': jsonEncode(location.toJson()),
          if (scheduledDate != null) 'scheduledDate': scheduledDate,
          if (timeSlot != null) 'timeSlot': jsonEncode(timeSlot),
          'orderType': 'home_collection',
          if (beneficiary != null) 'beneficiary': jsonEncode(beneficiary),
          if (medicine) 'medicine': 'true',
        },
        files: prescriptionImage != null
            ? {'prescription': await http.MultipartFile.fromPath(
                'prescription',
                prescriptionImage.path,
              )}
            : {},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Nurse request created successfully',
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create nurse request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get all orders for the current patient
  static Future<Map<String, dynamic>> getPatientOrders({
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
        '/orders/my-orders',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Handle both response formats
        List<dynamic>? ordersList;

        // The backend returns { success: true, data: { orders: [...], total, page, pages } }
        if (data['data'] is Map && data['data']['orders'] is List) {
          ordersList = data['data']['orders'] as List;
        } else if (data['orders'] is List) {
          ordersList = data['orders'] as List;
        }

        // Parse each order individually to catch any parsing errors
        final List<Order> parsedOrders = [];
        if (ordersList != null) {
          for (var i = 0; i < ordersList.length; i++) {
            try {
              final orderData = ordersList[i];
              if (orderData is Map) {
                final order = Order.fromJson(orderData as Map<String, dynamic>);
                parsedOrders.add(order);
              }
            } catch (e) {
              // Skip malformed orders, continue with valid ones
            }
          }
        }

        // Safely extract pagination values
        final dataObj = data['data'];
        dynamic total = 0;
        dynamic page = 1;
        dynamic pages = 1;

        if (dataObj is Map) {
          total = dataObj['total'] ?? 0;
          page = dataObj['page'] ?? 1;
          pages = dataObj['pages'] ?? 1;
        } else {
          total = data['total'] ?? 0;
          page = data['page'] ?? 1;
          pages = data['pages'] ?? 1;
        }

        final totalInt = total is int ? total : int.tryParse(total.toString() ?? '0') ?? 0;
        final pageInt = page is int ? page : int.tryParse(page.toString() ?? '1') ?? 1;
        final pagesInt = pages is int ? pages : int.tryParse(pages.toString() ?? '1') ?? 1;

        return {
          'success': true,
          'orders': parsedOrders,
          'total': totalInt,
          'page': pageInt,
          'pages': pagesInt,
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

  /// Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/orders/$orderId',
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
          'message': data['message'] ?? 'Failed to get order',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Cancel order
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/orders/$orderId/cancel',
        token: token,
        body: {'reason': reason},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Order cancelled',
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

  /// Approve or reject a prescription price quote
  static Future<Map<String, dynamic>> respondToQuote(
    String orderId,
    bool approved,
  ) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/orders/$orderId/respond-to-quote',
        token: token,
        body: {'approved': approved},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'order': data['data']?['order'] != null
              ? Order.fromJson(data['data']['order'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to respond to quote',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Submit rating for order
  static Future<Map<String, dynamic>> rateOrder(
    String orderId, {
    int? labRating,
    int? nurseRating,
    int? serviceRating,
    String? feedback,
    String? labRatingReason,
    String? nurseRatingReason,
  }) async {
    try {
      final token = await AuthService().getToken();

      final body = <String, dynamic>{};
      if (labRating != null) body['labRating'] = labRating;
      if (nurseRating != null) body['nurseRating'] = nurseRating;
      if (serviceRating != null) body['serviceRating'] = serviceRating;
      if (feedback != null) body['feedback'] = feedback;
      if (labRatingReason != null) body['labRatingReason'] = labRatingReason;
      if (nurseRatingReason != null) body['nurseRatingReason'] = nurseRatingReason;

      final response = await ApiService.post(
        '/orders/$orderId/rate',
        token: token,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Rating submitted',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to submit rating',
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
