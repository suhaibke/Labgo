import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_state.dart';
import 'catalog_data.dart';
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
  // Tests without a result yet are left out of the printed report.
  final rows = resultRows(p).where((r) => r.value.trim().isNotEmpty).toList();
  final code = p.code;
  final qr = p.resultUrl.isNotEmpty ? p.resultUrl : code;
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
                  if (app.labCode.isNotEmpty) t('LAB NO. ${app.labCode}', size: 6.5, color: _muted, spacing: .4),
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
        // results — the table and its key only when some test has a value
        if (rows.isNotEmpty) ...[
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
        ],
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
        // Parts cropped from the uploaded result photo / PDF.
        for (final (i, img) in (app.resultCrops[p.id] ?? const <Uint8List>[]).indexed) ...[
          pw.SizedBox(height: 10),
          // the heading only sits under a results table; alone, the image speaks for itself
          if (i == 0 && rows.isNotEmpty) ...[
            t('ATTACHED RESULT · مرفق النتيجة', size: 7.5, bold: true, color: _muted, spacing: .4),
            pw.SizedBox(height: 4),
          ],
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB), width: .8)),
            child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain, height: 330),
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
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qr, width: 58, height: 58),
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

/// The statement of a period (0 today, 1 this week, 2 this month, 3 this year),
/// printed from the home reports card: every order of the period with its amount,
/// discount, net and payment, then the totals.
Future<Uint8List> buildStatementPdf(AppState app, int period) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  final ar = app.lang != 'en';
  final accent = _pdfColor(app.palette.accent.toARGB32());
  String tr3(String a, String k, String e) => app.tr(a, k, e);
  final cur = app.currency;
  final now = DateTime.now();
  final from = app.periodStart(period);
  final list = app.periodPatients(period)
    ..sort((a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now));

  final title = [
    tr3('الموقف اليومي', 'باری ڕۆژانە', 'Daily statement'),
    tr3('الموقف الأسبوعي', 'باری هەفتانە', 'Weekly statement'),
    tr3('الموقف الشهري', 'باری مانگانە', 'Monthly statement'),
    tr3('الموقف السنوي', 'باری ساڵانە', 'Yearly statement'),
  ][period.clamp(0, 3)];
  String day(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String two(int v) => v.toString().padLeft(2, '0');
  final range = period == 0 ? day(from) : '${day(from)} — ${day(now)}';
  String when(Patient p) {
    final d = p.createdAt;
    if (d == null) return p.time;
    final hm = '${two(d.hour)}:${two(d.minute)}';
    return period == 0 ? hm : '${d.day}/${d.month} $hm';
  }

  // The period split into rows: the 7 days of the week, every day of the
  // month, or the 12 months of the year (the daily statement lists orders).
  final dayNames = ar
      ? (app.lang == 'ku'
          ? ['دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی', 'شەممە', 'یەکشەممە']
          : ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'])
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final monthNames = ar
      ? ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول']
      : ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final buckets = <(String, DateTime, DateTime)>[
    if (period == 1)
      for (var i = 0; i < 7; i++)
        () {
          final d = from.add(Duration(days: i));
          return ('${dayNames[d.weekday - 1]} ${d.day}/${d.month}', d, d.add(const Duration(days: 1)));
        }(),
    if (period == 2)
      for (var i = 1; i <= DateTime(from.year, from.month + 1, 0).day; i++)
        () {
          final d = DateTime(from.year, from.month, i);
          return ('${dayNames[d.weekday - 1]} ${d.day}/${d.month}', d, d.add(const Duration(days: 1)));
        }(),
    if (period == 3)
      for (var m = 1; m <= 12; m++) (monthNames[m - 1], DateTime(from.year, m), DateTime(from.year, m + 1)),
  ];
  List<Patient> inBucket(DateTime a, DateTime b) =>
      list.where((p) => !(p.createdAt ?? now).isBefore(a) && (p.createdAt ?? now).isBefore(b)).toList();
  // Who still owes: patients, and companies / clinics (B2B) added up.
  final debtors = list.where((p) => p.due > 0).toList();
  final companyDebt = <String, (int, int)>{};
  for (final p in debtors.where((p) => p.mode == 'B2B' && (p.company ?? '').trim().isNotEmpty)) {
    final k = p.company!.trim();
    final old = companyDebt[k] ?? (0, 0);
    companyDebt[k] = (old.$1 + 1, old.$2 + p.due);
  }

  final gross = list.fold<int>(0, (a, p) => a + p.gross);
  final discount = list.fold<int>(0, (a, p) => a + p.discount);
  final net = list.fold<int>(0, (a, p) => a + p.price);
  final paid = list.fold<int>(0, (a, p) => a + p.collected);
  final unpaid = list.fold<int>(0, (a, p) => a + p.due);
  final discounted = list.where((p) => p.discount > 0).length;

  // Rows and columns follow the page direction on their own, but tables are
  // laid out left to right, so Arabic / Kurdish table rows are reversed.
  List<pw.Widget> dir(List<pw.Widget> cells) => ar ? cells.reversed.toList() : cells;
  Map<int, pw.TableColumnWidth> widths(List<double> flex) {
    final f = ar ? flex.reversed.toList() : flex;
    return {for (var i = 0; i < f.length; i++) i: pw.FlexColumnWidth(f[i])};
  }

  pw.Widget c(String v, {bool bold = false, PdfColor color = _ink, double size = 8.5}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: t(v, size: size, bold: bold, color: color, maxLines: 2),
      );
  pw.Widget box(String label, String value, {PdfColor color = _ink}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          t(label, size: 7.5, color: _muted),
          pw.SizedBox(height: 2),
          t(value, size: 11.5, bold: true, color: color),
        ]),
      );

  final doc = pw.Document(title: title, author: app.labDisplayName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 30, marginRight: 30, marginTop: 30, marginBottom: 30),
    textDirection: ar ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    footer: (ctx) => pw.Row(children: [
      pw.Expanded(child: t('${app.labDisplayName} · ${tr3('طُبع', 'چاپکرا', 'Printed')} ${day(now)} ${two(now.hour)}:${two(now.minute)} · ${ctx.pageNumber}/${ctx.pagesCount}', size: 7, color: _muted)),
      if (_labgoLogo != null) pw.Image(pw.MemoryImage(_labgoLogo!), height: 10),
      pw.SizedBox(width: 4),
      t('Powered by LabGo platform', size: 7, color: _muted),
    ]),
    build: (ctx) => [
      // header: lab, statement title and its dates
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2.5))),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(app.labDisplayName, size: 15, bold: true),
            t(title, size: 12, color: accent, bold: true),
            t(range, size: 9, color: _muted),
          ])),
          if (app.labLogo != null) pw.Image(pw.MemoryImage(app.labLogo!), width: 48, height: 48, fit: pw.BoxFit.contain),
        ]),
      ),
      pw.SizedBox(height: 12),
      // summary
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: .6),
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: dir([
            box(tr3('عدد الطلبات', 'ژمارەی داواکاری', 'Orders'), '${list.length}'),
            box(tr3('المجموع قبل الخصم', 'کۆ پێش داشکاندن', 'Total before discount'), '${_money(gross)} $cur'),
            box('${tr3('الخصومات', 'داشکاندنەکان', 'Discounts')} ($discounted)', '${_money(discount)} $cur', color: const PdfColor.fromInt(0xFFDC2626)),
          ])),
          pw.TableRow(children: dir([
            box(tr3('الصافي', 'خاوێن', 'Net total'), '${_money(net)} $cur', color: accent),
            box(tr3('المستلم', 'وەرگیراو', 'Collected'), '${_money(paid)} $cur', color: const PdfColor.fromInt(0xFF16A34A)),
            box(tr3('غير مدفوع', 'نەدراو', 'Unpaid'), '${_money(unpaid)} $cur', color: unpaid > 0 ? const PdfColor.fromInt(0xFFD97706) : _ink),
          ])),
        ],
      ),
      pw.SizedBox(height: 14),
      if (period > 0) ...[
        t(period == 3 ? tr3('تفاصيل الأشهر', 'وردەکاری مانگەکان', 'By month') : tr3('تفاصيل الأيام', 'وردەکاری ڕۆژەکان', 'By day'), size: 11, bold: true),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          columnWidths: widths([2.4, 1, 1.6, 1.4, 1.6, 1.6, 1.6]),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), repeat: true, children: dir([
              c(period == 3 ? tr3('الشهر', 'مانگ', 'Month') : tr3('اليوم', 'ڕۆژ', 'Day'), bold: true, color: _muted, size: 7.5),
              c(tr3('الطلبات', 'داواکاری', 'Orders'), bold: true, color: _muted, size: 7.5),
              c(tr3('المبلغ', 'بڕ', 'Amount'), bold: true, color: _muted, size: 7.5),
              c(tr3('الخصم', 'داشکاندن', 'Discount'), bold: true, color: _muted, size: 7.5),
              c(tr3('الصافي', 'خاوێن', 'Net'), bold: true, color: _muted, size: 7.5),
              c(tr3('المستلم', 'وەرگیراو', 'Collected'), bold: true, color: _muted, size: 7.5),
              c(tr3('الديون', 'قەرز', 'Owed'), bold: true, color: _muted, size: 7.5),
            ])),
            for (final b in buckets)
              () {
                final rows = inBucket(b.$2, b.$3);
                final g = rows.fold<int>(0, (a, p) => a + p.gross), dsc = rows.fold<int>(0, (a, p) => a + p.discount);
                final n = rows.fold<int>(0, (a, p) => a + p.price), pd = rows.fold<int>(0, (a, p) => a + p.collected);
                final du = rows.fold<int>(0, (a, p) => a + p.due);
                final future = b.$2.isAfter(now);
                final quiet = rows.isEmpty;
                PdfColor tone(PdfColor x) => quiet ? _muted : x;
                return pw.TableRow(
                  decoration: future ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFA)) : null,
                  children: dir([
                    c(b.$1, bold: !quiet, color: tone(_ink)),
                    c(quiet ? '—' : '${rows.length}', color: tone(_ink)),
                    c(quiet ? '—' : _money(g), color: tone(_ink)),
                    c(dsc > 0 ? '-${_money(dsc)}' : '—', color: dsc > 0 ? const PdfColor.fromInt(0xFFDC2626) : _muted),
                    c(quiet ? '—' : _money(n), bold: !quiet, color: tone(_ink)),
                    c(quiet ? '—' : _money(pd), color: tone(const PdfColor.fromInt(0xFF16A34A))),
                    c(du > 0 ? _money(du) : '—', bold: du > 0, color: du > 0 ? const PdfColor.fromInt(0xFFD97706) : _muted),
                  ]),
                );
              }(),
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: dir([
              c(tr3('المجموع', 'کۆ', 'Total'), bold: true),
              c('${list.length}', bold: true),
              c(_money(gross), bold: true),
              c(discount > 0 ? '-${_money(discount)}' : '—', bold: true, color: discount > 0 ? const PdfColor.fromInt(0xFFDC2626) : _muted),
              c(_money(net), bold: true, color: accent),
              c(_money(paid), bold: true, color: const PdfColor.fromInt(0xFF16A34A)),
              c(unpaid > 0 ? _money(unpaid) : '—', bold: true, color: unpaid > 0 ? const PdfColor.fromInt(0xFFD97706) : _muted),
            ])),
          ],
        ),
      ],
      if (period == 0) ...[
      t(tr3('تفاصيل الطلبات', 'وردەکاری داواکارییەکان', 'Orders'), size: 11, bold: true),
      pw.SizedBox(height: 6),
      if (list.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 18), child: pw.Center(child: t(tr3('لا توجد طلبات في هذه الفترة', 'هیچ داواکارییەک لەم ماوەیەدا نییە', 'No orders in this period'), size: 10, color: _muted)))
      else
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          columnWidths: widths([0.6, 1.3, 2.4, 1.3, 3, 1.5, 1.3, 1.5, 1.1]),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), repeat: true, children: dir([
              c('#', bold: true, color: _muted, size: 7.5),
              c(tr3('الوصل', 'پسوڵە', 'Receipt'), bold: true, color: _muted, size: 7.5),
              c(tr3('المريض', 'نەخۆش', 'Patient'), bold: true, color: _muted, size: 7.5),
              c(period == 0 ? tr3('الوقت', 'کات', 'Time') : tr3('التاريخ', 'بەروار', 'Date'), bold: true, color: _muted, size: 7.5),
              c(tr3('التحاليل', 'پشکنینەکان', 'Tests'), bold: true, color: _muted, size: 7.5),
              c(tr3('المبلغ', 'بڕ', 'Amount'), bold: true, color: _muted, size: 7.5),
              c(tr3('الخصم', 'داشکاندن', 'Discount'), bold: true, color: _muted, size: 7.5),
              c(tr3('الصافي', 'خاوێن', 'Net'), bold: true, color: _muted, size: 7.5),
              c(tr3('الدفع', 'پارەدان', 'Paid'), bold: true, color: _muted, size: 7.5),
            ])),
            for (var i = 0; i < list.length; i++)
              pw.TableRow(children: dir([
                c('${i + 1}', color: _muted),
                c(list[i].code),
                c(list[i].mode == 'B2B' && (list[i].company ?? '').isNotEmpty ? '${list[i].name}\n${list[i].company}' : list[i].name, bold: true),
                c(when(list[i])),
                c(list[i].tests.join('، '), size: 7.5),
                c(_money(list[i].gross)),
                c(list[i].discount > 0 ? '-${_money(list[i].discount)}' : '—', color: list[i].discount > 0 ? const PdfColor.fromInt(0xFFDC2626) : _muted),
                c(_money(list[i].price), bold: true),
                c(
                    list[i].isPaid
                        ? tr3('مدفوع', 'دراو', 'Paid')
                        : list[i].isPartlyPaid
                            ? '${tr3('جزئي', 'بەشێک', 'Part')} ${_money(list[i].collected)}'
                            : tr3('غير مدفوع', 'نەدراو', 'Unpaid'),
                    color: list[i].isPaid ? const PdfColor.fromInt(0xFF16A34A) : const PdfColor.fromInt(0xFFD97706), size: 7.5),
              ])),
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: dir([
              c(''),
              c(''),
              c(tr3('المجموع', 'کۆ', 'Total'), bold: true),
              c(''),
              c('${list.length} ${tr3('طلب', 'داواکاری', 'orders')}', color: _muted, size: 7.5),
              c(_money(gross), bold: true),
              c(discount > 0 ? '-${_money(discount)}' : '—', bold: true, color: discount > 0 ? const PdfColor.fromInt(0xFFDC2626) : _muted),
              c(_money(net), bold: true, color: accent),
              c(''),
            ])),
          ],
        ),
      ],
      // Who still owes, under the table: companies / clinics, then patients.
      pw.SizedBox(height: 16),
      t(tr3('الديون المستحقة', 'قەرزە ماوەکان', 'Amounts owed'), size: 11, bold: true),
      pw.SizedBox(height: 6),
      if (debtors.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: t(tr3('لا توجد ديون في هذه الفترة', 'هیچ قەرزێک نییە', 'Nothing owed in this period'), size: 9.5, color: _muted))
      else ...[
        if (companyDebt.isNotEmpty) ...[
          t(tr3('الجهات (شركات / عيادات)', 'لایەنەکان', 'Companies / clinics'), size: 9, bold: true, color: _muted),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: .6),
            columnWidths: widths([4, 1.4, 2]),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: dir([
                c(tr3('الجهة', 'لایەن', 'Company / clinic'), bold: true, color: _muted, size: 7.5),
                c(tr3('الطلبات', 'داواکاری', 'Orders'), bold: true, color: _muted, size: 7.5),
                c(tr3('المستحق', 'قەرز', 'Owed'), bold: true, color: _muted, size: 7.5),
              ])),
              for (final e in (companyDebt.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2))))
                pw.TableRow(children: dir([
                  c(e.key, bold: true),
                  c('${e.value.$1}'),
                  c('${_money(e.value.$2)} $cur', bold: true, color: const PdfColor.fromInt(0xFFD97706)),
                ])),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
        t(tr3('المرضى', 'نەخۆشەکان', 'Patients'), size: 9, bold: true, color: _muted),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          columnWidths: widths([0.6, 2.6, 1.5, 1.3, 1.5, 1.5, 1.5, 1.6]),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), repeat: true, children: dir([
              c('#', bold: true, color: _muted, size: 7.5),
              c(tr3('المريض', 'نەخۆش', 'Patient'), bold: true, color: _muted, size: 7.5),
              c(tr3('رقم المريض', 'ژمارەی نەخۆش', 'Patient ID'), bold: true, color: _muted, size: 7.5),
              c(tr3('الوصل', 'پسوڵە', 'Receipt'), bold: true, color: _muted, size: 7.5),
              c(tr3('التاريخ', 'بەروار', 'Date'), bold: true, color: _muted, size: 7.5),
              c(tr3('الصافي', 'خاوێن', 'Net'), bold: true, color: _muted, size: 7.5),
              c(tr3('المدفوع', 'دراو', 'Paid'), bold: true, color: _muted, size: 7.5),
              c(tr3('المتبقي', 'ماوە', 'Owed'), bold: true, color: _muted, size: 7.5),
            ])),
            for (var i = 0; i < debtors.length; i++)
              pw.TableRow(children: dir([
                c('${i + 1}', color: _muted),
                c([debtors[i].name, if (debtors[i].phone.isNotEmpty) debtors[i].phone, if ((debtors[i].company ?? '').isNotEmpty) debtors[i].company!].join('\n'), bold: true),
                c(debtors[i].permanent.isEmpty ? '—' : debtors[i].permanent),
                c(debtors[i].code),
                c(debtors[i].createdAt == null ? '—' : day(debtors[i].createdAt!)),
                c(_money(debtors[i].price)),
                c(debtors[i].collected > 0 ? _money(debtors[i].collected) : '—', color: _muted),
                c(_money(debtors[i].due), bold: true, color: const PdfColor.fromInt(0xFFD97706)),
              ])),
            pw.TableRow(decoration: const pw.BoxDecoration(color: _soft), children: dir([
              c(''),
              c('${debtors.length} ${tr3('مريض', 'نەخۆش', 'patients')}', bold: true),
              c(''),
              c(''),
              c(''),
              c(''),
              c(tr3('المجموع', 'کۆ', 'Total'), bold: true),
              c('${_money(unpaid)} $cur', bold: true, color: const PdfColor.fromInt(0xFFD97706)),
            ])),
          ],
        ),
      ],
      pw.SizedBox(height: 6),
      t('${tr3('المبالغ بالدينار العراقي', 'بڕەکان بە دیناری عێراقی', 'Amounts in Iraqi dinar')} ($cur)', size: 7.5, color: _muted),
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

