import 'dart:convert';

import 'api_service.dart';
import 'auth_service.dart';

/// One row of the signed-in user's notification history (persisted
/// server-side alongside the push, so it survives even if the device
/// missed the FCM message).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: data['type']?.toString(),
      orderId: data['orderId']?.toString(),
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

class NotificationsApi {
  static Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        return {'success': false, 'requiresLogin': true, 'notifications': <AppNotification>[]};
      }

      final response = await ApiService.get(
        ApiEndpoints.notifications,
        token: token,
        queryParams: {'page': page},
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['data']?['notifications'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'notifications': list
              .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList(),
          'unreadCount': data['data']?['unreadCount'] ?? 0,
          'pagination': data['data']?['pagination'],
        };
      }
      return {'success': false, 'message': data['message'], 'notifications': <AppNotification>[]};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.', 'notifications': <AppNotification>[]};
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return 0;

      final response = await ApiService.get(
        '${ApiEndpoints.notifications}/unread-count',
        token: token,
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return (data['data']?['unreadCount'] as int?) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> markAsRead(String id) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return false;

      final response = await ApiService.post(
        '${ApiEndpoints.notifications}/$id/read',
        token: token,
      );
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markAllAsRead() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return false;

      final response = await ApiService.post(
        '${ApiEndpoints.notifications}/read-all',
        token: token,
      );
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
