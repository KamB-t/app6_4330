class ShoppingItem {
  String id; // "name|unit"
  String name;
  double qty;
  String unit;
  bool checked;
  List<String> fromRecipes;

  ShoppingItem({
    required this.name,
    required this.qty,
    required this.unit,
    this.checked = false,
    this.fromRecipes = const [],
  }) : id = '$name|$unit';

  factory ShoppingItem.fromMap(Map<String, dynamic> m) => ShoppingItem(
    name: m['name'] as String,
    qty: (m['qty'] as num).toDouble(),
    unit: m['unit'] as String,
    checked: (m['checked'] ?? false) as bool,
    fromRecipes: List<String>.from(m['fromRecipes'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'unit': unit,
    'checked': checked,
    'fromRecipes': fromRecipes,
  };
}