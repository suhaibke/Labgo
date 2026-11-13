import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_state.dart';
import 'models.dart';
import 'results_logic.dart';

/// PDFs built on the phone with the same design as the server's:
/// the lab result report (A4) and the shipping label (100 × 70 mm).

class _Fonts {
  final pw.Font regular, bold, arabic, arabicBold;
  const _Fonts(this.regular, this.bold, this.arabic, this.arabicBold);
}

_Fonts? _cache;
Uint8List? _labgoLogo;

Future<_Fonts> _fonts() async {
  if (_cache != null) return _cache!;
  Future<pw.Font> f(String p) async => pw.Font.ttf(await rootBundle.load(p));
  _cache = _Fonts(
    await f('assets/fonts/Inter-Regular.ttf'),
    await f('assets/fonts/Inter-Bold.ttf'),
    await f('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
    await f('assets/fonts/IBMPlexSansArabic-Bold.ttf'),
  );
  try {
    _labgoLogo = (await rootBundle.load('assets/images/logo.jpg')).buffer.asUint8List();
  } catch (_) {}
  return _cache!;
}

final _arabic = RegExp(r'[؀-ۿ]');
bool _isRtl(String s) => _arabic.hasMatch(s);

PdfColor _pdfColor(int argb) => PdfColor.fromInt(argb);

const _ink = PdfColor.fromInt(0xFF16181D);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);
const _soft = PdfColor.fromInt(0xFFF5F6F8);
const _high = PdfColor.fromInt(0xFFC81E1E);
const _low = PdfColor.fromInt(0xFF1D4ED8);

class _T {
  final _Fonts f;
  _T(this.f);

  /// Text that picks the Arabic font and right-to-left order when needed.
  pw.Widget call(String s, {double size = 10, bool bold = false, PdfColor color = _ink, pw.TextAlign? align, double? spacing, int? maxLines}) {
    final rtl = _isRtl(s);
    return pw.Text(
      s,
      maxLines: maxLines,
      textAlign: align,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        font: rtl ? (bold ? f.arabicBold : f.arabic) : (bold ? f.bold : f.regular),
        fontFallback: [bold ? f.arabicBold : f.arabic, bold ? f.bold : f.regular],
        fontSize: size,
        color: color,
        letterSpacing: spacing,
      ),
    );
  }
}

