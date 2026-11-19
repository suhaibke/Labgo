import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'crop_editor.dart';
import 'models.dart';
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
          if (app.settle != null) ...[
            _Backdrop(opacity: .4, onTap: app.closeSettle),
            _SettleSheet(key: ValueKey('settle-${app.settle!.$1}')),
          ],
          if (app.rowMenu != null) ...[
            _Backdrop(opacity: .4, onTap: () => app.openRowMenu(null)),
            _RowMenuSheet(key: ValueKey('menu-${app.rowMenu!.id}')),
          ],
          if (app.editingPatient != null) ...[
            _Backdrop(opacity: .4, onTap: app.closeRowDialogs),
            _EditPatientSheet(key: ValueKey('edit-${app.editingPatient!.id}')),
          ],
          if (app.deletingPatient != null) ...[
            _Backdrop(opacity: .5, onTap: app.closeRowDialogs),
            const _DeletePatientDialog(),
          ],
          if (app.sentResult != null) ...[
            _Backdrop(opacity: .4, onTap: () => app.openSentResult(null)),
            _SentResultSheet(key: ValueKey('sent-${app.sentResult!.id}')),
          ],
          if (app.uploadSourceOpen) ...[
            _Backdrop(opacity: .4, onTap: app.closeUploadSource),
            const _UploadSourceSheet(),
          ],
          if (app.cropperLoading)
            const Positioned.fill(child: ColoredBox(color: Color(0x88000000), child: Center(child: CircularProgressIndicator(color: Colors.white)))),
          if (app.cropper != null) CropEditor(key: ValueKey('crop-${app.cropper!.$1}-${app.resultCrops[app.cropper!.$1]?.length ?? 0}')),
          if (app.addPaySheet != null) ...[
            _Backdrop(opacity: .4, onTap: () => app.openAddPaySheet(null)),
            if (app.addPaySheet == 'discount') const _DiscountSheet() else const _PartialPaySheet(),
          ],
        ],
      ),
    );
  }
}

String _n(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Digits typed in any script (Arabic-Indic too) → a number.
num _parse(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch), j = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : j >= 0 ? '$j' : ch);
  }
  return num.tryParse(b.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

/// Title row shared by the payment sheets: icon, title, subtitle and close.
Widget _payHeader(BuildContext context, String icon, String title, String sub, VoidCallback onClose) {
  final pal = context.pal;
  return Row(
    children: [
      Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.accent.withValues(alpha: .12), shape: BoxShape.circle),
        child: LIcon(icon, size: 20, color: pal.accent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ts(context, 17, weight: w900)),
            Text(sub, style: ts(context, 12, color: pal.muted)),
          ],
        ),
      ),
      Tap(onTap: onClose, child: Padding(padding: const EdgeInsets.all(6), child: LIcon('X', size: 20, color: pal.muted))),
    ],
  );
}

Widget _sumRow(BuildContext context, String label, String value, {Color? color, bool big = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Text(label, style: ts(context, big ? 15 : 13, weight: big ? w900 : w400, color: big ? null : context.pal.muted)),
      const Spacer(),
      Text(value, textDirection: TextDirection.ltr, style: ts(context, big ? 18 : 14, weight: big ? w900 : w700, color: color)),
    ],
  ),
);

Widget _chip(BuildContext context, String label, bool on, VoidCallback onTap) {
  final pal = context.pal;
  return Tap(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: on ? pal.accent : pal.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? pal.accent : pal.line),
      ),
      child: Text(label, textDirection: TextDirection.ltr, style: ts(context, 13, weight: w700, color: on ? Colors.white : null)),
    ),
  );
}

Widget _wideButton(BuildContext context, String label, VoidCallback? onTap, {bool primary = true}) {
  final pal = context.pal;
  return Tap(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? pal.accent : pal.segmented,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: ts(context, 15, weight: w700, color: primary ? Colors.white : null)),
      ),
    ),
  );
}

