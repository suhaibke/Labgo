import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_lab/src/app_state.dart';
import 'package:labgo_lab/src/models.dart';
import 'package:labgo_lab/src/report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('result report and shipping label PDFs are built', () async {
    final app = AppState()..lang = 'ar';
    app.licenseOwners = 'Dr. Ahmed Hamdoon Ahmed · Bacteriologist, د. سارة علي · باثولوجي';
    final p = kPatientsSeed.first.copyWith(results: {'CBC': '13.2', 'Sugar': '110'}, status: 'Completed');
    final report = await buildResultReportPdf(app, p);
    expect(String.fromCharCodes(report.sublist(0, 4)), '%PDF');
    final label = await buildLabelPdf(app, const LabelInfo(
      code: 'LG-2026-4820', patient: 'سارة علي', demographic: 'أنثى · 31 سنة', tests: 'Vitamin D, Ferritin',
      fromLab: 'LabGo Mosul', toLab: 'Al-Hayat Lab', date: '13 Nov 2026', eta: '15 Nov 2026', reference: 'EXT-1042', price: '25,000', qr: 'https://labgo.iq/r/t/x?k=y'));
    expect(String.fromCharCodes(label.sublist(0, 4)), '%PDF');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) {
      File('$out/report.pdf').writeAsBytesSync(report);
      File('$out/label.pdf').writeAsBytesSync(label);
    }
  });
}