List<String> _holders(String s) =>
    s.split(RegExp(r'[,\n،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).take(6).toList();

String _fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// The lab result report, A4 (same layout as the server's report).
Future<Uint8List> buildResultReportPdf(AppState app, Patient p, {bool approved = true}) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  final accent = _pdfColor(app.palette.accent.toARGB32());
  final rows = resultRows(p);
  final code = p.permanent.isNotEmpty ? p.permanent : 'LG-${p.id.length > 6 ? p.id.substring(p.id.length - 6) : p.id}'.toUpperCase();
  final now = DateTime.now();
  final collected = p.createdAt ?? now;
  final holders = app.holderLines.isNotEmpty ? app.holderLines.take(6).toList() : _holders(app.licenseOwners);
  final groups = <String, List<ResultRow>>{};
  for (final r in rows) {
    groups.putIfAbsent(r.category, () => []).add(r);
  }

  pw.Widget cell(String en, String ar, String value, {bool big = false, bool accentValue = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Expanded(child: t(en.toUpperCase(), size: 6.5, color: _muted, spacing: .4)),
              t(ar, size: 6.5, color: _muted),
            ]),
            t(value.isEmpty ? '—' : value, size: big ? 11.5 : 9.5, bold: true, color: accentValue ? accent : _ink),
          ],
        ),
      );

  final contact = <(String, String)>[
    ('ADDRESS', app.labAddress),
    ('PHONE', app.labPhone),
    ('EMAIL', app.labEmail),
    ('WEBSITE', app.labWebsite),
  ].where((r) => r.$2.trim().isNotEmpty).toList();

  final doc = pw.Document(title: 'Lab report $code', author: app.labDisplayName);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 34, marginRight: 34, marginTop: 30, marginBottom: 30),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: .6))),
        child: pw.Row(children: [
          pw.Expanded(child: t('${app.labDisplayName} · $code', size: 7, color: _muted)),
          if (app.platformFooter) ...[
            if (_labgoLogo != null) pw.Image(pw.MemoryImage(_labgoLogo!), height: 10),
            pw.SizedBox(width: 4),
            t('Powered by LabGo platform', size: 7, color: _muted),
          ],
          pw.SizedBox(width: 10),
          t('${ctx.pageNumber} / ${ctx.pagesCount}', size: 7, color: _muted),
        ]),
      ),
      build: (ctx) => [
        if (!approved)
          pw.Align(alignment: pw.Alignment.centerRight, child: t('DRAFT', size: 9, bold: true, color: _high, spacing: 2)),
        // header: lab identity + contact
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            app.labLogo != null
                ? pw.Container(
                    width: 56,
                    height: 56,
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(12)),
                    child: pw.Image(pw.MemoryImage(app.labLogo!), fit: pw.BoxFit.contain),
                  )
                : pw.Container(
                    width: 56,
                    height: 56,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(12)),
                    child: t(app.labDisplayName.trim().isEmpty ? 'L' : app.labDisplayName.trim().substring(0, 1).toUpperCase(), size: 22, bold: true, color: PdfColors.white),
                  ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  t(app.labDisplayName, size: 15, bold: true),
                  if (holders.isNotEmpty) pw.SizedBox(height: 3),
                  for (final h in holders) t(h, size: 7.5, color: _ink),
                ],
              ),
            ),
            if (contact.isNotEmpty)
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.only(left: 12),
                  decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _line))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final c in contact)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.SizedBox(width: 48, child: t(c.$1, size: 6.5, color: _muted, spacing: .4)),
                            pw.Expanded(child: t(c.$2, size: 7.5, bold: true)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        // title bar with the order barcode
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _soft,
            border: pw.Border(top: pw.BorderSide(color: accent, width: 2.5)),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                t('LABORATORY REPORT', size: 11.5, bold: true, spacing: 2),
                t('تقرير نتائج التحاليل', size: 8.5, color: _muted),
              ]),
            ),
            pw.Column(children: [
              pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: code, width: 120, height: 26, drawText: false),
              t(code, size: 6.5, spacing: 2, color: _muted),
            ]),
          ]),
        ),
        pw.SizedBox(height: 8),
        // patient
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth(), 2: pw.FlexColumnWidth()},
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .6), verticalInside: pw.BorderSide(color: _line, width: .6)),
            children: [
              pw.TableRow(children: [
                cell('Patient', 'المريض', p.name, big: true),
                cell('Patient ID', 'رقم المريض', p.permanent, accentValue: true),
                cell('Gender / Age', 'الجنس / العمر', '${p.gender} / ${p.age}'),
              ]),
              pw.TableRow(children: [
                cell('Order No.', 'رقم الطلب', code),
                cell('Referred by', 'الطبيب', p.doctor),
                cell('Sample', 'العينة', p.sample),
              ]),
              pw.TableRow(children: [
                cell('Collected', 'تاريخ السحب', _fmtDate(collected)),
                cell('Reported', 'تاريخ التقرير', _fmtDate(now)),
                cell('Phone', 'الهاتف', p.phone),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // results
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(36),
            1: pw.FlexColumnWidth(16),
            2: pw.FlexColumnWidth(8),
            3: pw.FlexColumnWidth(14),
            4: pw.FlexColumnWidth(26),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFD1D5DB), width: 1.2))),
              children: [
                for (final h in const [('TEST', 'التحليل'), ('RESULT', 'النتيجة'), ('', ''), ('UNIT', 'الوحدة'), ('REFERENCE RANGE', 'المعدل الطبيعي')])
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      t(h.$1, size: 6.5, bold: true, color: _muted, spacing: .5),
                      if (h.$2.isNotEmpty) t(h.$2, size: 6.5, color: _muted),
                    ]),
                  ),
              ],
            ),
            for (final g in groups.entries) ...[
              if (groups.length > 1)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _soft),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: t('${g.key.toUpperCase()}  ·  ${categoryArabic(g.key)}', size: 7.5, bold: true, color: _muted)),
                    pw.SizedBox(), pw.SizedBox(), pw.SizedBox(), pw.SizedBox(),
                  ],
                ),
              for (final r in g.value)
                () {
                  final flag = classify(r.value, r.normalRow);
                  final color = flag == 'high' ? _high : flag == 'low' ? _low : _ink;
                  pw.Widget pad(pw.Widget c) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: c);
                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    decoration: pw.BoxDecoration(
                      color: flag == 'high' || flag == 'low' ? const PdfColor.fromInt(0xFFFBFBFC) : null,
                      border: const pw.Border(bottom: pw.BorderSide(color: _line, width: .6)),
                    ),
                    children: [
                      pad(t(r.label, size: 9, bold: true)),
                      pad(t(r.value.isEmpty ? '—' : r.value, size: 10.5, bold: true, color: color)),
                      pad(flag == 'high' || flag == 'low'
                          ? pw.Align(
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
                              child: t(flag == 'high' ? 'H' : 'L', size: 7, bold: true, color: PdfColors.white),
                            ))
                          : pw.SizedBox()),
                      pad(t(r.units, size: 8.5, color: const PdfColor.fromInt(0xFF374151))),
                      pad(t(r.range, size: 8.5, color: const PdfColor.fromInt(0xFF374151))),
                    ],
                  );
                }(),
            ],
          ],
        ),
        pw.SizedBox(height: 5),
        t('H = above the reference range · L = below the reference range', size: 7, color: _muted),
        t('H = أعلى من الطبيعي · L = أقل من الطبيعي', size: 7, color: _muted),
        if (p.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: _soft, border: pw.Border(left: pw.BorderSide(color: accent, width: 3))),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              t('LAB NOTE · ملاحظة المختبر', size: 7, bold: true, color: _muted),
              t(p.notes, size: 9),
            ]),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 170, height: .8, color: const PdfColor.fromInt(0xFF9CA3AF)),
                pw.SizedBox(height: 3),
                t(app.doctorName, size: 10.5, bold: true),
                t(approved ? 'Electronically approved · ${_fmtDate(now)}' : 'Not approved yet — draft copy', size: 7.5, color: _muted),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              t('Scan to verify this report', size: 7, color: _muted),
              t('امسح للتحقق من صحة التقرير', size: 7, color: _muted),
              pw.SizedBox(height: 3),
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: code, width: 58, height: 58),
            ]),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Center(child: t('— END OF REPORT —', size: 7.5, color: _muted, spacing: 2)),
      ],
    ),
  );
  return doc.save();
}