/// One line of the payment receipt: a package, a test inside it, or a test.
class ReceiptItem {
  final String label;
  final int? price;
  final bool indent;
  const ReceiptItem(this.label, this.price, {this.indent = false});
}

List<ReceiptItem> receiptItems(Patient p) {
  final mode = p.mode;
  final pkgs = kPackages.where((k) => p.packages.contains(k.id) || p.packages.contains(k.name)).toList();
  final covered = {for (final k in pkgs) ...k.tests};
  return [
    for (final k in pkgs) ...[
      ReceiptItem(k.name, packagePrice(k, mode)),
      for (final t in k.tests) ReceiptItem(t, null, indent: true),
    ],
    for (final t in p.tests.where((t) => !covered.contains(t))) ReceiptItem(t, testPrice(t, mode)),
  ];
}

String _money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// The payment receipt on an 80 mm thermal roll: order number as a Code 128
/// barcode, a QR that opens the result once approved, and an URGENT band.
Future<Uint8List> buildReceiptPdf(AppState app, Patient p, {required bool payLater}) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  final ar = app.lang != 'en';
  String tr3(String a, String k, String e) => app.tr(a, k, e);
  final items = receiptItems(p);
  final code = p.code;
  final qr = p.resultUrl.isNotEmpty ? p.resultUrl : code;
  final when = p.createdAt ?? DateTime.now();
  final dir = ar ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Widget dashed() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Container(
          height: 0,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _ink, width: .6, style: pw.BorderStyle.dashed)),
          ),
        ),
      );
  pw.Widget row(String a, String b, {bool bold = false, double size = 8.5}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(children: [
          t(a, size: size, bold: bold),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Align(alignment: ar ? pw.Alignment.centerLeft : pw.Alignment.centerRight, child: t(b, size: size, bold: bold))),
        ]),
      );

  final doc = pw.Document(title: 'Receipt $code', author: app.labDisplayName);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(marginLeft: 4 * PdfPageFormat.mm, marginRight: 4 * PdfPageFormat.mm, marginTop: 4 * PdfPageFormat.mm, marginBottom: 6 * PdfPageFormat.mm),
      textDirection: dir,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (_labgoLogo != null) pw.Center(child: pw.Image(pw.MemoryImage(_labgoLogo!), height: 26)),
          pw.SizedBox(height: 2),
          pw.Center(child: t(app.labDisplayName, size: 12, bold: true)),
          if (app.labPhone.trim().isNotEmpty) pw.Center(child: t(app.labPhone, size: 7.5)),
          if (app.labAddress.trim().isNotEmpty) pw.Center(child: t(app.labAddress, size: 7.5, align: pw.TextAlign.center)),
          if (p.urgency == 'Urgent') ...[
            pw.SizedBox(height: 5),
            pw.Container(
              color: _ink,
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                t('عاجل', size: 14, bold: true, color: PdfColors.white),
                t('  •  URGENT', size: 13, bold: true, color: PdfColors.white, spacing: 1),
              ]),
            ),
          ],
          dashed(),
          row(tr3('رقم الطلب', 'ژمارەی داواکاری', 'Order No.'), code, bold: true, size: 11),
          row(tr3('المريض', 'نەخۆش', 'Patient'), p.name, bold: true),
          row(tr3('العمر / الجنس', 'تەمەن / ڕەگەز', 'Age / Gender'), '${p.age} • ${p.gender}'),
          if (p.doctor.isNotEmpty) row(tr3('الطبيب', 'پزیشک', 'Doctor'), p.doctor),
          if (p.mode == 'B2B' && (p.company ?? '').isNotEmpty) row(tr3('الجهة', 'لایەن', 'Company'), p.company!),
          row(tr3('التاريخ', 'بەروار', 'Date'), _fmtDate(when)),
          dashed(),
          for (final it in items)
            pw.Padding(
              padding: pw.EdgeInsets.only(left: !ar && it.indent ? 8 : 0, right: ar && it.indent ? 8 : 0, top: 1, bottom: 1),
              child: pw.Row(children: [
                pw.Expanded(child: t(it.indent ? '- ${it.label}' : it.label, size: it.indent ? 7.5 : 8.5, bold: !it.indent, color: it.indent ? _muted : _ink, maxLines: 1)),
                t(it.price == null ? tr3('مشمول', 'لەخۆگرتووە', 'Included') : _money(it.price!), size: it.indent ? 7.5 : 8.5, bold: !it.indent, color: it.indent ? _muted : _ink),
              ]),
            ),
          dashed(),
          if (p.discount > 0) ...[
            row(tr3('المجموع', 'کۆ', 'Subtotal'), _money(p.gross)),
            row(tr3('الخصم', 'داشکاندن', 'Discount'), '-${_money(p.discount)}'),
          ],
          row(tr3('الإجمالي', 'کۆی گشتی', 'TOTAL'), '${_money(p.price)} IQD', bold: true, size: 11),
          if (p.isPartlyPaid) ...[
            row(tr3('المدفوع', 'دراو', 'Paid'), _money(p.collected)),
            row(tr3('المتبقي', 'ماوە', 'Remaining'), '${_money(p.due)} IQD', bold: true, size: 10),
          ],
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: .6)),
              child: t(
                  p.isPartlyPaid
                      ? tr3('دفع جزئي — متبقي ${_money(p.due)}', 'بەشێکی دراوە — ماوە ${_money(p.due)}', 'Partly paid — ${_money(p.due)} due')
                      : payLater
                          ? tr3('الدفع لاحقاً — معلق', 'دواتر پارەبدە — چاوەڕوانە', 'Pay later — pending')
                          : tr3('تم الدفع', 'پارەدراوە', 'Paid'),
                  size: 8,
                  bold: true),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: code, width: 150, height: 38, drawText: false)),
          pw.SizedBox(height: 2),
          pw.Center(child: t(code, size: 10, bold: true, spacing: 2)),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qr, width: 72, height: 72)),
          pw.SizedBox(height: 2),
          pw.Center(child: t(tr3('امسح لعرض النتيجة عند جاهزيتها', 'سکان بکە بۆ بینینی ئەنجام کاتێک ئامادەبوو', 'Scan to view the result when ready'), size: 7.5, color: _muted)),
          dashed(),
          pw.Center(child: t('THANK YOU • LabGo', size: 9, bold: true, spacing: 1)),
          if (app.labFooter.trim().isNotEmpty) pw.Center(child: t(app.labFooter, size: 7, color: _muted, align: pw.TextAlign.center)),
        ],
      ),
    ),
  );
  return doc.save();
}

