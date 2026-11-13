import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_lab/main.dart';

void main() {
  testWidgets('app boots to login, in Arabic first', (tester) async {
    await tester.pumpWidget(const LabGoLabApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('تصفح كضيف'), findsOneWidget);
  });
}
