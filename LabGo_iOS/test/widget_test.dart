// // Basic Flutter widget smoke test for LabGo.

// import 'package:flutter_test/flutter_test.dart';
// import 'package:labgo_app/main.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();

//   setUp(() {
//     SharedPreferences.setMockInitialValues({});
//   });

//   testWidgets('LabGoApp builds without crashing', (WidgetTester tester) async {
//     await tester.pumpWidget(const LabGoApp(isLoggedIn: false));
//     await tester.pump();

//     expect(find.byType(LabGoApp), findsOneWidget);
//   });
// }
