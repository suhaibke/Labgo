import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/code39_barcode.dart';

/// Sample sticker for the collection tube — same visual language as the invoice.
class SampleLabelScreen extends StatefulWidget {
  final Order order;

  const SampleLabelScreen({super.key, required this.order});

  @override
  State<SampleLabelScreen> createState() => _SampleLabelScreenState();
}

class _SampleLabelScreenState extends State<SampleLabelScreen> {
  static const _cardBorder = Color(0xFFE8E0F8);
  static const _qrWash = Color(0xFFF3EDFF);
  static const _ink = Color(0xFF1C1433);
  static const _muted = Color(0xFF9A93B0);
  static const _headerPurple = Color(0xFF5B3CC4);

  bool _busy = false;

  Order get _order => widget.order;

  String get _sampleCode => _order.qrCode.toUpperCase();

  String _patientName() {
    if (_order.isForOtherPerson &&
        (_order.beneficiaryName?.trim().isNotEmpty ?? false)) {
      return _order.beneficiaryName!.trim();
    }
    return _order.patientData?['name']?.toString() ?? '';
  }

  String _labName() => _order.labData?['name']?.toString() ?? '';

  String _phone() {
    if (_order.isForOtherPerson &&
        (_order.beneficiaryPhone?.trim().isNotEmpty ?? false)) {
      return _order.beneficiaryPhone!.trim();
    }
    return _order.patientData?['phone']?.toString() ??
        _order.location.phone ??
        '';
  }

  String _gender(AppLocalizations l10n) {
    final raw = (_order.patientData?['gender'] ??
            _order.beneficiary?['gender'])
        ?.toString()
        .toLowerCase();
    if (raw == 'male') return l10n.male;
    if (raw == 'female') return l10n.female;
    return raw ?? '';
  }

  String _age() {
    final raw = _order.patientData?['birthDate']?.toString() ??
        _order.patientData?['dateOfBirth']?.toString();
    if (raw == null || raw.isEmpty) return '';
    final birth = DateTime.tryParse(raw);
    if (birth == null) return '';
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years >= 0 ? '$years' : '';
  }

  String _formattedDate(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMMM yyyy', locale).format(_order.createdAt.toLocal());
  }

  Future<Uint8List> _buildPdf(AppLocalizations l10n, String locale) async {
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final isRtl = locale.startsWith('ar') || locale.startsWith('ku');
    final date = DateFormat('d MMMM yyyy', locale).format(_order.createdAt.toLocal());
    const purple = PdfColor.fromInt(0xFF7257D8);
    const muted = PdfColor.fromInt(0xFF9A93B0);
    const ink = PdfColor.fromInt(0xFF1C1433);
    const border = PdfColor.fromInt(0xFFE8E0F8);

    final tests = _order.tests.map((t) => t.testName).where((n) => n.isNotEmpty).join(' • ');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) {
          return pw.Directionality(
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border, width: 1.2),
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logo, height: 22),
                      pw.Spacer(),
                      pw.Text(
                        l10n.sampleLabel,
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: purple),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(l10n.sampleCode, style: pw.TextStyle(fontSize: 9, color: muted)),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              _sampleCode,
                              style: pw.TextStyle(font: fontBold, fontSize: 11, color: purple),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 64,
                        height: 64,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF3EDFF),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: _order.qrCode,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  _pdfRow(l10n.patient, _patientName(), fontBold, muted, ink),
                  if (_phone().isNotEmpty)
                    _pdfRow(l10n.phoneNumber, _phone(), fontBold, muted, ink),
                  if (_gender(l10n).isNotEmpty)
                    _pdfRow(l10n.gender, _gender(l10n), fontBold, muted, ink),
                  if (_age().isNotEmpty)
                    _pdfRow(l10n.age, _age(), fontBold, muted, ink),
                  _pdfRow(l10n.laboratory, _labName(), fontBold, muted, ink),
                  _pdfRow(
                    l10n.invoiceTests,
                    tests.isEmpty ? l10n.invoiceTestsCount(_order.tests.length) : tests,
                    fontBold,
                    muted,
                    ink,
                  ),
                  _pdfRow(l10n.sampleDate, date, fontBold, muted, ink),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: ink, thickness: 1),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.SizedBox(
                      width: 180,
                      height: 40,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code39(),
                        data: _sampleCode.replaceAll(RegExp(r'[^A-Z0-9\-]'), ''),
                        drawText: false,
                        color: ink,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      _sampleCode,
                      style: pw.TextStyle(fontSize: 8, color: muted, letterSpacing: 0.8),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: muted)),
          pw.Spacer(),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              textAlign: pw.TextAlign.end,
              style: pw.TextStyle(font: bold, fontSize: 10, color: ink),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runPdf(Future<void> Function(Uint8List bytes) action) async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tests = _order.tests.map((t) => t.testName).where((n) => n.isNotEmpty).join(' • ');

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
                    icon: Directionality.of(context) == ui.TextDirection.rtl
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.sampleLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _headerPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  children: [
                    Text(
                      l10n.stickOnSample,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Text(
                                  'labgo',
                                  style: TextStyle(
                                    fontSize: 20,
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
                                    l10n.sampleCollected,
                                    style: const TextStyle(
                                      color: Color(0xFF22A45A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formattedDate(context),
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.sampleCode,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _sampleCode,
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _qrWash,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: QrImageView(
                                  data: _order.qrCode,
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
                          const SizedBox(height: 14),
                          _InfoRow(label: l10n.patient, value: _patientName()),
                          if (_phone().isNotEmpty)
                            _InfoRow(label: l10n.phoneNumber, value: _phone()),
                          if (_gender(l10n).isNotEmpty)
                            _InfoRow(label: l10n.gender, value: _gender(l10n)),
                          if (_age().isNotEmpty)
                            _InfoRow(label: l10n.age, value: _age()),
                          _InfoRow(label: l10n.laboratory, value: _labName()),
                          _InfoRow(
                            label: l10n.invoiceTests,
                            value: tests.isEmpty
                                ? l10n.invoiceTestsCount(_order.tests.length)
                                : tests,
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: _ink, thickness: 1.2, height: 1),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            width: 230,
                            child: Code39Barcode(
                              data: _sampleCode.replaceAll(RegExp(r'[^A-Z0-9\-]'), ''),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _sampleCode,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _runPdf((bytes) {
                                        return Printing.layoutPdf(
                                          onLayout: (_) async => bytes,
                                        );
                                      }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _ink,
                                side: const BorderSide(color: Color(0xFFE6E2F0)),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.print_outlined, size: 20),
                              label: Text(
                                l10n.printLabel,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _runPdf((bytes) {
                                        return Printing.sharePdf(
                                          bytes: bytes,
                                          filename: 'sample-$_sampleCode.pdf',
                                        );
                                      }),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A93B0),
              fontSize: 13,
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
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
