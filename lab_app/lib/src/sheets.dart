import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            _SendSheet(key: ValueKey('send-${app.sendPatient?.id}')),
          ],
          if (app.labelReferral != null) ...[
            _Backdrop(opacity: .5, onTap: () => app.showLabel(null)),
            const _ShippingLabel(),
          ],
          if (app.deleteAccountOpen) ...[
            _Backdrop(
              opacity: .4,
              onTap: () =>
                  app.updateSettings(() => app.deleteAccountOpen = false),
            ),
            const _DeleteAccountDialog(),
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
    final items = app.notificationItems;
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
              onTap: () => app.openNotification(n.$1),
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
  const _SendSheet({super.key});

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
              children: app.sendPatient?.id.startsWith('tr:') == true
                  ? [TextSpan(text: app.sendPatient!.company ?? '')]
                  : [
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
      // A sample another lab sent here: the result goes back to that lab.
      final toLab = app.sendPatient?.id.startsWith('tr:') == true;
      final disabled = app.sending || (!toLab && app.sendPhone.trim().isEmpty);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          if (toLab)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.chipBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.line),
              ),
              child: Row(
                children: [
                  LIcon('Building2', size: 18, color: pal.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      app.tr(
                        'تصل النتيجة مباشرة إلى ${app.sendPatient!.company ?? ''} مع إشعار',
                        'ئەنجام ڕاستەوخۆ دەگاتە ${app.sendPatient!.company ?? ''}',
                        'The result goes straight to ${app.sendPatient!.company ?? ''} with a notification',
                      ),
                      style: ts(context, 13, weight: w600),
                    ),
                  ),
                ],
              ),
            ),
          if (!toLab) ...[
            Text(
              app.w('phone'),
              style: ts(context, 12, weight: w700, color: pal.muted),
            ),
            const SizedBox(height: 4),
            BoxField(
              controller: _phone,
              onChanged: app.setSendPhone,
              ltr: true,
              keyboard: TextInputType.phone,
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
                              ? context.pal.accentGradient
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
          ],
          const SizedBox(height: 16),
          Opacity(
            opacity: disabled ? .6 : 1,
            child: GestureDetector(
              onTap: disabled ? null : app.sendResult,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: context.pal.accentGradient,
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
                            gradient: context.pal.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.pal.accentShadow,
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

/// Shipping label popup for a referral (design `wl`).
class _ShippingLabel extends StatelessWidget {
  const _ShippingLabel();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final r = app.labelReferral!;
    // Server mode: real label data (QR = result upload link, Code 128 barcode).
    final ld = app.labelData;
    final code = '${ld?['code'] ?? r.tracking}';
    // Real codes: from the server, or made here (demo).
    final qrSvg = ld != null
        ? '${ld['qrSvg']}'
        : bc.Barcode.qrCode().toSvg(code, width: 200, height: 200);
    final barSvg = ld != null
        ? '${ld['barcodeSvg']}'
        : bc.Barcode.code128().toSvg(code, width: 320, height: 80, drawText: false);
    final ink = pal.dark ? Colors.white : const Color(0xFF111111);
    final grey = pal.dark ? const Color(0xFFA1A1AA) : const Color(0xFF666666);
    final match = app.patients.where((p) => p.name.toLowerCase() == r.patient.toLowerCase());
    final demo = ld != null
        ? [
            if (ld['gender'] == 'male') app.tr('ذكر', 'نێر', 'Male'),
            if (ld['gender'] == 'female') app.tr('أنثى', 'مێ', 'Female'),
            if (ld['age'] != null) '${ld['age']} ${app.tr('سنة', 'ساڵ', 'y')}',
          ].join(' · ')
        : r.gender.isNotEmpty
        ? [
            r.gender == 'Female' ? app.tr('أنثى', 'مێ', 'Female') : app.tr('ذكر', 'نێر', 'Male'),
            if (r.age.isNotEmpty) '${r.age} ${app.tr('سنة', 'ساڵ', 'y')}',
          ].join(' · ')
        : match.isEmpty
        ? ''
        : '${match.first.gender == 'Female' ? app.tr('أنثى', 'مێ', 'Female') : app.tr('ذكر', 'نێر', 'Male')} · ${match.first.age}';
    return Positioned(
      left: 12,
      right: 12,
      top: 70,
      child: Entrance.pop(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pal.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPaint(
                  painter: _DashedRRect(color: Fixed.orange, radius: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                app.d('labelTitle'),
                                style: ts(
                                  context,
                                  18,
                                  weight: w900,
                                  color: ink,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pal.softAccent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                code,
                                style: ts(
                                  context,
                                  11,
                                  weight: w700,
                                  color: Fixed.orange,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: r.patient,
                                style: const TextStyle(fontWeight: w700),
                              ),
                              if (demo.isNotEmpty)
                                TextSpan(
                                  text: ' ($demo)',
                                  style: TextStyle(color: grey),
                                ),
                              TextSpan(text: ' • ${ld?['tests'] ?? r.test}'),
                            ],
                          ),
                          style: ts(context, 13, color: ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${app.d('sendingLab')}: ${ld?['fromLab'] ?? 'LabGo Mosul'} → ${app.d('receivingLab')}: ${ld?['toLab'] ?? r.lab}',
                          style: ts(context, 13, color: grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${app.w('dateCol')}: ${ld?['date'] ?? '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'} • ${app.w('eta')}: ${ld?['eta'] ?? r.eta}',
                          style: ts(context, 13, color: grey),
                        ),
                        if ('${ld?['priceText'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${app.tr('السعر', 'نرخ', 'Price')}: ',
                                ),
                                TextSpan(
                                  text:
                                      '${ld!['priceText']} ${app.tr('د.ع', 'د.ع', 'IQD')}',
                                  style: const TextStyle(
                                    fontWeight: w900,
                                    color: Fixed.orange,
                                  ),
                                ),
                              ],
                            ),
                            style: ts(context, 13, color: grey),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: pal.cardBorder),
                                  ),
                                  child: SvgPicture.string(qrSvg),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'QR',
                                  style: ts(context, 10, color: pal.muted),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: pal.cardBorder),
                                  ),
                                  child: SvgPicture.string(
                                    barSvg,
                                    height: 34,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.black,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  code,
                                  style: ts(
                                    context,
                                    10,
                                    color: pal.muted,
                                    tracking: .18 * 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          app.d('labelNote'),
                          style: ts(context, 11, color: grey, height: 1.625),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => app.showLabel(null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.dark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            app.w('close'),
                            style: ts(context, 16, weight: w700, color: ink),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        // The device's print preview (AirPrint / share) with the label PDF.
                        onTap: app.printLabel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: context.pal.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const LIcon(
                                'Printer',
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                app.d('printLabel'),
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

class _DashedRRect extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRect({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          Radius.circular(radius),
        ),
      );
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, (d + 6).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRect old) => old.color != color;
}

/// Delete account: confirm, then a 6-digit code (123456 in the demo).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool otpStage = false;
  String status = 'idle'; // idle | wrong | correct
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    void close() => app.updateSettings(() => app.deleteAccountOpen = false);

    Widget btn(String label, Color bg, Color fg, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: ts(context, 16, weight: w700, color: fg),
              ),
            ),
          ),
        );

    List<Widget> body;
    if (!otpStage) {
      body = [
        Text(
          app.d('deleteConfirmTitle'),
          textAlign: TextAlign.center,
          style: ts(context, 19, weight: w700),
        ),
        const SizedBox(height: 4),
        Text(
          app.d('deleteConfirmDesc'),
          textAlign: TextAlign.center,
          style: ts(context, 13, color: pal.muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            btn(app.d('cancelDelete'), pal.segmented, pal.ink, close),
            const SizedBox(width: 8),
            btn(
              app.d('confirmDelete'),
              Fixed.red,
              Colors.white,
              () => setState(() => otpStage = true),
            ),
          ],
        ),
      ];
    } else {
      Color border = pal.cardBorder, fill = pal.inputBg, text = pal.ink;
      if (status == 'wrong') {
        border = Fixed.red;
        fill = const Color(0xFFFFF0EF);
        text = Fixed.red;
      } else if (status == 'correct') {
        border = Fixed.green;
        fill = const Color(0xFFEAF9EE);
        text = const Color(0xFF0E7A3E);
      }
      body = [
        Text(
          app.p('otpTitle'),
          textAlign: TextAlign.center,
          style: ts(context, 19, weight: w700),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${app.p('otpSub')} '),
              TextSpan(
                text: app.userPhone,
                style: const TextStyle(fontWeight: w700),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: ts(context, 13, color: pal.muted),
        ),
        const SizedBox(height: 16),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: TextField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: ts(context, 20, weight: w900, color: text),
                    cursorColor: pal.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      final digit = v.replaceAll(RegExp(r'\D'), '');
                      _ctrls[i].text = digit.isEmpty
                          ? ''
                          : digit.substring(digit.length - 1);
                      if (digit.isNotEmpty && i < 5)
                        _nodes[i + 1].requestFocus();
                      setState(() => status = 'idle');
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (status == 'correct')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '✓ ${app.lang == 'ar' ? 'رمز صحيح' : 'Correct code'}',
              textAlign: TextAlign.center,
              style: ts(context, 14, weight: w900, color: Fixed.green),
            ),
          ),
        if (status == 'wrong')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              app.lang == 'ar' ? 'رمز خاطئ' : 'Wrong code',
              textAlign: TextAlign.center,
              style: ts(context, 13, weight: w700, color: Fixed.red),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            btn(
              app.w('cancel'),
              pal.segmented,
              pal.ink,
              () => setState(() => otpStage = false),
            ),
            const SizedBox(width: 8),
            btn(app.p('confirmBtn'), Fixed.red, Colors.white, () {
              if (_ctrls.map((c) => c.text).join() == '123456') {
                setState(() => status = 'correct');
                Future.delayed(
                  const Duration(milliseconds: 650),
                  app.accountDeleted,
                );
              } else {
                setState(() => status = 'wrong');
              }
            }),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          app.p('tryHint'),
          textAlign: TextAlign.center,
          style: ts(context, 12, color: pal.muted),
        ),
      ];
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Entrance.pop(
          key: ValueKey(otpStage),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: Shadows.xxl,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
