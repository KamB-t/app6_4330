import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/models/shopping_item.dart';

// ---------------------------------------------------------------------------
// Basic unit conversion
// ---------------------------------------------------------------------------
// Units convert only inside their own family: mass (g, kg, lbs), volume (ml,
// l, tsp, tbsp, cup, fl oz) and count. Mass never converts to volume (no densities),
// and an unknown unit only matches itself.

const Map<String, double> _massToG = {'g': 1, 'kg': 1000, 'lbs': 453.592};
const Map<String, double> _volumeToMl = {
  'ml': 1,
  'l': 1000,
  'tsp': 4.92892,
  'tbsp': 14.7868,
  'cup': 236.588,
  'fl oz': 29.5735,
};

/// "mass", "volume", or the unit itself when it has no conversions.
String unitFamily(String unit) {
  if (_massToG.containsKey(unit)) return 'mass';
  if (_volumeToMl.containsKey(unit)) return 'volume';
  return unit;
}

/// [qty] expressed in the family's base unit (g or ml; others unchanged).
double toBaseQty(double qty, String unit) =>
    qty * (_massToG[unit] ?? _volumeToMl[unit] ?? 1);

/// Inverse of [toBaseQty].
double fromBaseQty(double base, String unit) =>
    base / (_massToG[unit] ?? _volumeToMl[unit] ?? 1);

/// Pantry totals in base units, keyed "name|family". Expired items skipped.
Map<String, double> _pantryBase(List<PantryItem> pantryItems, DateTime? now) {
  final out = <String, double>{};
  for (final p in pantryItems) {
    if (p.isExpired(now)) continue; // expired food can't cover a recipe
    final key = '${p.name.trim().toLowerCase()}|${unitFamily(p.unit)}';
    out[key] = (out[key] ?? 0) + toBaseQty(p.qty, p.unit);
  }
  return out;
}

/// Builds the shopping list for the week.
///
/// [planRecipes] has one entry per assigned plan slot, so a recipe planned
/// twice appears twice and its ingredients count twice.
///
/// Expired pantry items are ignored, so they never reduce what you need to buy.
/// Pantry amounts convert within a unit family, so 4 l of soy sauce covers a
/// recipe that asks for 2 tbsp.
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

  // Step 4: subtract pantry. Same name; units convert within a family, and
  // each pantry amount is used up once (two recipe lines for the same food in
  // different units can't both spend the same bottle).
  final pantry = _pantryBase(pantryItems, now);

  final result = <ShoppingItem>[];
  for (final item in grouped.values) {
    final key = '${item.name}|${unitFamily(item.unit)}';
    final needBase = toBaseQty(item.qty, item.unit);
    final owned = pantry[key] ?? 0;
    final used = owned < needBase ? owned : needBase;
    pantry[key] = owned - used;
    final remainingBase = needBase - used;
    if (remainingBase <= 0.001) continue; // fully covered by the pantry
    item.qty = _round(fromBaseQty(remainingBase, item.unit));
    if (item.qty <= 0) continue;
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

  /// Ingredients fully covered: same name and enough quantity (units convert
  /// within a family, e.g. 4 l covers 2 tbsp).
  final int have;

  /// Ingredients where the pantry has the name, but not enough of it, or it
  /// is stored in a unit that can't convert (e.g. grams vs. count).
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
/// Uses the same rules as [generateShoppingList]: exact name, no fuzzy
/// matching, units converted within a family, and expired pantry items
/// ignored. Ties are broken by fewer missing ingredients, then by recipe name.
List<RecipeMatch> rankRecipesByPantry(
  List<Recipe> recipes,
  List<PantryItem> pantryItems, {
  DateTime? now, // only tests pass this, to pin "today"
}) {
  final pantry = _pantryBase(pantryItems, now); // "name|family" -> base qty
  final pantryNames = <String>{};
  for (final p in pantryItems) {
    if (p.isExpired(now)) continue; // expired food is not "available"
    pantryNames.add(p.name.trim().toLowerCase());
  }

  final matches = <RecipeMatch>[];
  for (final recipe in recipes) {
    var have = 0;
    var low = 0;
    final missing = <String>[];
    for (final ing in recipe.ingredients) {
      final name = ing.name.trim().toLowerCase();
      final owned = pantry['$name|${unitFamily(ing.unit)}'] ?? 0;
      if (owned >= toBaseQty(ing.qty, ing.unit) - 0.001) {
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


// ---------------------------------------------------------------------------
// Using a recipe's ingredients up
// ---------------------------------------------------------------------------

/// What starting a recipe does to the pantry.
class PantryDeduction {
  /// Pantry item id -> quantity left, in that item's own unit. 0 means the
  /// item is used up and should be removed. Items not listed are untouched.
  final Map<String, double> newQty;

  /// Ingredients the pantry couldn't fully cover (everything usable was used).
  final List<String> shortfall;

  const PantryDeduction(this.newQty, this.shortfall);
}

/// Subtracts [ingredients] from [pantryItems]. Same rules as the shopping
/// list: matching name, units convert within a family, expired items are never
/// used. Items that expire soonest are used first.
PantryDeduction deductFromPantry(
  List<Ingredient> ingredients,
  List<PantryItem> pantryItems, {
  DateTime? now, // only tests pass this, to pin "today"
}) {
  final usable = pantryItems.where((p) => !p.isExpired(now)).toList()
    ..sort((a, b) {
      final ea = a.expiryDate, eb = b.expiryDate;
      if (ea == null && eb == null) return 0;
      if (ea == null) return 1; // no expiry date: use last
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });

  final leftBase = {for (final p in usable) p.id: toBaseQty(p.qty, p.unit)};
  final touched = <String>{};
  final shortfall = <String>[];

  for (final ing in ingredients) {
    final name = ing.name.trim().toLowerCase();
    final family = unitFamily(ing.unit);
    var need = toBaseQty(ing.qty, ing.unit);
    for (final p in usable) {
      if (need <= 0.001) break;
      if (p.name != name || unitFamily(p.unit) != family) continue;
      final avail = leftBase[p.id]!;
      if (avail <= 0) continue;
      final take = avail < need ? avail : need;
      leftBase[p.id] = avail - take;
      need -= take;
      touched.add(p.id);
    }
    if (need > 0.001) shortfall.add(name);
  }

  final newQty = <String, double>{};
  for (final p in usable) {
    if (!touched.contains(p.id)) continue;
    final left = _round(fromBaseQty(leftBase[p.id]!, p.unit));
    newQty[p.id] = left <= 0.0001 ? 0 : left;
  }
  return PantryDeduction(newQty, shortfall);
}