/// Everything the shipping label shows (server labelData, or built locally).
class LabelInfo {
  final String code, patient, demographic, tests, fromLab, toLab, date, eta, reference, price, qr;
  const LabelInfo({
    required this.code,
    required this.patient,
    required this.demographic,
    required this.tests,
    required this.fromLab,
    required this.toLab,
    required this.date,
    required this.eta,
    required this.reference,
    required this.price,
    required this.qr,
  });
}

/// The shipping label, 100 × 70 mm (same layout as the server's label).
Future<Uint8List> buildLabelPdf(AppState app, LabelInfo l) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  const orange = PdfColor.fromInt(0xFFFF5A00);
  final ar = app.lang != 'en';
  String tr3(String a, String k, String e) => app.tr(a, k, e);
  pw.Widget line(List<String> parts) => pw.Wrap(
        spacing: 3,
        children: [for (final x in parts) t(x, size: 7, color: const PdfColor.fromInt(0xFF666666))],
      );
  final doc = pw.Document(title: 'Label ${l.code}');
  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 70 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
      textDirection: ar ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: orange, width: 1.5, style: pw.BorderStyle.dashed),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Expanded(child: t(tr3('ملصق الشحن', 'لیبڵی ناردن', 'Shipping Label'), size: 12, bold: true)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFFFF0E6), borderRadius: pw.BorderRadius.circular(10)),
                child: t(l.code, size: 7.5, bold: true, color: orange),
              ),
            ]),
            pw.SizedBox(height: 3),
            t('${l.patient}${l.demographic.isEmpty ? '' : ' (${l.demographic})'} • ${l.tests}', size: 8, bold: true, maxLines: 2),
            // Each label and value is its own piece, so Arabic and English keep their order.
            line([
              '${tr3('المختبر المرسل', 'تاقیگەی نێرەر', 'Sending lab')}:', l.fromLab, ar ? '←' : '→',
              '${tr3('المختبر المستلم', 'تاقیگەی وەرگر', 'Receiving lab')}:', l.toLab,
            ]),
            line([
              '${tr3('التاريخ', 'بەروار', 'Date')}:', l.date, '•',
              '${tr3('الوصول المتوقع', 'گەیشتنی چاوەڕوانکراو', 'ETA')}:', l.eta,
              if (l.reference.isNotEmpty) ...['•', '${tr3('مرجع', 'ژمارە', 'Ref')}:', l.reference],
            ]),
            if (l.price.isNotEmpty) t('${tr3('السعر', 'نرخ', 'Price')}: ${l.price} ${tr3('د.ع', 'د.ع', 'IQD')}', size: 7.5, bold: true, color: orange),
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: l.qr, width: 48, height: 48),
                    t('QR', size: 6, color: _muted),
                  ]),
                  pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: l.code, width: 120, height: 30, drawText: false),
                    t(l.code, size: 6, color: _muted, spacing: 1.5),
                  ]),
                ],
              ),
            ),
            t(tr3('يُستخدم QR لرفع النتيجة إذا كان المختبر المستلم غير مسجل', 'QR بۆ بارکردنی ئەنجامە ئەگەر تاقیگەی وەرگر تۆمار نەکرابێت', 'QR is used to upload the result if the receiving lab is not registered'), size: 5.8, color: const PdfColor.fromInt(0xFF666666)),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