/// "Discount" on Add Patient: an amount in IQD or a percentage, with a live total.
class _DiscountSheet extends StatefulWidget {
  const _DiscountSheet();

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late String _mode = context.app.addDiscountMode;
  late final _input = TextEditingController(
    text: context.app.addDiscountValue > 0 ? '${context.app.addDiscountValue}' : '',
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  int _discountFor(int total) {
    final v = _parse(_input.text);
    final d = _mode == 'percent' ? (total * v.clamp(0, 100) / 100).round() : v.round();
    return d.clamp(0, total).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final total = app.addTotal;
    final discount = _discountFor(total);
    final pct = _mode == 'percent';
    final presets = pct ? const [5, 10, 15, 20, 25, 50] : const [1000, 2000, 5000, 10000, 25000];
    final typed = _parse(_input.text);
    final tooMuch = !pct && typed > total;
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _payHeader(context, 'Tag', app.tr('خصم على الطلب', 'داشکاندن', 'Discount'),
              app.tr('ينقص من المبلغ الكلي للمريض', 'لە کۆی گشتی کەم دەبێتەوە', 'Taken off the patient\'s total'), () => app.openAddPaySheet(null)),
          const SizedBox(height: 16),
          // amount / percent
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: pal.segmented, borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                for (final m in [('amount', app.tr('مبلغ (IQD)', 'بڕ (IQD)', 'Amount (IQD)')), ('percent', app.tr('نسبة %', 'ڕێژە %', 'Percent %'))])
                  Expanded(
                    child: Tap(
                      onTap: () => setState(() {
                        _mode = m.$1;
                        _input.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _mode == m.$1 ? pal.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(m.$2, style: ts(context, 13, weight: w700, color: _mode == m.$1 ? null : pal.muted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BoxField(
            controller: _input,
            hint: pct ? app.tr('مثال: 10', 'نموونە: 10', 'e.g. 10') : app.tr('مثال: 5,000', 'نموونە: 5,000', 'e.g. 5,000'),
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            ltr: true,
            fontSize: 20,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in presets)
                _chip(context, pct ? '$v%' : _n(v), typed == v, () => setState(() => _input.text = '$v')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: pal.line)),
            child: Column(
              children: [
                _sumRow(context, app.tr('المجموع', 'کۆ', 'Subtotal'), '${_n(total)} IQD'),
                _sumRow(context, app.tr('الخصم', 'داشکاندن', 'Discount'), discount > 0 ? '-${_n(discount)} IQD' : '—', color: discount > 0 ? Fixed.red : null),
                Divider(color: pal.line, height: 14),
                _sumRow(context, app.tr('الإجمالي بعد الخصم', 'کۆ دوای داشکاندن', 'Total after discount'), '${_n(total - discount)} IQD', big: true, color: pal.accent),
              ],
            ),
          ),
          if (tooMuch) ...[
            const SizedBox(height: 6),
            Text(app.tr('الخصم أكبر من المبلغ الكلي', 'داشکاندن لە کۆی گشتی زیاترە', 'The discount is more than the total'), style: ts(context, 12, color: Fixed.red)),
          ],
          const SizedBox(height: 16),
          _wideButton(context, app.tr('تطبيق الخصم', 'داشکاندن جێبەجێ بکە', 'Apply discount'),
              total == 0 || tooMuch ? null : () => app.setAddDiscount(_mode, _parse(_input.text))),
          if (app.addDiscount > 0) ...[
            const SizedBox(height: 8),
            _wideButton(context, app.tr('إزالة الخصم', 'لابردنی داشکاندن', 'Remove discount'), () => app.setAddDiscount('amount', 0), primary: false),
          ],
        ],
      ),
    );
  }
}

/// "Partial payment" on Add Patient: what the patient pays now; the rest is owed.
class _PartialPaySheet extends StatefulWidget {
  const _PartialPaySheet();

  @override
  State<_PartialPaySheet> createState() => _PartialPaySheetState();
}

class _PartialPaySheetState extends State<_PartialPaySheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final net = app.addNet;
    final paid = _parse(_input.text).round();
    final valid = paid > 0 && paid < net;
    int part(int pct) => ((net * pct / 100) / 250).round() * 250;
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _payHeader(context, 'Tag', app.tr('دفع جزئي', 'پارەدانی بەشێک', 'Partial payment'),
              app.tr('يدفع المريض جزءاً الآن ويبقى الباقي ديناً عليه', 'نەخۆش ئێستا بەشێک دەدات و ئەوی تر قەرزە', 'The patient pays part now and owes the rest'),
              () => app.openAddPaySheet(null)),
          const SizedBox(height: 16),
          _sumRow(context, app.tr('المبلغ الكلي', 'کۆی گشتی', 'Total'), '${_n(net)} IQD', big: true),
          if (app.addDiscount > 0)
            Text(app.tr('بعد خصم ${_n(app.addDiscount)}', 'دوای داشکاندنی ${_n(app.addDiscount)}', 'after a ${_n(app.addDiscount)} discount'),
                style: ts(context, 12, color: pal.muted)),
          const SizedBox(height: 12),
          Text(app.tr('المبلغ المدفوع الآن', 'بڕی دراو ئێستا', 'Paid now'), style: ts(context, 13, weight: w700)),
          const SizedBox(height: 6),
          BoxField(
            controller: _input,
            hint: '0',
            keyboard: TextInputType.number,
            ltr: true,
            fontSize: 20,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pct in const [25, 50, 75])
                if (part(pct) > 0 && part(pct) < net)
                  _chip(context, '$pct% · ${_n(part(pct))}', paid == part(pct), () => setState(() => _input.text = '${part(pct)}')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: pal.line)),
            child: Column(
              children: [
                _sumRow(context, app.tr('المدفوع', 'دراو', 'Paid'), '${_n(paid.clamp(0, net).toInt())} IQD', color: Fixed.green),
                Divider(color: pal.line, height: 14),
                _sumRow(context, app.tr('المتبقي على المريض', 'ماوە لەسەر نەخۆش', 'Still owed'), '${_n((net - paid).clamp(0, net).toInt())} IQD',
                    big: true, color: const Color(0xFFD97706)),
              ],
            ),
          ),
          if (_input.text.isNotEmpty && !valid) ...[
            const SizedBox(height: 6),
            Text(
              paid >= net
                  ? app.tr('المبلغ يساوي الإجمالي أو أكثر — استخدم زر الدفع الكامل', 'بڕەکە یەکسانە یان زیاترە لە کۆ — دوگمەی پارەدانی تەواو بەکاربهێنە', 'That covers the full total — use the full payment button')
                  : app.tr('أدخل مبلغاً أكبر من صفر', 'بڕێک لە سفر زیاتر بنووسە', 'Enter an amount above zero'),
              style: ts(context, 12, color: Fixed.red),
            ),
          ],
          const SizedBox(height: 16),
          _wideButton(context, app.tr('تأكيد وإضافة المريض', 'پشتڕاستکردنەوە و زیادکردنی نەخۆش', 'Confirm and add patient'),
              valid && !app.addSaving ? () => app.submitPartial(paid) : null),
        ],
      ),
    );
  }
}

