/// How close a pantry item is to its expiry date.
///
///   none     no expiry date was entered
///   fresh    more than 7 days left
///   soon     4 to 7 days left (expires this week)
///   urgent   0 to 3 days left (an item that expires today is still usable)
///   expired  the expiry date has passed
enum ExpiryStatus { none, fresh, soon, urgent, expired }

class PantryItem {
  String id;
  String name; // lowercase, trimmed
  double qty;
  String unit;
  DateTime? expiryDate;

  PantryItem({
    this.id = '',
    required String name,
    required this.qty,
    required this.unit,
    this.expiryDate,
  }) : name = name.trim().toLowerCase();

  factory PantryItem.fromMap(Map<String, dynamic> m, {String id = ''}) =>
      PantryItem(
        id: id,
        name: m['name'] as String,
        qty: (m['qty'] as num).toDouble(),
        unit: m['unit'] as String,
        expiryDate: m['expiryDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['expiryDate'] as int),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'unit': unit,
    'expiryDate': expiryDate?.millisecondsSinceEpoch,
  };

  /// Whole calendar days from today until the expiry date: 0 means it expires
  /// today, negative means it already expired. Null if there is no expiry date.
  /// [now] exists so tests can pin "today".
  int? daysUntilExpiry([DateTime? now]) {
    final e = expiryDate;
    if (e == null) return null;
    final t = now ?? DateTime.now();
    // UTC dates, so a daylight-saving change can't shift the count by a day.
    final today = DateTime.utc(t.year, t.month, t.day);
    final expiry = DateTime.utc(e.year, e.month, e.day);
    return expiry.difference(today).inDays;
  }

  bool isExpired([DateTime? now]) {
    final d = daysUntilExpiry(now);
    return d != null && d < 0;
  }

  ExpiryStatus expiryStatus([DateTime? now]) {
    final d = daysUntilExpiry(now);
    if (d == null) return ExpiryStatus.none;
    if (d < 0) return ExpiryStatus.expired;
    if (d <= 3) return ExpiryStatus.urgent;
    if (d <= 7) return ExpiryStatus.soon;
    return ExpiryStatus.fresh;
  }
}
