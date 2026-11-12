import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';

class InvoiceScreen extends StatefulWidget {
  final Order order;

  const InvoiceScreen({super.key, required this.order});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  static const _cardBorder = Color(0xFFE8E0F8);
  static const _qrWash = Color(0xFFF3EDFF);
  static const _ink = Color(0xFF1C1433);
  static const _muted = Color(0xFF9A93B0);
  static const _headerPurple = Color(0xFF5B3CC4);

  bool _busy = false;

  Order get _order => widget.order;

  String get _invoiceNumber {
    final raw = _order.qrCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final short = raw.length >= 5
        ? raw.substring(raw.length - 5).toUpperCase()
        : raw.padLeft(5, '0').toUpperCase();
    return 'INV-${_order.createdAt.year}-$short';
  }

  String get _barcodeValue {
    final raw = _order.qrCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final short = raw.length >= 5
        ? raw.substring(raw.length - 5).toUpperCase()
        : raw.padLeft(5, '0').toUpperCase();
    return 'LABGO-$short-${_order.createdAt.year}';
  }

  String _patientName() {
    if (_order.isForOtherPerson &&
        (_order.beneficiaryName?.trim().isNotEmpty ?? false)) {
      return _order.beneficiaryName!.trim();
    }
    return _order.patientData?['name']?.toString() ?? '';
  }

  String _patientGender(AppLocalizations l10n) {
    switch (_order.patientData?['gender']?.toString()) {
      case 'male':
        return l10n.male;
      case 'female':
        return l10n.female;
      default:
        return '';
    }
  }

  String _patientAge(AppLocalizations l10n) {
    final birthDate = DateTime.tryParse(
      _order.patientData?['birthDate']?.toString() ?? '',
    );
    if (birthDate == null) return '';
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return '$age ${l10n.ageYears}';
  }

  String _labName(AppLocalizations l10n) {
    if (_order.isMedicineOrder) {
      final lab = _order.labData?['name']?.toString();
      if (lab != null && lab.isNotEmpty) return lab;
      return l10n.therapeuticPrescription;
    }
    final lab = _order.labData?['name']?.toString();
    return (lab != null && lab.isNotEmpty) ? lab : l10n.laboratory;
  }

  String _itemsDescription(AppLocalizations l10n) {
    if (_order.tests.isNotEmpty) {
      return l10n.invoiceTestsCount(_order.tests.length);
    }
    if (_order.prescriptionQuote != null) {
      final quote = _order.prescriptionQuote!;
      final medName = quote['medicineName']?.toString();
      if (medName != null && medName.isNotEmpty) {
        final medType = quote['medicineType']?.toString();
        return (medType != null && medType.isNotEmpty) ? '$medName ($medType)' : medName;
      }
      final quoteTests = (quote['tests'] as List?)
          ?.whereType<Map>()
          .where((t) => (t['name']?.toString().isNotEmpty ?? false))
          .toList() ?? [];
      if (quoteTests.isNotEmpty) {
        return l10n.invoiceTestsCount(quoteTests.length);
      }
    }
    return _order.isMedicineOrder ? l10n.therapeuticPrescription : l10n.invoiceTestsCount(0);
  }

  String _formatPrice(int price) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  String _formattedDate(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMMM yyyy', locale).format(_order.createdAt.toLocal());
  }

  bool get _isCancelled =>
      _order.status == 'cancelled' || _order.status == 'canceled';

