const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2024-06-20" -> "Thu 20 Jun". Uses the date from the server, not the phone.
String formatLongDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "2026-10-09" -> "09 Oct". Returns a dash when the date is missing.
String formatShortDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
}

/// 44.0 -> "44", 44.2 -> "44.2"
String formatQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

/// 2484 -> "RM2,484"
String formatRm(double value) {
  final digits = value.round().toString();
  final withCommas = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'RM$withCommas';
}

/// days_left -> badge text
String daysLabel(int daysLeft) {
  if (daysLeft < 0) return 'Expired';
  if (daysLeft == 0) return 'Today';
  if (daysLeft == 1) return '1 Day';
  return '$daysLeft Days';
}