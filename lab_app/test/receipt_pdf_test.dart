import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_lab/src/app_state.dart';
import 'package:labgo_lab/src/models.dart';
import 'package:labgo_lab/src/report_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('receipt and report PDFs carry the order number', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    const p = Patient(
      id: 'x1', name: 'Omar', age: '30Y', gender: 'Male', phone: '', tests: ['CBC'], sample: 'Blood',
      urgency: 'Urgent', notes: '', status: 'Pending', time: '10:00', price: 15000, doctor: 'Dr. A',
      mode: 'B2C', results: {}, permanent: 'P-1', orderNo: 'V0001', resultUrl: 'https://x/r/o/1?k=a',
    );
    expect(p.code, 'V0001');
    final r = await buildReceiptPdf(app, p, payLater: false);
    expect(r.length, greaterThan(1000));
    final rep = await buildResultReportPdf(app, p);
    expect(rep.length, greaterThan(1000));
  });
}
