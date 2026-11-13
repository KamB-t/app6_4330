import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';

Recipe recipe(String name, List<Ingredient> ingredients) =>
    Recipe(name: name, ingredients: ingredients);

void main() {
  test('Combining: ground beef 500 g + 300 g becomes one item at 800 g', () {
    final tacos = recipe('Tacos', [Ingredient(name: 'ground beef', qty: 500, unit: 'g')]);
    final spaghetti = recipe('Spaghetti', [Ingredient(name: 'ground beef', qty: 300, unit: 'g')]);

    final list = generateShoppingList([tacos, spaghetti], []);

    expect(list.length, 1);
    expect(list.first.name, 'ground beef');
    expect(list.first.qty, 800);
    expect(list.first.unit, 'g');
    expect(list.first.fromRecipes, ['Tacos', 'Spaghetti']);
  });

  test('Pantry subtraction: need 500 g chicken, pantry has 300 g -> 200 g', () {
    final r = recipe('Stir fry', [Ingredient(name: 'chicken', qty: 500, unit: 'g')]);
    final pantry = [PantryItem(name: 'chicken', qty: 300, unit: 'g')];

    final list = generateShoppingList([r], pantry);

    expect(list.length, 1);
    expect(list.first.qty, 200);
  });

  test('Full coverage: pantry 500 g covers 500 g chicken, no chicken item', () {
    final r = recipe('Stir fry', [Ingredient(name: 'chicken', qty: 500, unit: 'g')]);
    final pantry = [PantryItem(name: 'chicken', qty: 500, unit: 'g')];

    final list = generateShoppingList([r], pantry);

    expect(list.where((i) => i.name == 'chicken'), isEmpty);
  });

  test('Unit mismatch: 500 ml milk with pantry 2 count milk stays 500 ml', () {
    final r = recipe('Pancakes', [Ingredient(name: 'milk', qty: 500, unit: 'ml')]);
    final pantry = [PantryItem(name: 'milk', qty: 2, unit: 'count')];

    final list = generateShoppingList([r], pantry);

    expect(list.length, 1);
    expect(list.first.qty, 500);
    expect(list.first.unit, 'ml');
  });

  test('Double assignment: same recipe twice counts its ingredients twice', () {
    final r = recipe('Stir fry', [Ingredient(name: 'rice', qty: 200, unit: 'g')]);

    final list = generateShoppingList([r, r], []);

    expect(list.length, 1);
    expect(list.first.qty, 400);
    expect(list.first.fromRecipes, ['Stir fry']); // name listed once
  });

  test('Empty plan: no assigned recipes gives an empty list', () {
    expect(generateShoppingList([], []), isEmpty);
    expect(
      generateShoppingList([], [PantryItem(name: 'rice', qty: 1, unit: 'lbs')]),
      isEmpty,
    );
  });
}