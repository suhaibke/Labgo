import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_app/src/services/order_service.dart';

void main() {
  test('a returned external-lab report is parsed as a completed patient result', () {
    final order = Order.fromJson({
      '_id': 'order-1',
      'patientId': 'patient-1',
      'labId': {
        '_id': 'lab-1',
        'name': 'Main Lab',
      },
      'tests': [
        {
          'testId': 'test-1',
          'testName': 'CBC',
          'testCode': 'CBC',
          'price': 10000,
        }
      ],
      'qrCode': 'LABGO-1',
      'location': {
        'address': 'Baghdad',
        'coordinates': {'latitude': 33.3, 'longitude': 44.4},
      },
      'status': 'completed',
      'orderType': 'home_collection',
      'pricing': {'total': 10000},
      'payment': {'status': 'paid'},
      'createdAt': '2026-08-01T10:00:00Z',
      'results': {
        'reportUrl': '/uploads/results/external-result.pdf',
        'completedAt': '2026-08-04T10:00:00Z',
      },
    });

    expect(order.isCompleted, isTrue);
    expect(order.results?['reportUrl'], '/uploads/results/external-result.pdf');
  });
}
