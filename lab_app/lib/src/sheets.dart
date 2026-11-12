import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui.dart';

/// Modal layers drawn above the app (notifications, send result, logout).
class Overlays extends StatelessWidget {
  const Overlays({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Positioned.fill(
      child: Stack(
        children: [
          if (app.notificationsOpen) ...[
            _Backdrop(opacity: .4, onTap: () => app.openNotifications(false)),
            const _NotificationsSheet(),
          ],
          if (app.sendSheetOpen && app.sendPatient != null) ...[
            _Backdrop(opacity: .4, onTap: app.closeSendSheet),
            const _SendSheet(),
          ],
          if (app.logoutOpen) ...[
            _Backdrop(opacity: .4, onTap: () => app.showLogout(false)),
            const _LogoutDialog(),
          ],
        ],
      ),
    );
  }
}

/// `bg-black/40 backdrop-in` (.2s fade).
class _Backdrop extends StatelessWidget {
  final double opacity;
  final VoidCallback onTap;
  const _Backdrop({required this.opacity, required this.onTap});

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        builder: (context, t, _) =>
            ColoredBox(color: Colors.black.withValues(alpha: opacity * t)),
      ),
    ),
  );
}

/// Bottom sheet with the `sheet-up` animation (.32s cubic-bezier(.2,.8,.2,1)).
class BottomSheetBox extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  const BottomSheetBox({
    super.key,
    required this.child,
    this.maxHeightFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final h = MediaQuery.sizeOf(context).height;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 320),
        curve: const Cubic(.2, .8, .2, 1),
        builder: (context, t, child) =>
            FractionalTranslation(translation: Offset(0, t), child: child),
        child: Container(
          constraints: BoxConstraints(maxHeight: h * maxHeightFactor),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: pal.cardBorder)),
            boxShadow: Shadows.xxl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: pal.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final items = [
      ('n1', app.w('n1'), app.w('n1Time')),
      ('n2', app.w('n2'), app.w('n2Time')),
      ('n3', app.w('n3'), app.w('n3Time')),
    ];
    return BottomSheetBox(
      maxHeightFactor: .72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.w('notifTitle'),
                  style: ts(context, 18, weight: w700),
                ),
              ),
              GestureDetector(
                onTap: app.markAllRead,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    app.w('markAll'),
                    style: ts(context, 12, weight: w700, color: pal.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => app.openNotifications(false),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.segmented,
                    shape: BoxShape.circle,
                  ),
                  child: LIcon('X', size: 16, color: pal.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final n in items) ...[
            Tap(
              onTap: () => app.markRead(n.$1),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pal.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.segmented,
                        shape: BoxShape.circle,
                      ),
                      child: LIcon('Bell', size: 17, color: pal.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.$2,
                            style: ts(context, 14, weight: w600, height: 1.375),
                          ),
                          const SizedBox(height: 2),
                          Text(n.$3, style: ts(context, 12, color: pal.muted)),
                        ],
                      ),
                    ),
                    if (!app.readNotifications.contains(n.$1))
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6, left: 12),
                        decoration: BoxDecoration(
                          color: pal.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SendSheet extends StatefulWidget {
  const _SendSheet();

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  late final _phone = TextEditingController(text: context.app.sendPhone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final p = app.sendPatient!;
    Widget body;
    if (app.sent) {
      body = Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF9EE),
              shape: BoxShape.circle,
            ),
            child: Text(
              '✓',
              style: ts(
                context,
                26,
                weight: w900,
                color: Fixed.green,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.tr('تم إرسال النتيجة', 'ئەنجام نێردرا', 'Result sent'),
            style: ts(context, 16, weight: w900),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${app.sendChannel} • '),
                TextSpan(text: app.sendPhone, locale: const Locale('en')),
              ],
            ),
            textAlign: TextAlign.center,
            style: ts(context, 12, color: pal.muted),
          ),
          const SizedBox(height: 16),
          Tap(
            onTap: app.closeSendSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.segmented,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(app.w('close'), style: ts(context, 16, weight: w700)),
            ),
          ),
        ],
      );
    } else {
      final channels = [
        ('WhatsApp', app.w('whatsapp'), 'MessageCircle'),
        ('SMS', app.w('sms'), 'MessageSquare'),
        ('In-app', app.tr('داخل التطبيق', 'ناو ئەپ', 'In-app'), 'Send'),
      ];
      final disabled = app.sending || app.sendPhone.trim().isEmpty;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            app.w('phone'),
            style: ts(context, 12, weight: w700, color: pal.muted),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _phone,
            onChanged: app.setSendPhone,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            style: ts(context, 15),
            strutStyle: const StrutStyle(
              fontSize: 15,
              height: 1.5,
              forceStrutHeight: true,
            ),
            cursorColor: pal.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: pal.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: pal.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: pal.cardBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < channels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => app.setSendChannel(channels[i].$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: app.sendChannel == channels[i].$1
                            ? Fixed.sendGradient
                            : null,
                        color: app.sendChannel == channels[i].$1
                            ? null
                            : pal.chipBg,
                        borderRadius: BorderRadius.circular(16),
                        border: app.sendChannel == channels[i].$1
                            ? null
                            : Border.all(color: pal.cardBorder),
                      ),
                      child: Column(
                        children: [
                          LIcon(
                            channels[i].$3,
                            size: 17,
                            color: app.sendChannel == channels[i].$1
                                ? Colors.white
                                : pal.ink,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            channels[i].$2,
                            style: ts(
                              context,
                              12,
                              weight: w700,
                              color: app.sendChannel == channels[i].$1
                                  ? Colors.white
                                  : pal.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: disabled ? .6 : 1,
            child: GestureDetector(
              onTap: disabled ? null : app.sendResult,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: Fixed.sendGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LIcon('Send', size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      app.sending
                          ? '…'
                          : app.tr(
                              'إرسال النتيجة PDF',
                              'ناردنی ئەنجام PDF',
                              'Send Result PDF',
                            ),
                      style: ts(context, 16, weight: w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(app.w('sendVia'), style: ts(context, 18, weight: w700)),
          const SizedBox(height: 4),
          Text(
            '${p.name} • ${p.tests.join(', ')}',
            style: ts(context, 13, color: pal.muted),
          ),
          body,
        ],
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Entrance.pop(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: Shadows.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  app.w('logoutQ'),
                  textAlign: TextAlign.center,
                  style: ts(context, 19, weight: w700),
                ),
                const SizedBox(height: 4),
                Text(
                  app.w('logoutDesc'),
                  textAlign: TextAlign.center,
                  style: ts(context, 13, color: pal.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => app.showLogout(false),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.segmented,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            app.w('cancel'),
                            style: ts(context, 16, weight: w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          app.showLogout(false);
                          app.logout();
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: Fixed.sendGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(255, 107, 0, .35),
                                offset: Offset(0, 10),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const LIcon(
                                'LogOut',
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                app.w('confirm'),
                                style: ts(
                                  context,
                                  16,
                                  weight: w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
