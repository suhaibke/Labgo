import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_lab/src/api.dart';

void main() {
  test('phones typed without the leading 0 get it back', () {
    expect(LabApi.normalizePhone('770 123 4567'), '07701234567');
    expect(LabApi.normalizePhone('07701234567'), '07701234567');
    expect(LabApi.normalizePhone('lab@labgo.iq'), 'lab@labgo.iq');
  });

  test('server data becomes the app catalog, packages and patients', () {
    final b = Bootstrap.fromJson({
      'user': {'name': 'Dr. Ahmed'},
      'lab': {'name': 'LabGo Mosul'},
      'catalog': [
        {
          'id': 't1', 'name': 'Hemoglobin', 'price': 5000, 'priceB2B': 5000, 'category': 'General', 'on': true,
          'units': 'g/dL', 'normalText': '',
          'ranges': [
            {'ageFrom': '0', 'ageTo': '120', 'ageUnit': 'Y', 'gender': 'Female', 'min': '12', 'max': '15.5'},
          ],
        },
      ],
      'packages': [
        {'id': 'p1', 'code': '', 'name': 'Full', 'category': 'General', 'aliases': ['Full'], 'tests': ['Hemoglobin'], 'price': 9000, 'priceB2B': 9000, 'active': true},
      ],
      'patients': [
        {
          'id': 'o1', 'name': 'Sara', 'age': '31Y', 'gender': 'Female', 'phone': '0770', 'tests': ['Hemoglobin'],
          'sample': 'Blood', 'urgency': 'Normal', 'notes': '', 'status': 'Pending', 'time': '09:12', 'price': 5000,
          'doctor': '', 'mode': 'B2C', 'company': null, 'results': {'Hemoglobin': '11.2'}, 'permanent': '#100245',
          'createdAt': '2026-11-13T06:12:00.000Z',
        },
      ],
    });
    expect(b.testIds['Hemoglobin'], 't1');
    expect(b.catalog.single.ranges.single.max, '15.5');
    expect(b.packages.single.tests, ['Hemoglobin']);
    final p = b.patients.single;
    expect(p.results['Hemoglobin'], '11.2');
    expect(p.permanent, '#100245');
    expect(p.createdAt, isNotNull);
  });
}