/// Medical waste pickup request (same content as the server's report).
Future<Uint8List> buildWastePdf(AppState app, WasteTransfer w) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  const orange = PdfColor.fromInt(0xFFFF5A00);
  const types = {
    'Biohazard': 'نفايات خطرة بيولوجياً · Biohazard',
    'Sharps': 'أدوات حادة · Sharps',
    'Chemical': 'نفايات كيميائية · Chemical',
    'General': 'نفايات عامة · General',
  };
  pw.TableRow row(String k, String v) => pw.TableRow(children: [
        pw.Container(color: _soft, padding: const pw.EdgeInsets.all(7), child: t(k, size: 8.5, bold: true, color: _muted)),
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: t(v.isEmpty ? '—' : v, size: 10)),
      ]);
  final now = DateTime.now();
  final doc = pw.Document(title: 'Waste request ${w.requestNo}');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 40, marginRight: 40, marginTop: 40, marginBottom: 40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: orange, width: 2.5))),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                t(app.labDisplayName, size: 16, bold: true),
                t([app.labAddress, app.labPhone].where((x) => x.trim().isNotEmpty).join(' · '), size: 9, color: _muted),
              ]),
            ),
            if (app.labLogo != null) pw.Image(pw.MemoryImage(app.labLogo!), width: 54, height: 54, fit: pw.BoxFit.contain),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t('طلب نقل نفايات طبية', size: 14, bold: true),
            t('Medical waste pickup request', size: 9, color: _muted),
          ])),
          t('#${w.requestNo}', size: 14, bold: true, color: orange),
        ]),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: _line),
          columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)},
          children: [
            row('المختبر · Lab', app.labDisplayName),
            row('العنوان · Address', app.labAddress),
            row('الهاتف · Phone', app.labPhone),
            row('نوع النفايات · Type', types[w.type] ?? w.type),
            row('الوزن · Weight', '${w.weight} kg'),
            row('موعد الاستلام · Pickup date', w.date),
            row('ملاحظات · Notes', w.notes),
            row('تاريخ الطباعة · Printed', '${now.day}/${now.month}/${now.year}'),
          ],
        ),
        pw.SizedBox(height: 50),
        pw.Row(children: [
          for (final s in const [('المختبر', 'Lab signature & stamp'), ('جهة النقل', 'Collector signature')]) ...[
            pw.Expanded(child: pw.Column(children: [
              pw.Container(height: .8, color: const PdfColor.fromInt(0xFF9CA3AF)),
              pw.SizedBox(height: 3),
              t(s.$1, size: 10, bold: true),
              t(s.$2, size: 8, color: _muted),
            ])),
            if (s.$1 == 'المختبر') pw.SizedBox(width: 30),
          ],
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          if (_labgoLogo != null) pw.Image(pw.MemoryImage(_labgoLogo!), height: 10),
          pw.SizedBox(width: 4),
          t('Powered by LabGo platform', size: 7, color: _muted),
        ]),
      ],
    ),
  ));
  return doc.save();
}

