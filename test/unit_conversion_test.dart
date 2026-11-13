import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';

Recipe recipe(String name, List<Ingredient> ingredients) =>
    Recipe(name: name, ingredients: ingredients);

Ingredient ing(String name, double qty, String unit) =>
    Ingredient(name: name, qty: qty, unit: unit);

void main() {
  test('4 l of soy sauce covers 2 tbsp: nothing to buy', () {
    final r = recipe('Stir fry', [ing('soy sauce', 2, 'tbsp')]);
    final pantry = [PantryItem(name: 'soy sauce', qty: 4, unit: 'l')];

    expect(generateShoppingList([r], pantry), isEmpty);
    expect(rankRecipesByPantry([r], pantry).single.canMakeNow, isTrue);
  });

  test('Partial cover converts the remainder back to the recipe unit', () {
    final r = recipe('Stew', [ing('beef', 2, 'kg')]);
    final pantry = [PantryItem(name: 'beef', qty: 500, unit: 'g')];

    final list = generateShoppingList([r], pantry);

    expect(list.single.unit, 'kg');
    expect(list.single.qty, 1.5);
  });

  test('lbs and g convert', () {
    final r = recipe('Burgers', [ing('ground beef', 1, 'lbs')]);
    final pantry = [PantryItem(name: 'ground beef', qty: 500, unit: 'g')];

    expect(generateShoppingList([r], pantry), isEmpty);
  });

  test('Mass never converts to volume or count', () {
    final r = recipe('Pancakes', [ing('milk', 500, 'ml')]);
    final pantry = [
      PantryItem(name: 'milk', qty: 2, unit: 'count'),
      PantryItem(name: 'milk', qty: 1000, unit: 'g'),
    ];

    final list = generateShoppingList([r], pantry);

    expect(list.single.qty, 500);
    expect(list.single.unit, 'ml');
  });

  test('One pantry amount is not spent twice across units', () {
    final r = recipe('Sauce', [
      ing('soy sauce', 100, 'ml'),
      ing('soy sauce', 1, 'cup'),
    ]);
    final pantry = [PantryItem(name: 'soy sauce', qty: 200, unit: 'ml')];

    final list = generateShoppingList([r], pantry);

    // 100 ml covers the first line; the other 100 ml covers part of the cup.
    expect(list.length, 1);
    expect(list.single.unit, 'cup');
    expect(list.single.qty, closeTo(0.5772, 0.001));
  });

  test('Expired pantry items still do not convert into coverage', () {
    final r = recipe('Stir fry', [ing('soy sauce', 2, 'tbsp')]);
    final pantry = [
      PantryItem(
        name: 'soy sauce',
        qty: 4,
        unit: 'l',
        expiryDate: DateTime(2020, 1, 1),
      ),
    ];

    expect(generateShoppingList([r], pantry).single.qty, 2);
  });

  test('fl oz converts with ml, l and cups', () {
    final r = recipe('Dressing', [ing('olive oil', 8, 'fl oz')]);
    final pantry = [PantryItem(name: 'olive oil', qty: 1, unit: 'cup')];

    // 1 cup is 236.588 ml, exactly 8 fl oz (236.588 ml).
    expect(generateShoppingList([r], pantry), isEmpty);
    expect(
      generateShoppingList(
        [recipe('Soup', [ing('broth', 1, 'l')])],
        [PantryItem(name: 'broth', qty: 16, unit: 'fl oz')],
      ).single.qty,
      closeTo(0.5268, 0.001),
    );
  });

  test('Separate pantry rows for the same item add up (1 + 2 garlic = 3)', () {
    final r = recipe('Garlic bread', [ing('garlic', 3, 'count')]);
    final pantry = [
      PantryItem(name: 'garlic', qty: 1, unit: 'count'),
      PantryItem(
        name: ' Garlic ',
        qty: 2,
        unit: 'count',
        expiryDate: DateTime(2099, 1, 1),
      ),
    ];

    expect(generateShoppingList([r], pantry), isEmpty);
    final m = rankRecipesByPantry([r], pantry).single;
    expect(m.canMakeNow, isTrue);
    expect(m.have, 1);
  });

  test('Rows in different units of one family also add up', () {
    final r = recipe('Rice', [ing('rice', 1, 'kg')]);
    final pantry = [
      PantryItem(name: 'rice', qty: 600, unit: 'g'),
      PantryItem(name: 'rice', qty: 0.4, unit: 'kg'),
    ];

    expect(generateShoppingList([r], pantry), isEmpty);
    expect(rankRecipesByPantry([r], pantry).single.canMakeNow, isTrue);
  });
}
