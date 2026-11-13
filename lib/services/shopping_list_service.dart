import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/models/shopping_item.dart';

/// Builds the shopping list for the week.
///
/// [planRecipes] has one entry per assigned plan slot, so a recipe planned
/// twice appears twice and its ingredients count twice.
List<ShoppingItem> generateShoppingList(
    List<Recipe> planRecipes,
    List<PantryItem> pantryItems,
    ) {
  // Steps 1-3: collect, normalize, and group by name + unit.
  final grouped = <String, ShoppingItem>{};
  for (final recipe in planRecipes) {
    for (final ing in recipe.ingredients) {
      final name = ing.name.trim().toLowerCase();
      final key = '$name|${ing.unit}';
      final item = grouped.putIfAbsent(
        key,
            () => ShoppingItem(
            name: name, qty: 0, unit: ing.unit, fromRecipes: <String>[]),
      );
      item.qty += ing.qty;
      if (!item.fromRecipes.contains(recipe.name)) {
        item.fromRecipes.add(recipe.name);
      }
    }
  }

  // Step 4: subtract pantry. Exact name + exact unit only, no conversion.
  final pantryQty = <String, double>{};
  for (final p in pantryItems) {
    final key = '${p.name.trim().toLowerCase()}|${p.unit}';
    pantryQty[key] = (pantryQty[key] ?? 0) + p.qty;
  }

  final result = <ShoppingItem>[];
  for (final item in grouped.values) {
    final remaining = item.qty - (pantryQty[item.id] ?? 0);
    if (remaining <= 0.0001) continue; // fully covered by the pantry
    item.qty = _round(remaining);
    result.add(item);
  }

  // Step 5: sort alphabetically by name.
  result.sort((a, b) {
    final byName = a.name.compareTo(b.name);
    return byName != 0 ? byName : a.unit.compareTo(b.unit);
  });
  return result;
}

// Avoids results like 0.30000000000000004 from decimal arithmetic.
double _round(double v) => (v * 10000).round() / 10000;

/// Monday and Sunday (both at midnight) of the week containing [now].
List<DateTime> currentWeekRange([DateTime? now]) {
  final t = now ?? DateTime.now();
  final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1));
  return [monday, DateTime(monday.year, monday.month, monday.day + 6)];
}