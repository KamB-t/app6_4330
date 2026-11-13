import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';

Recipe recipe(String name, List<Ingredient> ingredients) =>
    Recipe(name: name, ingredients: ingredients);

Ingredient ing(String name, double qty, String unit) =>
    Ingredient(name: name, qty: qty, unit: unit);

void main() {
  test('Fully covered recipe can be made now and has nothing missing', () {
    final r = recipe('Rice bowl', [ing('rice', 200, 'g'), ing('egg', 2, 'count')]);
    final pantry = [
      PantryItem(name: 'rice', qty: 500, unit: 'g'),
      PantryItem(name: 'egg', qty: 6, unit: 'count'),
    ];

    final m = rankRecipesByPantry([r], pantry).single;

    expect(m.canMakeNow, isTrue);
    expect(m.have, 2);
    expect(m.total, 2);
    expect(m.missing, isEmpty);
    expect(m.score, 1);
  });

  test('Name in pantry but not enough counts as low and is listed as missing', () {
    final r = recipe('Stir fry', [ing('chicken', 500, 'g')]);
    final pantry = [PantryItem(name: 'chicken', qty: 300, unit: 'g')];

    final m = rankRecipesByPantry([r], pantry).single;

    expect(m.canMakeNow, isFalse);
    expect(m.have, 0);
    expect(m.low, 1);
    expect(m.missing, ['chicken']);
    expect(m.score, 0.5);
  });

  test('Unit mismatch is not covered (units are never converted)', () {
    final r = recipe('Pancakes', [ing('milk', 500, 'ml')]);
    final pantry = [PantryItem(name: 'milk', qty: 2, unit: 'count')];

    final m = rankRecipesByPantry([r], pantry).single;

    expect(m.have, 0);
    expect(m.low, 1);
    expect(m.canMakeNow, isFalse);
  });

  test('Best match comes first', () {
    final half = recipe('Half', [ing('rice', 100, 'g'), ing('beans', 100, 'g')]);
    final full = recipe('Full', [ing('rice', 100, 'g'), ing('salt', 1, 'tsp')]);
    final none = recipe('None', [ing('truffle', 1, 'count')]);
    final pantry = [
      PantryItem(name: 'rice', qty: 500, unit: 'g'),
      PantryItem(name: 'salt', qty: 5, unit: 'tsp'),
    ];

    final ranked = rankRecipesByPantry([none, half, full], pantry);

    expect(ranked.map((m) => m.recipe.name).toList(), ['Full', 'Half', 'None']);
  });

  test('Empty pantry: nothing is ready and every ingredient is missing', () {
    final r = recipe('Salad', [ing('lettuce', 200, 'g'), ing('tomato', 2, 'count')]);

    final m = rankRecipesByPantry([r], []).single;

    expect(m.canMakeNow, isFalse);
    expect(m.have, 0);
    expect(m.missing, ['lettuce', 'tomato']);
    expect(m.score, 0);
  });

  test('Pantry rows with the same name and unit are added together', () {
    final r = recipe('Bread', [ing('flour', 500, 'g')]);
    final pantry = [
      PantryItem(name: 'flour', qty: 300, unit: 'g'),
      PantryItem(name: 'Flour ', qty: 250, unit: 'g'),
    ];

    expect(rankRecipesByPantry([r], pantry).single.canMakeNow, isTrue);
  });
}
