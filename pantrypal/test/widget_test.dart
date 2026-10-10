import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/helpers.dart';
import 'package:pantrypal/models/alert_item.dart';

void main() {
  test('formats RM and dates the way the screens show them', () {
    expect(formatRm(2484), 'RM2,484');
    expect(formatLongDate('2024-06-20'), 'Thu 20 Jun');
    expect(formatShortDate(null), '—');
    expect(daysLabel(0), 'Today');
    expect(daysLabel(-1), 'Expired');
    expect(daysLabel(3), '3 Days');
  });

  test('reads the /alerts summary and the alert list', () {
    final data = AlertsResponse.fromJson({
      'today': '2024-06-20',
      'expired_or_today': 1,
      'due_soon': 0,
      'total_rm_at_risk': 12.5,
      'alerts': [
        {
          'batch_id': 7,
          'product_id': 1,
          'name': 'Fresh Milk',
          'quantity': 4,
          'unit': 'L',
          'days_left': 0,
          'action': 'discount',
          'discount_pct': 30,
          'risk': 0.8,
          'explanation': 'Expires today',
        },
      ],
    });
    expect(data.alerts.single.batchId, 7);
    expect(data.alerts.single.action, 'discount');
    expect(data.expiredOrToday, 1);
  });
}