/// "Pay off": the patient pays all or part of what they owe.
class _SettleSheet extends StatefulWidget {
  const _SettleSheet({super.key});

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final _input = TextEditingController(text: '${context.app.settle?.$3 ?? ''}');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final s = app.settle!;
    final owed = s.$3;
    final pay = _parse(_input.text).round();
    final tooMuch = pay > owed;
    final valid = pay > 0 && !tooMuch;
    final left = (owed - pay).clamp(0, owed).toInt();
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _payHeader(context, 'Tag', app.tr('تسديد دين', 'دانەوەی قەرز', 'Pay off debt'), s.$2, app.closeSettle),
          const SizedBox(height: 16),
          _sumRow(context, app.tr('المبلغ المستحق', 'بڕی قەرز', 'Owed'), '${_n(owed)} IQD', big: true, color: const Color(0xFFD97706)),
          const SizedBox(height: 12),
          Text(app.tr('المبلغ المدفوع الآن', 'بڕی دراو ئێستا', 'Paid now'), style: ts(context, 13, weight: w700)),
          const SizedBox(height: 6),
          BoxField(controller: _input, hint: '0', keyboard: TextInputType.number, ltr: true, fontSize: 20, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, app.tr('كامل المبلغ', 'هەمووی', 'All'), pay == owed, () => setState(() => _input.text = '$owed')),
              if (owed >= 2000)
                _chip(context, '50% · ${_n(((owed / 2) / 250).round() * 250)}', pay == ((owed / 2) / 250).round() * 250,
                    () => setState(() => _input.text = '${((owed / 2) / 250).round() * 250}')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: pal.line)),
            child: Column(
              children: [
                _sumRow(context, app.tr('يُدفع الآن', 'ئێستا دەدرێت', 'Paying now'), '${_n(pay.clamp(0, owed).toInt())} IQD', color: Fixed.green),
                Divider(color: pal.line, height: 14),
                _sumRow(context, app.tr('يبقى بعد الدفع', 'دوای پارەدان دەمێنێتەوە', 'Left after this'), left == 0 ? app.tr('لا شيء ✓', 'هیچ ✓', 'Nothing ✓') : '${_n(left)} IQD',
                    big: true, color: left == 0 ? Fixed.green : const Color(0xFFD97706)),
              ],
            ),
          ),
          if (tooMuch) ...[
            const SizedBox(height: 6),
            Text(app.tr('المبلغ أكبر من الدين (${_n(owed)})', 'بڕەکە لە قەرز زیاترە (${_n(owed)})', 'More than what is owed (${_n(owed)})'),
                style: ts(context, 12, color: Fixed.red)),
          ],
          const SizedBox(height: 16),
          _wideButton(context, app.settling ? '…' : app.tr('تأكيد التسديد', 'پشتڕاستکردنەوەی پارەدان', 'Confirm payment'),
              valid && !app.settling ? () => app.submitSettle(pay) : null),
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
                          : app.sendChannel == 'WhatsApp'
                          ? app.tr('فتح واتساب المريض', 'کردنەوەی واتسئاپ', "Open patient's WhatsApp")
                          : app.sendChannel == 'SMS'
                          ? app.tr('فتح الرسائل', 'کردنەوەی نامە', 'Open Messages')
                          : app.tr('إرسال إلى تطبيق المريض', 'ناردن بۆ ئەپی نەخۆش', "Send to patient's app"),
                      style: ts(context, 16, weight: w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The report as a PDF file, to attach in WhatsApp or anywhere else.
          Center(
            child: GestureDetector(
              onTap: () => app.shareResultPdf(app.sendPatient!),
              child: Text(
                app.tr('مشاركة ملف PDF', 'هاوبەشکردنی PDF', 'Share the PDF file'),
                style: ts(context, 13, weight: w700, color: context.pal.accent),
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


/// One tappable line in an action sheet: tinted round icon, title, subtitle.
Widget _actionTile(BuildContext context, String icon, String title, String sub, VoidCallback onTap, {Color? color}) {
  final pal = context.pal;
  final c = color ?? pal.accent;
  return Tap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.withValues(alpha: .12), shape: BoxShape.circle),
            child: LIcon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(context, 15, weight: w700, color: color)),
                Text(sub, style: ts(context, 12, color: pal.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// "⋮" on a results row: edit details, invoice, labels, delete.
class _RowMenuSheet extends StatelessWidget {
  const _RowMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = app.rowMenu!;
    final walkIn = !p.id.startsWith('tr:');
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _payHeader(context, 'User', p.name, '${p.code} • ${p.tests.join(', ')}', () => app.openRowMenu(null)),
          const SizedBox(height: 14),
          if (walkIn) ...[
            _actionTile(context, 'UserPen', app.tr('تعديل البيانات الشخصية', 'دەستکاری زانیاری کەسی', 'Edit personal details'),
                app.tr('الاسم، الهاتف، العمر والجنس', 'ناو، مۆبایل، تەمەن و ڕەگەز', 'Name, phone, age and gender'), () => app.rowAction('edit')),
            const SizedBox(height: 8),
          ],
          _actionTile(context, 'Receipt', app.tr('طباعة الفاتورة', 'چاپی پسوڵە', 'Print invoice'),
              app.tr('وصل 80 ملم مع رمز QR', 'پسوڵەی 80 ملم', '80 mm receipt with QR code'), () => app.rowAction('invoice')),
          const SizedBox(height: 8),
          _actionTile(context, 'Tag', app.tr('طباعة الملصقات', 'چاپی لیبڵ', 'Print labels'),
              app.tr('ملصق التيوب بالباركود والاسم (${app.tubeLabelCopies})', 'لیبڵی تیوب (${app.tubeLabelCopies})', 'Tube label with barcode and name (${app.tubeLabelCopies})'),
              () => app.rowAction('labels')),
          if (walkIn) ...[
            const SizedBox(height: 8),
            _actionTile(context, 'Trash2', app.tr('حذف', 'سڕینەوە', 'Delete'),
                app.tr('حذف الطلب من القائمة والحسابات', 'سڕینەوەی داواکاری', 'Remove the order from the list and finance'), () => app.rowAction('delete'),
                color: const Color(0xFFE5484D)),
          ],
        ],
      ),
    );
  }
}

class _EditPatientSheet extends StatefulWidget {
  const _EditPatientSheet({super.key});

  @override
  State<_EditPatientSheet> createState() => _EditPatientSheetState();
}

class _EditPatientSheetState extends State<_EditPatientSheet> {
  late final p = context.app.editingPatient!;
  late final _name = TextEditingController(text: p.name);
  late final _phone = TextEditingController(text: p.phone);
  late final _ageMatch = RegExp(r'^(\d+)\s*([YMD])').firstMatch(p.age);
  late final _age = TextEditingController(text: _ageMatch?.group(1) ?? '');
  late String unit = _ageMatch?.group(2) ?? 'Y';
  late String gender = p.gender == 'Female' ? 'Female' : 'Male';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(t, style: ts(context, 13, weight: w700)),
        );
    return BottomSheetBox(
      maxHeightFactor: .9,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _payHeader(context, 'UserPen', app.tr('تعديل البيانات الشخصية', 'دەستکاری زانیاری', 'Edit personal details'), p.code, app.closeRowDialogs),
            const SizedBox(height: 6),
            label(app.tr('الاسم الكامل', 'ناوی تەواو', 'Full name')),
            BoxField(controller: _name, hint: app.tr('اسم المريض', 'ناوی نەخۆش', 'Patient name')),
            label(app.tr('الهاتف', 'مۆبایل', 'Phone')),
            BoxField(controller: _phone, hint: '07xx xxx xxxx', keyboard: TextInputType.phone, ltr: true),
            label(app.tr('العمر والجنس', 'تەمەن و ڕەگەز', 'Age and gender')),
            Row(
              children: [
                Expanded(child: BoxField(controller: _age, hint: app.tr('العمر', 'تەمەن', 'Age'), keyboard: TextInputType.number, ltr: true)),
                const SizedBox(width: 8),
                for (final u in const [('Y', 'س', 'ساڵ', 'Y'), ('M', 'ش', 'م', 'M'), ('D', 'ي', 'ڕ', 'D')]) ...[
                  _chip(context, app.tr(u.$2, u.$3, u.$4), unit == u.$1, () => setState(() => unit = u.$1)),
                  const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _chip(context, app.tr('ذكر', 'نێر', 'Male'), gender == 'Male', () => setState(() => gender = 'Male'))),
                const SizedBox(width: 8),
                Expanded(child: _chip(context, app.tr('أنثى', 'مێ', 'Female'), gender == 'Female', () => setState(() => gender = 'Female'))),
              ],
            ),
            const SizedBox(height: 18),
            _wideButton(
              context,
              app.rowBusy ? '…' : app.tr('حفظ التعديلات', 'پاشەکەوتکردن', 'Save changes'),
              app.rowBusy
                  ? null
                  : () => app.submitEditPatient(name: _name.text, phone: _phone.text, gender: gender, age: _age.text, ageUnit: unit),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletePatientDialog extends StatelessWidget {
  const _DeletePatientDialog();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final p = app.deletingPatient!;
    const red = Color(0xFFE5484D);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Entrance.pop(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(28), boxShadow: Shadows.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: red.withValues(alpha: .12), shape: BoxShape.circle),
                  child: const LIcon('Trash2', size: 24, color: red),
                ),
                const SizedBox(height: 10),
                Text(app.tr('حذف طلب ${p.name}؟', 'داواکاری ${p.name} بسڕدرێتەوە؟', 'Delete ${p.name}\'s order?'),
                    textAlign: TextAlign.center, style: ts(context, 18, weight: w700)),
                const SizedBox(height: 4),
                Text(
                  app.tr('${p.code} • سيختفي من النتائج والحسابات ولا يمكن التراجع.', '${p.code} • ناگەڕێتەوە.',
                      '${p.code} • It leaves the results and finance and cannot be undone.'),
                  textAlign: TextAlign.center,
                  style: ts(context, 13, color: pal.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _wideButton(context, app.w('cancel'), app.closeRowDialogs, primary: false)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tap(
                        onTap: app.rowBusy ? null : app.confirmDeletePatient,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(999)),
                          child: Text(app.rowBusy ? '…' : app.tr('حذف', 'سڕینەوە', 'Delete'),
                              style: ts(context, 15, weight: w700, color: Colors.white)),
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

/// "Upload result": gallery, camera or files.
class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return BottomSheetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _payHeader(context, 'ImagePlus', app.tr('رفع النتيجة', 'بارکردنی ئەنجام', 'Upload result'),
              app.tr('صورة أو ملف PDF', 'وێنە یان PDF', 'Photo or PDF'), app.closeUploadSource),
          const SizedBox(height: 14),
          _actionTile(context, 'Images', app.tr('من الاستوديو', 'لە گەلەری', 'Photo library'),
              app.tr('اختر صورة النتيجة من الصور', 'وێنەیەک هەڵبژێرە', 'Pick a photo of the result'), () => app.uploadResultFrom('gallery')),
          const SizedBox(height: 8),
          _actionTile(context, 'Camera', app.tr('فتح الكاميرا', 'کامێرا', 'Camera'),
              app.tr('صوّر ورقة النتيجة الآن', 'ئێستا وێنە بگرە', 'Take a photo of the result now'), () => app.uploadResultFrom('camera')),
          const SizedBox(height: 8),
          _actionTile(context, 'FolderOpen', app.tr('من الملفات', 'لە فایلەکان', 'Files'),
              app.tr('PDF أو صورة من ملفات الجهاز', 'PDF یان وێنە', 'A PDF or image from your files'), () => app.uploadResultFrom('files')),
        ],
      ),
    );
  }
}


