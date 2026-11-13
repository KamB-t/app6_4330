import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/models/shopping_item.dart';

/// Builds the shopping list for the week.
///
/// [planRecipes] has one entry per assigned plan slot, so a recipe planned
/// twice appears twice and its ingredients count twice.
///
/// Expired pantry items are ignored, so they never reduce what you need to buy.
List<ShoppingItem> generateShoppingList(
    List<Recipe> planRecipes,
    List<PantryItem> pantryItems, {
    DateTime? now, // only tests pass this, to pin "today"
    }) {
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
    if (p.isExpired(now)) continue; // expired food can't cover a recipe
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

// ---------------------------------------------------------------------------
// Pantry-based recipe recommendations
// ---------------------------------------------------------------------------

/// How well one recipe is covered by the pantry.
class RecipeMatch {
  final Recipe recipe;

  /// Ingredients fully covered: same name, same unit, enough quantity.
  final int have;

  /// Ingredients where the pantry has the name, but not enough of it, or it
  /// is stored in a different unit (units are never converted).
  final int low;

  /// Total ingredients in the recipe.
  final int total;

  /// Names of ingredients that are missing or low (what you would still buy).
  final List<String> missing;

  const RecipeMatch({
    required this.recipe,
    required this.have,
    required this.low,
    required this.total,
    required this.missing,
  });

  /// 0 to 1. A "low" ingredient counts as half, because you own some of it.
  double get score => total == 0 ? 0 : (have + 0.5 * low) / total;

  /// Every ingredient is in the pantry in a big enough amount.
  bool get canMakeNow => total > 0 && have == total;
}

/// Scores every recipe against the pantry, best match first.
///
/// Uses the same rules as [generateShoppingList]: exact name, exact unit, no
/// fuzzy matching and no unit conversion, and expired pantry items are
/// ignored. Ties are broken by fewer missing ingredients, then by recipe name.
List<RecipeMatch> rankRecipesByPantry(
  List<Recipe> recipes,
  List<PantryItem> pantryItems, {
  DateTime? now, // only tests pass this, to pin "today"
}) {
  final pantryQty = <String, double>{}; // "name|unit" -> total quantity
  final pantryNames = <String>{};
  for (final p in pantryItems) {
    if (p.isExpired(now)) continue; // expired food is not "available"
    final name = p.name.trim().toLowerCase();
    pantryNames.add(name);
    final key = '$name|${p.unit}';
    pantryQty[key] = (pantryQty[key] ?? 0) + p.qty;
  }

  final matches = <RecipeMatch>[];
  for (final recipe in recipes) {
    var have = 0;
    var low = 0;
    final missing = <String>[];
    for (final ing in recipe.ingredients) {
      final name = ing.name.trim().toLowerCase();
      final owned = pantryQty['$name|${ing.unit}'] ?? 0;
      if (owned >= ing.qty - 0.0001) {
        have++;
      } else if (pantryNames.contains(name)) {
        low++;
        missing.add(name);
      } else {
        missing.add(name);
      }
    }
    matches.add(RecipeMatch(
      recipe: recipe,
      have: have,
      low: low,
      total: recipe.ingredients.length,
      missing: missing,
    ));
  }

  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byMissing = a.missing.length.compareTo(b.missing.length);
    if (byMissing != 0) return byMissing;
    return a.recipe.name.compareTo(b.recipe.name);
  });
  return matches;
}
