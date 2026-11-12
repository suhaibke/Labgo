import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_app/src/utils/package_share.dart';

void main() {
  group('packageShareText', () {
    test('contains the package details, total price and link, in order', () {
      final text = packageShareText(
        packageId: 'abc123',
        packageName: 'تساقط الشعر',
        testNames: ['فيتامين د', 'TSH'],
        price: 40000,
      );

      expect(
        text,
        'باقة تساقط الشعر\n\n'
        'الفحوصات المشمولة:\n'
        '• فيتامين د\n'
        '• TSH\n\n'
        'السعر الكلي: 40000 د.ع\n\n'
        'https://labgo-iq.com/p/abc123',
      );
    });

    test('omits the tests heading when the package has no tests', () {
      final text = packageShareText(
        packageId: 'abc123',
        packageName: 'باقة',
        testNames: const [],
        price: 1000,
      );

      expect(text, isNot(contains('الفحوصات المشمولة')));
    });
  });

  group('packageIdFromLink', () {
    final cases = <String, String?>{
      'labgo://package/abc123': 'abc123',
      'https://labgo-iq.com/p/abc123': 'abc123',
      'https://www.labgo-iq.com/p/abc123': 'abc123',
      'http://labgo-iq.com/p/abc123': null,
      'https://evil.example/p/abc123': null,
      'https://labgo-iq.com/shop/abc123': null,
      'https://labgo-iq.com/p/': null,
      'labgo://other/abc123': null,
      'labgo://package': null,
    };

    cases.forEach((link, expected) {
      test('$link -> $expected', () {
        expect(packageIdFromLink(Uri.parse(link)), expected);
      });
    });
  });
}