  Future<Uint8List> _buildPdf(AppLocalizations l10n, String locale) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final isCancelled = _isCancelled;
    final status = isCancelled ? l10n.invoiceCancelledStatus : l10n.invoiceConfirmed;
    final payment = l10n.cashOnCollection;
    final date = DateFormat('d MMMM yyyy', locale).format(_order.createdAt.toLocal());
    final isRtl = locale.startsWith('ar') || locale.startsWith('ku');
    final amount = '${_formatPrice(_order.totalPrice)} ${l10n.iqd}';
    const purple = PdfColor.fromInt(0xFF7257D8);
    const muted = PdfColor.fromInt(0xFF9A93B0);
    const ink = PdfColor.fromInt(0xFF1C1433);
    const green = PdfColor.fromInt(0xFF16A34A);
    const border = PdfColor.fromInt(0xFFE8E0F8);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return pw.Directionality(
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(28),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border, width: 1.2),
                borderRadius: pw.BorderRadius.circular(18),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(logo, height: 28),
                      pw.Spacer(),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            status,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 13,
                              color: isCancelled
                                  ? PdfColor.fromInt(0xFFEF4444)
                                  : green,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(date, style: pw.TextStyle(fontSize: 10, color: muted)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 22),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              l10n.invoiceNumber,
                              style: pw.TextStyle(fontSize: 10, color: muted),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              _invoiceNumber,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 16,
                                color: purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Container(
                        width: 78,
                        height: 78,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF3EDFF),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: _invoiceNumber,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  _pdfRow(l10n.patient, _patientName(), fontBold, muted, ink),
                  if (_patientGender(l10n).isNotEmpty)
                    _pdfRow(l10n.gender, _patientGender(l10n), fontBold, muted, ink),
                  if (_patientAge(l10n).isNotEmpty)
                    _pdfRow(l10n.age, _patientAge(l10n), fontBold, muted, ink),
                  _pdfRow(
                    _order.isMedicineOrder ? l10n.therapeuticPrescription : l10n.laboratory,
                    _labName(l10n),
                    fontBold,
                    muted,
                    ink,
                  ),
                  _pdfRow(
                    _order.isMedicineOrder ? l10n.prescription : l10n.invoiceTests,
                    _itemsDescription(l10n),
                    fontBold,
                    muted,
                    ink,
                  ),
                  _pdfRow(l10n.paymentMethod, payment, fontBold, muted, ink),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColor.fromInt(0xFF2A1A4A), thickness: 1.1),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Text(
                        l10n.grandTotal,
                        style: pw.TextStyle(font: fontBold, fontSize: 14, color: purple),
                      ),
                      pw.Spacer(),
                      pw.Text(
                        amount,
                        style: pw.TextStyle(font: fontBold, fontSize: 18, color: purple),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 28),
                  pw.Center(
                    child: pw.SizedBox(
                      width: 220,
                      height: 52,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code39(),
                        data: _barcodeValue,
                        drawText: false,
                        color: ink,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text(
                      _barcodeValue,
                      style: pw.TextStyle(fontSize: 9, color: muted, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfRow(
    String label,
    String value,
    pw.Font bold,
    PdfColor muted,
    PdfColor ink,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, color: muted)),
          pw.Spacer(),
          pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(font: bold, fontSize: 12, color: ink),
          ),
        ],
      ),
    );
  }

  Future<void> _runPdfAction(Future<void> Function(Uint8List bytes) action) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final locale = Localizations.localeOf(context).toString();
      final bytes = await _buildPdf(l10n, locale);
      await action(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invoicePdfError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadPdf() {
    return _runPdfAction((bytes) {
      return Printing.sharePdf(bytes: bytes, filename: '$_invoiceNumber.pdf');
    });
  }

  Future<void> _printInvoice() {
    return _runPdfAction((bytes) {
      return Printing.layoutPdf(onLayout: (_) async => bytes);
    });
  }

  Future<void> _shareInvoice() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _runPdfAction((bytes) {
        return Printing.sharePdf(bytes: bytes, filename: '$_invoiceNumber.pdf');
      });
    } catch (_) {
      await Share.share(
        l10n.invoiceShareMessage(_invoiceNumber, _formatPrice(_order.totalPrice)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _isCancelled ? AppTheme.error : const Color(0xFF22A45A);
    final statusLabel =
        _isCancelled ? l10n.invoiceCancelledStatus : l10n.invoiceConfirmed;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Directionality.of(context) ==
                            ui.TextDirection.rtl
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.invoice,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _headerPurple,
                      ),
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.share_outlined,
                    onTap: _busy ? null : _shareInvoice,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _cardBorder, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Text(
                                  'labgo',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formattedDate(context),
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.invoiceNumber,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _invoiceNumber,
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _qrWash,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: QrImageView(
                                  data: _invoiceNumber,
                                  padding: EdgeInsets.zero,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: _ink,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _InfoRow(label: l10n.patient, value: _patientName()),
                          if (_patientGender(l10n).isNotEmpty)
                            _InfoRow(label: l10n.gender, value: _patientGender(l10n)),
                          if (_patientAge(l10n).isNotEmpty)
                            _InfoRow(label: l10n.age, value: _patientAge(l10n)),
                          _InfoRow(
                            label: _order.isMedicineOrder ? l10n.therapeuticPrescription : l10n.laboratory,
                            value: _labName(l10n),
                          ),
                          _InfoRow(
                            label: _order.isMedicineOrder ? l10n.prescription : l10n.invoiceTests,
                            value: _itemsDescription(l10n),
                          ),
                          _InfoRow(
                            label: l10n.paymentMethod,
                            value: l10n.cashOnCollection,
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: _ink, thickness: 1.2, height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                l10n.grandTotal,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_formatPrice(_order.totalPrice)} ${l10n.iqd}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 56,
                            width: 230,
                            child: CustomPaint(
                              painter: _Code39Painter(data: _barcodeValue),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _barcodeValue,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _printInvoice,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _ink,
                                side: const BorderSide(color: Color(0xFFE6E2F0)),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.description_outlined, size: 20),
                              label: Text(
                                l10n.printInvoice,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _downloadPdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded, size: 20),
                              label: Text(
                                l10n.downloadPdf,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE6E2F0)),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A93B0),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF1C1433),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual Code 39 barcode used on the invoice card.
class _Code39Painter extends CustomPainter {
  final String data;

  const _Code39Painter({required this.data});

  static const _patterns = <String, String>{
    '0': 'nnnwwnwnn',
    '1': 'wnnwnnnnw',
    '2': 'nnwwnnnnw',
    '3': 'wnwwnnnnn',
    '4': 'nnnwwnnnw',
    '5': 'wnnwwnnnn',
    '6': 'nnwwwnnnn',
    '7': 'nnnwnnwnw',
    '8': 'wnnwnnwnn',
    '9': 'nnwwnnwnn',
    'A': 'wnnnnwnnw',
    'B': 'nnwnnwnnw',
    'C': 'wnwnnwnnn',
    'D': 'nnnnwwnnw',
    'E': 'wnnnwwnnn',
    'F': 'nnwnwwnnn',
    'G': 'nnnnnwwnw',
    'H': 'wnnnnwwnn',
    'I': 'nnwnnwwnn',
    'J': 'nnnnwwwnn',
    'K': 'wnnnnnnww',
    'L': 'nnwnnnnww',
    'M': 'wnwnnnnwn',
    'N': 'nnnnwnnww',
    'O': 'wnnnwnnwn',
    'P': 'nnwnwnnwn',
    'Q': 'nnnnnnwww',
    'R': 'wnnnnnwwn',
    'S': 'nnwnnnwwn',
    'T': 'nnnnwnwwn',
    'U': 'wwnnnnnnw',
    'V': 'nwwnnnnnw',
    'W': 'wwwnnnnnn',
    'X': 'nwnnwnnnw',
    'Y': 'wwnnwnnnn',
    'Z': 'nwwnwnnnn',
    '-': 'nwnnnnwnw',
    '.': 'wwnnnnwnn',
    ' ': 'nwwnnnwnn',
    '*': 'nwnnwnwnn',
    '\$': 'nwnwnwnnn',
    '/': 'nwnwnnnwn',
    '+': 'nwnnnwnwn',
    '%': 'nnnwnwnwn',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final encoded = '*${data.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-\. \$/+%]'), '')}*';
    final modules = <bool>[];
    for (var i = 0; i < encoded.length; i++) {
      final pattern = _patterns[encoded[i]] ?? _patterns['0']!;
      for (var j = 0; j < pattern.length; j++) {
        final wide = pattern[j] == 'w';
        final isBar = j.isEven;
        final units = wide ? 3 : 1;
        for (var u = 0; u < units; u++) {
          modules.add(isBar);
        }
      }
      if (i != encoded.length - 1) {
        modules.add(false);
      }
    }

    if (modules.isEmpty) return;

    const quietModules = 10;
    final totalModules = modules.length + quietModules * 2;
    final paint = Paint()..color = const Color(0xFF1C1433);
    // Snap every bar edge to a whole pixel instead of a fractional `i *
    // unit` offset: fractional offsets let rounding error accumulate
    // across the barcode, blurring edges and skewing the narrow:wide bar
    // ratio scanners rely on to tell modules apart.
    for (var i = 0; i < modules.length; i++) {
      if (!modules[i]) continue;
      final x0 = (((i + quietModules) / totalModules) * size.width).roundToDouble();
      final x1 = (((i + quietModules + 1) / totalModules) * size.width).roundToDouble();
      canvas.drawRect(
        Rect.fromLTWH(x0, 0, (x1 - x0).clamp(1, size.width), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Code39Painter oldDelegate) => oldDelegate.data != data;
}
