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
}