double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// One alert from GET /alerts.
class AlertItem {
  final int batchId;
  final int productId;
  final String name;
  final double quantity;
  final String unit;
  final int daysLeft;
  final String priority; // high / medium / ...
  final String issueType; // expiring_soon / expired / ...
  final String action; // discount / monitor / remove / donate / ...
  final int discountPct;
  final double risk; // 0.0 to 1.0
  final double expectedWasteUnits;
  final double rmAtRisk;
  final double expectedRmSaved;
  final String explanation;

  const AlertItem({
    required this.batchId,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.daysLeft,
    required this.priority,
    required this.issueType,
    required this.action,
    required this.discountPct,
    required this.risk,
    required this.expectedWasteUnits,
    required this.rmAtRisk,
    required this.expectedRmSaved,
    required this.explanation,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        batchId: _int(j['batch_id']),
        productId: _int(j['product_id']),
        name: j['name']?.toString() ?? '',
        quantity: _num(j['quantity']),
        unit: j['unit']?.toString() ?? '',
        daysLeft: _int(j['days_left']),
        priority: j['priority']?.toString() ?? '',
        issueType: j['issue_type']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        discountPct: _int(j['discount_pct']),
        risk: _num(j['risk']),
        expectedWasteUnits: _num(j['expected_waste_units']),
        rmAtRisk: _num(j['rm_at_risk']),
        expectedRmSaved: _num(j['expected_rm_saved']),
        explanation: j['explanation']?.toString() ?? '',
      );
}

/// The whole GET /alerts response.
class AlertsResponse {
  final String today; // the server's date, e.g. "2024-06-20"
  final int expiredOrToday;
  final int dueSoon;
  final double totalRmAtRisk;
  final double totalExpectedRmSaved;
  final List<AlertItem> alerts;

  const AlertsResponse({
    required this.today,
    required this.expiredOrToday,
    required this.dueSoon,
    required this.totalRmAtRisk,
    required this.totalExpectedRmSaved,
    required this.alerts,
  });

  factory AlertsResponse.fromJson(Map<String, dynamic> j) => AlertsResponse(
        today: j['today']?.toString() ?? '',
        expiredOrToday: _int(j['expired_or_today']),
        dueSoon: _int(j['due_soon']),
        totalRmAtRisk: _num(j['total_rm_at_risk']),
        totalExpectedRmSaved: _num(j['total_expected_rm_saved']),
        alerts: [
          for (final a in (j['alerts'] as List? ?? []))
            AlertItem.fromJson(a as Map<String, dynamic>),
        ],
      );
}