/// Purchase order for lab supplies (to send to a supplier).
Future<Uint8List> buildSupplyOrderPdf(AppState app, SupplyOrder o) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  final accent = _pdfColor(app.palette.accent.toARGB32());
  final doc = pw.Document(title: 'Supply order ${o.no}');
  pw.Widget cell(String v, {bool bold = false, PdfColor color = _ink, double size = 10}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: t(v, size: size, bold: bold, color: color));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 40, marginRight: 40, marginTop: 36, marginBottom: 36),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
      if (_labgoLogo != null) pw.Image(pw.MemoryImage(_labgoLogo!), height: 10),
      pw.SizedBox(width: 4),
      t('Powered by LabGo platform', size: 7, color: _muted),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2.5))),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(app.labDisplayName, size: 16, bold: true),
            t([app.labAddress, app.labPhone, app.labEmail].where((x) => x.trim().isNotEmpty).join(' · '), size: 9, color: _muted),
          ])),
          if (app.labLogo != null) pw.Image(pw.MemoryImage(app.labLogo!), width: 54, height: 54, fit: pw.BoxFit.contain),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          t('طلبية مواد مختبرية', size: 15, bold: true),
          t('Laboratory supplies order', size: 9, color: _muted),
        ])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          t('#${o.no}', size: 14, bold: true, color: accent),
          t(o.date, size: 9, color: _muted),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          t('إلى المورد · To: ${o.supplier.isEmpty ? '—' : o.supplier}', size: 10, bold: true),
          if (o.supplierPhone.isNotEmpty) t(o.supplierPhone, size: 9, color: _muted),
          if (o.neededBy.isNotEmpty) t('مطلوب قبل · Needed by: ${o.neededBy}', size: 9, color: _muted),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        columnWidths: const {0: pw.FixedColumnWidth(28), 1: pw.FlexColumnWidth(5), 2: pw.FlexColumnWidth(1.4), 3: pw.FlexColumnWidth(1.6)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: [
            cell('#', bold: true, color: _muted, size: 8),
            cell('المادة · Item', bold: true, color: _muted, size: 8),
            cell('الكمية · Qty', bold: true, color: _muted, size: 8),
            cell('الوحدة · Unit', bold: true, color: _muted, size: 8),
          ]),
          for (var i = 0; i < o.items.length; i++)
            pw.TableRow(children: [
              cell('${i + 1}', color: _muted),
              cell(o.items[i].name, bold: true),
              cell(o.items[i].qty),
              cell(o.items[i].unit),
            ]),
        ],
      ),
      if (o.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        t('ملاحظات · Notes', size: 8, bold: true, color: _muted),
        t(o.notes, size: 10),
      ],
      pw.SizedBox(height: 40),
      pw.Row(children: [
        pw.Expanded(child: pw.Column(children: [
          pw.Container(height: .8, color: const PdfColor.fromInt(0xFF9CA3AF)),
          pw.SizedBox(height: 3),
          t(app.doctorName, size: 10, bold: true),
          t('توقيع المختبر · Lab signature', size: 8, color: _muted),
        ])),
        pw.SizedBox(width: 120),
      ]),
    ],
  ));
  return doc.save();
}