/// Results of a sample sent to another lab: value, unit and normal range per
/// test (typed from what the other lab reported), and / or its result file.
class _SentResultSheet extends StatefulWidget {
  const _SentResultSheet({super.key});

  @override
  State<_SentResultSheet> createState() => _SentResultSheetState();
}

class _SentResultSheetState extends State<_SentResultSheet> {
  late final Referral r = context.app.sentResult!;
  late final List<String> tests = r.tests.isNotEmpty
      ? r.tests
      : r.test.split(RegExp('[,،]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  late final Map<String, List<TextEditingController>> fields = {
    for (final t in (tests.isEmpty ? ['Result'] : tests))
      t: () {
        final done = r.results.where((x) => x.test == t).firstOrNull;
        return [
          TextEditingController(text: done?.value ?? ''),
          TextEditingController(text: done?.unit ?? ''),
          TextEditingController(text: done?.range ?? ''),
        ];
      }(),
  };
  (String, Uint8List)? file;

  @override
  void dispose() {
    for (final l in fields.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
      if (picked.isEmpty) return;
      final f = picked.first;
      final bytes = await f.readAsBytes();
      setState(() => file = (f.name, bytes));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget field(TextEditingController c, String hint, {bool number = false}) => BoxField(
          controller: c,
          hint: hint,
          ltr: true,
          fontSize: 14,
          vPad: 10,
          radius: 12,
          keyboard: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        );
    return BottomSheetBox(
      maxHeightFactor: .92,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _payHeader(context, 'Send', r.patient, '${r.lab} • ${r.tracking}', () => app.openSentResult(null)),
            const SizedBox(height: 10),
            if (r.onLabGo && !r.done)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  app.tr('المختبر المستلم مسجل في LabGo، وإذا أدخل النتيجة ستصلك تلقائياً. ويمكنك إدخالها بنفسك الآن.',
                      'تاقیگەی وەرگر لە LabGo یە؛ دەتوانیت خۆت ئێستا ئەنجام بنووسیت.',
                      'The receiving lab is on LabGo; its result reaches you automatically. You can also enter it yourself now.'),
                  style: ts(context, 13, color: pal.muted, height: 1.5),
                ),
              ),
            Text(
                app.tr('اكتب النتيجة كما وصلتك من المختبر، أو أرفق صورتها أو ملفها.', 'ئەنجام بنووسە یان وێنەکەی هاوپێچ بکە.',
                    'Type the result as the other lab reported it, or attach its photo or file.'),
                style: ts(context, 12, color: pal.muted),
              ),
            for (final e in fields.entries) ...[
              const SizedBox(height: 12),
              Text(e.key, textDirection: TextDirection.ltr, style: ts(context, 14, weight: w700)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(flex: 5, child: field(e.value[0], app.tr('النتيجة', 'ئەنجام', 'Result'), number: true)),
                const SizedBox(width: 6),
                Expanded(flex: 4, child: field(e.value[1], app.tr('الوحدة', 'یەکە', 'Unit'))),
              ]),
              const SizedBox(height: 6),
              field(e.value[2], app.tr('المعدل الطبيعي (مثال: 30 - 100)', 'ئاستی ئاسایی (30 - 100)', 'Normal range (e.g. 30 - 100)')),
            ],
            if (r.resultFile.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                LIcon('FileText', size: 16, color: pal.accent),
                const SizedBox(width: 6),
                Text(app.tr('ملف النتيجة مرفق', 'فایلی ئەنجام هاوپێچە', 'Result file attached'), style: ts(context, 13, weight: w700)),
              ]),
            ],
            ...[
              const SizedBox(height: 12),
              Tap(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(999), border: Border.all(color: pal.line)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LIcon(file == null ? 'ImagePlus' : 'FileText', size: 16, color: pal.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        file == null ? app.tr('إرفاق صورة أو ملف النتيجة', 'هاوپێچکردنی وێنە یان فایل', 'Attach the result photo or file') : file!.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(context, 13, weight: w700),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              _wideButton(
                context,
                app.sentSaving ? '…' : app.tr('حفظ النتيجة', 'پاشەکەوتکردن', 'Save result'),
                app.sentSaving
                    ? null
                    : () => app.saveSentResults([
                          for (final e in fields.entries)
                            {'test': e.key, 'value': e.value[0].text, 'unit': e.value[1].text, 'range': e.value[2].text},
                        ], file: file),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
