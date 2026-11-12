import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

/// Model class for financial breakdown of an order
class OrderFinancials {
  final double totalAmount;
  final double commissionRate;
  final double adminCommission;
  final double labAmount;
  final double nurseEarning;
  final bool labSettled;
  final String? labSettledAt;

  OrderFinancials({
    required this.totalAmount,
    required this.commissionRate,
    required this.adminCommission,
    required this.labAmount,
    required this.nurseEarning,
    this.labSettled = false,
    this.labSettledAt,
  });

  factory OrderFinancials.fromJson(Map<String, dynamic> json) {
    return OrderFinancials(
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      commissionRate: (json['commissionRate'] ?? 0).toDouble(),
      adminCommission: (json['adminCommission'] ?? 0).toDouble(),
      labAmount: (json['labAmount'] ?? 0).toDouble(),
      nurseEarning: (json['nurseEarning'] ?? 0).toDouble(),
      labSettled: json['labSettled'] ?? false,
      labSettledAt: json['labSettledAt'],
    );
  }
}

/// Model class for nurse transaction
class NurseTransaction {
  final String id;
  final String type;
  final double amount;
  final String orderId;
  final String? labId;
  final String? labName;
  final String? description;
  final String referenceNumber;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final DateTime createdAt;

  NurseTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.orderId,
    this.labId,
    this.labName,
    this.description,
    required this.referenceNumber,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.createdAt,
  });

  factory NurseTransaction.fromJson(Map<String, dynamic> json) {
    return NurseTransaction(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      orderId: json['orderId'] is Map ? json['orderId']['_id'] ?? '' : json['orderId'] ?? '',
      labId: json['labId'] is Map ? json['labId']['_id'] : json['labId'],
      labName: json['labId'] is Map ? json['labId']['name'] : null,
      description: json['description'],
      referenceNumber: json['referenceNumber'] ?? '',
      balanceBefore: (json['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: json['balanceAfter'] is Map 
          ? (json['balanceAfter']['nurseBalance'] ?? 0).toDouble()
          : (json['balanceAfter'] ?? 0).toDouble(),
      status: json['status'] ?? 'completed',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'commission_earned':
        return 'Commission Earned';
      case 'lab_settlement':
        return 'Lab Payment';
      case 'admin_settlement':
        return 'Admin Settlement';
      case 'balance_adjustment':
        return 'Balance Adjustment';
      default:
        return type;
    }
  }
}

/// Model class for nurse finance overview
class NurseFinanceOverview {
  final double currentBalance;
  final double totalEarnings;
  final double totalPaidToAdmin;
  final int pendingLabPayments;
  final double pendingLabAmount;
  final int pendingAdminPayments;
  final double pendingAdminAmount;
  final int completedOrdersThisMonth;
  final double earningsThisMonth;
  final double commissionRate;
  final DateTime? lastSettlementDate;

  NurseFinanceOverview({
    required this.currentBalance,
    required this.totalEarnings,
    required this.totalPaidToAdmin,
    required this.pendingLabPayments,
    required this.pendingLabAmount,
    required this.pendingAdminPayments,
    required this.pendingAdminAmount,
    required this.completedOrdersThisMonth,
    required this.earningsThisMonth,
    required this.commissionRate,
    this.lastSettlementDate,
  });

  factory NurseFinanceOverview.fromJson(Map<String, dynamic> json) {
    final nurse = json['nurse'] ?? {};
    final pendingLab = json['pendingLabSettlements'] ?? {};
    final pendingAdmin = json['pendingAdminSettlements'] ?? {};
    final thisMonth = json['thisMonth'] ?? {};

    return NurseFinanceOverview(
      currentBalance: (nurse['currentBalance'] ?? 0).toDouble(),
      totalEarnings: (nurse['totalEarnings'] ?? 0).toDouble(),
      totalPaidToAdmin: (nurse['totalPaidToAdmin'] ?? 0).toDouble(),
      pendingLabPayments: (pendingLab['orders'] as List?)?.length ?? 0,
      pendingLabAmount: (pendingLab['totalAmount'] ?? 0).toDouble(),
      pendingAdminPayments: (pendingAdmin['orders'] as List?)?.length ?? 0,
      pendingAdminAmount: (pendingAdmin['totalAmount'] ?? 0).toDouble(),
      completedOrdersThisMonth: thisMonth['orderCount'] ?? 0,
      earningsThisMonth: (thisMonth['nurseNetEarning'] ?? 0).toDouble(),
      commissionRate: (nurse['commissionRate'] ?? 0).toDouble(),
      lastSettlementDate: nurse['lastSettlementDate'] != null 
          ? DateTime.parse(nurse['lastSettlementDate'])
          : null,
    );
  }
}

/// Model class for pending lab settlement
class PendingLabSettlement {
  final String orderId;
  final String orderNumber;
  final String labId;
  final String labName;
  final double totalAmount;
  final double labAmount;
  final double adminAmount;
  final double nurseNetEarning;
  final double labCommissionRate;
  final double nurseCommissionRate;
  final DateTime createdAt;

  PendingLabSettlement({
    required this.orderId,
    required this.orderNumber,
    required this.labId,
    required this.labName,
    required this.totalAmount,
    required this.labAmount,
    required this.adminAmount,
    required this.nurseNetEarning,
    required this.labCommissionRate,
    required this.nurseCommissionRate,
    required this.createdAt,
  });

  factory PendingLabSettlement.fromJson(Map<String, dynamic> json) {
    final financials = json['financials'] ?? {};
    final lab = json['labId'] is Map ? json['labId'] : (json['lab'] ?? {});
    final pricing = json['pricing'] ?? {};

    return PendingLabSettlement(
      orderId: json['_id'] ?? '',
      orderNumber: json['qrCode'] ?? json['orderNumber'] ?? '',
      labId: lab is Map ? (lab['_id'] ?? '') : (json['labId'] ?? ''),
      labName: lab is Map ? (lab['name'] ?? 'Unknown Lab') : 'Unknown Lab',
      totalAmount: (pricing['total'] ?? json['totalPrice'] ?? 0).toDouble(),
      labAmount: (financials['labAmount'] ?? 0).toDouble(),
      adminAmount: (financials['adminAmount'] ?? 0).toDouble(),
      nurseNetEarning: (financials['nurseNetEarning'] ?? 0).toDouble(),
      labCommissionRate: (financials['labCommissionRate'] ?? 0).toDouble(),
      nurseCommissionRate: (financials['nurseCommissionRate'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Model class for pending admin settlement (what nurse owes admin)
class PendingAdminSettlement {
  final String orderId;
  final String orderNumber;
  final String labId;
  final String labName;
  final double totalAmount;
  final double adminAmount;
  final double nurseCommissionRate;
  final DateTime createdAt;

  PendingAdminSettlement({
    required this.orderId,
    required this.orderNumber,
    required this.labId,
    required this.labName,
    required this.totalAmount,
    required this.adminAmount,
    required this.nurseCommissionRate,
    required this.createdAt,
  });

  factory PendingAdminSettlement.fromJson(Map<String, dynamic> json) {
    final financials = json['financials'] ?? {};
    final lab = json['labId'] is Map ? json['labId'] : (json['lab'] ?? {});
    final pricing = json['pricing'] ?? {};

    return PendingAdminSettlement(
      orderId: json['_id'] ?? '',
      orderNumber: json['qrCode'] ?? json['orderNumber'] ?? '',
      labId: lab is Map ? (lab['_id'] ?? '') : (json['labId'] ?? ''),
      labName: lab is Map ? (lab['name'] ?? 'Unknown Lab') : 'Unknown Lab',
      totalAmount: (pricing['total'] ?? json['totalPrice'] ?? 0).toDouble(),
      adminAmount: (financials['adminAmount'] ?? 0).toDouble(),
      nurseCommissionRate: (financials['nurseCommissionRate'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Service for nurse finance operations
class NurseFinanceService {
  /// Get nurse finance overview
  static Future<Map<String, dynamic>> getFinanceOverview() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/finance/overview',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'overview': NurseFinanceOverview.fromJson(data['data']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get finance overview',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get financial breakdown for a specific order
  static Future<Map<String, dynamic>> getOrderFinancials(String orderId) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/finance/order/$orderId',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'financials': OrderFinancials.fromJson(data['data']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get order financials',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get nurse transaction history
  static Future<Map<String, dynamic>> getTransactions({
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService().getToken();

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await ApiService.get(
        '/nurse/finance/transactions',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final transactionsList = data['data']?['transactions'] as List<dynamic>? ?? [];

        final List<NurseTransaction> transactions = transactionsList
            .map((t) => NurseTransaction.fromJson(t as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'transactions': transactions,
          'total': data['data']?['total'] ?? 0,
          'page': data['data']?['page'] ?? 1,
          'pages': data['data']?['pages'] ?? 1,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get transactions',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get pending lab settlements
  static Future<Map<String, dynamic>> getPendingSettlements() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/finance/pending-settlements',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final settlementsList = data['data']?['orders'] as List<dynamic>? ?? [];

        final List<PendingLabSettlement> settlements = settlementsList
            .map((s) => PendingLabSettlement.fromJson(s as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'settlements': settlements,
          'totalPending': data['data']?['totalPending'] ?? 0,
          'totalAmount': (data['data']?['totalAmount'] ?? 0).toDouble(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get pending settlements',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get pending admin settlements (what nurse owes to admin)
  static Future<Map<String, dynamic>> getPendingAdminSettlements() async {
    try {
      final token = await AuthService().getToken();

      // Use overview endpoint to get pending admin settlements
      final response = await ApiService.get(
        '/nurse/finance/overview',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final pendingAdmin = data['data']?['pendingAdminSettlements'] ?? {};
        final ordersList = pendingAdmin['orders'] as List<dynamic>? ?? [];

        final List<PendingAdminSettlement> settlements = ordersList
            .map((s) => PendingAdminSettlement.fromJson(s as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'settlements': settlements,
          'totalPending': ordersList.length,
          'totalAmount': (pendingAdmin['totalAmount'] ?? 0).toDouble(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get pending admin settlements',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Settle payment with a lab for a specific order
  static Future<Map<String, dynamic>> settleLabPayment(String orderId) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/nurse/finance/settle-lab/$orderId',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Lab payment settled successfully',
          'newBalance': (data['data']?['newBalance'] ?? 0).toDouble(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to settle lab payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Batch settle multiple lab payments
  static Future<Map<String, dynamic>> settleLabPaymentsBatch(List<String> orderIds) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.post(
        '/nurse/finance/settle-lab-batch',
        token: token,
        body: {'orderIds': orderIds},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Lab payments settled successfully',
          'settledCount': data['data']?['settledCount'] ?? 0,
          'newBalance': (data['data']?['newBalance'] ?? 0).toDouble(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to settle lab payments',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get earnings history
  static Future<Map<String, dynamic>> getEarningsHistory({
    String period = 'monthly',
    int months = 6,
  }) async {
    try {
      final token = await AuthService().getToken();

      final queryParams = <String, dynamic>{
        'period': period,
        'months': months,
      };

      final response = await ApiService.get(
        '/nurse/finance/earnings-history',
        token: token,
        queryParams: queryParams,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'history': data['data']?['history'] ?? [],
          'totals': data['data']?['totals'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get earnings history',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get available months with data
  static Future<Map<String, dynamic>> getAvailableMonths() async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/finance/available-months',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'months': data['data']?['months'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get available months',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Get finance data for a specific month
  static Future<Map<String, dynamic>> getMonthlyData(int year, int month) async {
    try {
      final token = await AuthService().getToken();

      final response = await ApiService.get(
        '/nurse/finance/monthly/$year/$month',
        token: token,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final ordersList = data['data']?['orders'] as List<dynamic>? ?? [];
        final transactionsList = data['data']?['transactions'] as List<dynamic>? ?? [];

        return {
          'success': true,
          'year': data['data']?['year'] ?? year,
          'month': data['data']?['month'] ?? month,
          'stats': data['data']?['stats'] ?? {},
          'orders': ordersList,
          'transactions': transactionsList.map((t) => NurseTransaction.fromJson(t as Map<String, dynamic>)).toList(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get monthly data',
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