/// The tests to write on the tube label: each package's tests, then the rest
/// (no duplicates).
List<String> tubeLabelTests(Patient p) {
  final pkgs = kPackages.where((k) => p.packages.contains(k.id) || p.packages.contains(k.name));
  final out = <String>[];
  for (final t in [for (final k in pkgs) ...k.tests, ...p.tests]) {
    if (!out.contains(t)) out.add(t);
  }
  return out;
}

/// Narrowest bar of the tube barcode, in mm. Thermal label printers print
/// 8 dots per mm (203 dpi), so 0.375 mm (3 dots) and 0.25 mm (2 dots) keep
/// every bar an exact number of dots: sharp edges the analyzers' scanners
/// read first time. The widest that fits wins.
const _tubeModules = [0.375, 0.25];

/// Tube label for a 50 × 25 mm thermal label printer: patient name, order
/// number, age / gender / date, the order number as a Code 128 barcode and
/// the tests. [copies] identical labels, one per tube.
///
/// Made for lab analyzers' barcode readers: Code 128, bars 10 mm tall, a
/// quiet zone of at least 10 bars' width on each side, and a bar width fixed
/// to the printer's dots (never stretched to fill the label). Stick it along
/// the tube with the bars across it, like the tubes' own labels.
Future<Uint8List> buildTubeLabelPdf(AppState app, Patient p, {int copies = 1}) async {
  final fonts = await _fonts();
  final t = _T(fonts);
  const mm = PdfPageFormat.mm;
  const usable = 47.0; // 50 mm minus the 1.5 mm margins
  final code = p.code;
  final when = p.createdAt ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(when.day)}/${two(when.month)}/${when.year % 100} ${two(when.hour)}:${two(when.minute)}';
  final tests = tubeLabelTests(p).join(' • ');
  final urgent = p.urgency == 'Urgent';

  final barcode = pw.Barcode.code128();
  // Code 128 always has a one-module element: the narrowest gives the count.
  final elems = barcode.make(code, width: 1000, height: 1, drawText: false).toList();
  final narrowest = elems.map((e) => e.width).reduce((a, b) => a < b ? a : b);
  final modules = (1000 / narrowest).round();
  final module = _tubeModules.firstWhere((m) => (modules + 20) * m <= usable, orElse: () => _tubeModules.last);
  final barWidth = modules * module;

  final doc = pw.Document(title: 'Tube label $code', author: app.labDisplayName);
  for (var i = 0; i < copies.clamp(1, 20); i++) {
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(50 * mm, 25 * mm, marginAll: 1.5 * mm),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(children: [
              pw.Expanded(child: t(p.name, size: 7.5, bold: true, maxLines: 1)),
              pw.SizedBox(width: 2),
              t(code, size: 7.5, bold: true),
            ]),
            pw.Row(children: [
              pw.Expanded(child: t('${p.age} • ${p.gender} • $date', size: 5.5, maxLines: 1)),
              if (urgent)
                pw.Container(
                  color: _ink,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  child: t('URGENT', size: 5.5, bold: true, color: PdfColors.white),
                ),
            ]),
            pw.SizedBox(height: .6 * mm),
            pw.Center(child: pw.BarcodeWidget(barcode: barcode, data: code, width: barWidth * mm, height: 10 * mm, drawText: false)),
            pw.SizedBox(height: .6 * mm),
            pw.Expanded(child: t(tests, size: 5.5, maxLines: 2)),
          ],
        ),
      ),
    );
  }
  return doc.save();
}