/// Home card details for printing (patients and reports per period, and the patients of the period).
Future<Uint8List> buildStatsPdf(AppState app, String title) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  final accent = _pdfColor(app.palette.accent.toARGB32());
  final stats = app.periodStats;
  final periods = [
    app.tr('اليوم', 'ئەمڕۆ', 'Today'),
    app.tr('هذا الأسبوع', 'ئەم هەفتەیە', 'This week'),
    app.tr('هذا الشهر', 'ئەم مانگە', 'This month'),
    app.tr('هذه السنة', 'ئەمساڵ', 'This year'),
  ];
  final now = DateTime.now();
  pw.Widget c(String v, {bool bold = false, PdfColor color = _ink}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5), child: t(v, size: 9.5, bold: bold, color: color));
  final doc = pw.Document(title: title);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 36, marginRight: 36, marginTop: 34, marginBottom: 34),
    footer: (ctx) => pw.Row(children: [
      pw.Expanded(child: t('${app.labDisplayName} · ${now.day}/${now.month}/${now.year}', size: 7, color: _muted)),
      if (_labgoLogo != null) pw.Image(pw.MemoryImage(_labgoLogo!), height: 10),
      pw.SizedBox(width: 4),
      t('Powered by LabGo platform', size: 7, color: _muted),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2.5))),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(app.labDisplayName, size: 15, bold: true),
            t(title, size: 11, color: accent, bold: true),
          ])),
          if (app.labLogo != null) pw.Image(pw.MemoryImage(app.labLogo!), width: 48, height: 48, fit: pw.BoxFit.contain),
        ]),
      ),
      pw.SizedBox(height: 12),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: [
            c(app.tr('الفترة', 'ماوە', 'Period'), bold: true, color: _muted),
            c(app.tr('المرضى', 'نەخۆش', 'Patients'), bold: true, color: _muted),
            c(app.tr('مكتمل', 'تەواو', 'Completed'), bold: true, color: _muted),
            c(app.tr('قيد الانتظار', 'چاوەڕوان', 'Pending'), bold: true, color: _muted),
            c(app.tr('مرسل', 'نێردراو', 'Sent'), bold: true, color: _muted),
          ]),
          for (var i = 0; i < stats.length && i < periods.length; i++)
            pw.TableRow(children: [
              c(periods[i], bold: true),
              c('${stats[i].$1}'),
              c('${stats[i].$2}'),
              c('${stats[i].$3}'),
              c('${stats[i].$4}'),
            ]),
        ],
      ),
      pw.SizedBox(height: 14),
      t(app.tr('المرضى', 'نەخۆشەکان', 'Patients'), size: 11, bold: true),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(4), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(2)},
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: [
            c(app.tr('الاسم', 'ناو', 'Name'), bold: true, color: _muted),
            c(app.tr('التحاليل', 'پشکنین', 'Tests'), bold: true, color: _muted),
            c(app.tr('الحالة', 'دۆخ', 'Status'), bold: true, color: _muted),
            c(app.tr('السعر', 'نرخ', 'Price'), bold: true, color: _muted),
          ]),
          for (final p in app.patients.take(60))
            pw.TableRow(children: [
              c(p.name, bold: true),
              c(p.tests.join(', ')),
              c(p.status),
              c('${p.price}'),
            ]),
        ],
      ),
    ],
  ));
  return doc.save();
}

/// A photo of a result as a one-page PDF (to share or print).
Future<Uint8List> imageAsPdf(Uint8List img) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain))));
  return doc.save();
}
