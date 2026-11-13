import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';

// Pinned "today" so the tests never depend on the real date.
final now = DateTime(2026, 11, 13, 15, 30);

PantryItem item(String name, double qty, String unit, DateTime? expiry) =>
    PantryItem(name: name, qty: qty, unit: unit, expiryDate: expiry);

Recipe chickenRecipe() => Recipe(
      name: 'Chicken',
      ingredients: [Ingredient(name: 'chicken', qty: 500, unit: 'g')],
    );

void main() {
  group('expiryStatus', () {
    ExpiryStatus at(DateTime? d) => item('x', 1, 'g', d).expiryStatus(now);

    test('no expiry date has no status', () {
      expect(at(null), ExpiryStatus.none);
      expect(item('x', 1, 'g', null).isExpired(now), false);
    });
    test('yesterday is expired', () {
      expect(at(DateTime(2026, 11, 12)), ExpiryStatus.expired);
    });
    test('today and the next 3 days are red', () {
      expect(at(DateTime(2026, 11, 13)), ExpiryStatus.urgent);
      expect(at(DateTime(2026, 11, 16)), ExpiryStatus.urgent);
    });
    test('4 to 7 days is yellow', () {
      expect(at(DateTime(2026, 11, 17)), ExpiryStatus.soon);
      expect(at(DateTime(2026, 11, 20)), ExpiryStatus.soon);
    });
    test('more than 7 days is green', () {
      expect(at(DateTime(2026, 11, 21)), ExpiryStatus.fresh);
    });
  });

  group('expired pantry items are ignored', () {
    test('shopping list still needs the full amount', () {
      final list = generateShoppingList(
        [chickenRecipe()],
        [item('chicken', 500, 'g', DateTime(2026, 11, 12))],
        now: now,
      );
      expect(list.single.qty, 500);
    });

    test('item expiring today still covers the recipe', () {
      final list = generateShoppingList(
        [chickenRecipe()],
        [item('chicken', 500, 'g', DateTime(2026, 11, 13))],
        now: now,
      );
      expect(list, isEmpty);
    });

    test('expired items do not make a recipe recommendable', () {
      final m = rankRecipesByPantry(
        [chickenRecipe()],
        [item('chicken', 500, 'g', DateTime(2026, 11, 12))],
        now: now,
      ).single;
      expect(m.canMakeNow, false);
      expect(m.have, 0);
    });
  });
}
