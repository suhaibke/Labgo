import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/notifications_api.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../../l10n/app_localizations.dart';

/// The signed-in user's notification history - persisted server-side so it
/// survives even if the device missed the original push.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _requiresLogin = false;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    if (AuthService.isGuestMode) {
      setState(() {
        _isLoading = false;
        _requiresLogin = true;
      });
      return;
    }

    final result = await NotificationsApi.getNotifications();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _notifications = result['notifications'] as List<AppNotification>;
      } else if (result['requiresLogin'] == true) {
        _requiresLogin = true;
      } else {
        _hasError = true;
      }
    });
  }

  Future<void> _markAllAsRead() async {
    if (!_notifications.any((n) => !n.isRead)) return;

    setState(() {
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                orderId: n.orderId,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
    });
    await NotificationsApi.markAllAsRead();
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (_openingId != null) return;
    setState(() => _openingId = notification.id);

    if (!notification.isRead) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            type: notification.type,
            orderId: notification.orderId,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
      unawaited(NotificationsApi.markAsRead(notification.id));
    }

    if (notification.type != null || notification.orderId != null) {
      await NotificationService().openNotificationTarget({
        'type': notification.type,
        'orderId': notification.orderId,
      });
    }

    if (mounted) setState(() => _openingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        title: Text(l10n.notifications),
        elevation: 0,
        backgroundColor: AppTheme.backgroundLavender,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                l10n.markAllAsRead,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _load,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : (_notifications.isEmpty ? _buildEmpty(l10n) : _buildList(l10n)),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    final IconData icon;
    final String title;
    final String subtitle;
    final VoidCallback? action;
    final String? actionLabel;

    if (_requiresLogin) {
      icon = Icons.lock_outline_rounded;
      title = l10n.loginRequired;
      subtitle = l10n.loginToViewNotifications;
      action = () => showAuthRequiredDialog(context, message: l10n.loginToViewNotifications);
      actionLabel = l10n.signIn;
    } else if (_hasError) {
      icon = Icons.error_outline_rounded;
      title = l10n.tryAgain;
      subtitle = '';
      action = _load;
      actionLabel = l10n.retry;
    } else {
      icon = Icons.notifications_none_rounded;
      title = l10n.noNotificationsYet;
      subtitle = l10n.notificationsHint;
      action = null;
      actionLabel = null;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 36, color: AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.gray900,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: TextButton(onPressed: action, child: Text(actionLabel!))),
        ],
      ],
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _NotificationCard(
          notification: notification,
          isOpening: _openingId == notification.id,
          onTap: () => _openNotification(notification),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isOpening;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isOpening,
    required this.onTap,
  });

  IconData get _icon {
    switch (notification.type) {
      case 'order_accepted':
      case 'nurse_assigned':
      case 'nurse_assigned_by_admin':
        return TablerIcons.truck_delivery;
      case 'results_ready':
        return TablerIcons.file_check;
      case 'prescription_quoted':
        return TablerIcons.receipt_2;
      case 'order_completed':
        return TablerIcons.circle_check;
      case 'lab_offer':
        return TablerIcons.discount_2;
      default:
        return TablerIcons.bell;
    }
  }

  String _formatTime(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM • h:mm a', locale).format(notification.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOpening ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : AppTheme.gray200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: isOpening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(_icon, size: 19, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                              color: AppTheme.gray900,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.gray600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(context),
                      style: const TextStyle(fontSize: 11, color: AppTheme.gray500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
