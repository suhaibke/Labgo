import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_lab/src/app_state.dart';
import 'package:labgo_lab/src/models.dart';
import 'package:labgo_lab/src/report_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app's sound player talks to a native plugin that tests do not have.
  for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
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

  test('the WhatsApp / SMS message carries the short result link', () {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    const base = Patient(
      id: 'x2', name: 'Omar', age: '30Y', gender: 'Male', phone: '', tests: ['CBC'], sample: 'Blood',
      urgency: 'Normal', notes: '', status: 'Completed', time: '10:00', price: 15000, doctor: '',
      mode: 'B2C', results: {'CBC': '13'}, permanent: 'P-2',
    );
    expect(app.resultMessage(base).contains('/r/'), isFalse);
    const linked = Patient(
      id: 'x3', name: 'Omar', age: '30Y', gender: 'Male', phone: '', tests: ['CBC'], sample: 'Blood',
      urgency: 'Normal', notes: '', status: 'Completed', time: '10:00', price: 15000, doctor: '',
      mode: 'B2C', results: {'CBC': '13'}, permanent: 'P-3', resultUrl: 'https://labgo.test/r/qB4aJimx',
    );
    final msg = app.resultMessage(linked);
    expect(msg, contains('https://labgo.test/r/qB4aJimx'));
    expect(msg, contains('PDF'));
  });
}
