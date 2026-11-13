import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';

final now = DateTime(2026, 11, 13, 12);

PantryItem item(String id, String name, double qty, String unit,
        [DateTime? expiry]) =>
    PantryItem(id: id, name: name, qty: qty, unit: unit, expiryDate: expiry);

Ingredient ing(String name, double qty, String unit) =>
    Ingredient(name: name, qty: qty, unit: unit);

void main() {
  test('Subtracts the amount and leaves the rest', () {
    final d = deductFromPantry(
      [ing('chicken', 500, 'g')],
      [item('a', 'chicken', 800, 'g')],
      now: now,
    );
    expect(d.newQty, {'a': 300});
    expect(d.shortfall, isEmpty);
  });

  test('Uses up an item exactly (quantity 0 means remove it)', () {
    final d = deductFromPantry(
      [ing('garlic', 3, 'count')],
      [item('a', 'garlic', 3, 'count')],
      now: now,
    );
    expect(d.newQty['a'], 0);
  });

  test('Converts units: 2 tbsp comes out of 4 l of soy sauce', () {
    final d = deductFromPantry(
      [ing('soy sauce', 2, 'tbsp')],
      [item('a', 'soy sauce', 4, 'l')],
      now: now,
    );
    expect(d.newQty['a'], closeTo(3.9704, 0.0001));
  });

  test('Uses the item that expires first, then the next one', () {
    final d = deductFromPantry(
      [ing('garlic', 3, 'count')],
      [
        item('later', 'garlic', 2, 'count', DateTime(2026, 12, 1)),
        item('soon', 'garlic', 1, 'count', DateTime(2026, 11, 15)),
        item('none', 'garlic', 5, 'count'),
      ],
      now: now,
    );
    expect(d.newQty, {'soon': 0, 'later': 0});
    expect(d.shortfall, isEmpty);
  });

  test('Expired items are never used', () {
    final d = deductFromPantry(
      [ing('milk', 500, 'ml')],
      [item('old', 'milk', 1000, 'ml', DateTime(2026, 11, 1))],
      now: now,
    );
    expect(d.newQty, isEmpty);
    expect(d.shortfall, ['milk']);
  });

  test('Not enough: uses what exists and reports the shortfall', () {
    final d = deductFromPantry(
      [ing('rice', 500, 'g'), ing('salt', 1, 'tsp')],
      [item('a', 'rice', 200, 'g')],
      now: now,
    );
    expect(d.newQty['a'], 0);
    expect(d.shortfall, ['rice', 'salt']); // rice was only partly covered
  });
}
