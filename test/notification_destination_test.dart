import 'package:flutter_test/flutter_test.dart';
import 'package:labgo_app/src/services/notification_destination.dart';

void main() {
  test('results-ready notifications open the patient results tab', () {
    expect(mainTabForNotificationType('results_ready'), 2);
  });

  test('admin-created order notifications open the patient order list', () {
    expect(mainTabForNotificationType('order_accepted'), 2);
  });

  test('unrelated notifications keep the default main tab', () {
    expect(mainTabForNotificationType('lab_offer'), 0);
    expect(mainTabForNotificationType(null), 0);
  });
}
