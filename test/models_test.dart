import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/recipe.dart';

void main() {
  test('Recipe toMap then fromMap keeps name, ingredients, prep time', () {
    final r = Recipe(
      name: 'Tacos',
      prepTimeMinutes: 20,
      ingredients: [
        Ingredient(name: ' Ground Beef ', qty: 500, unit: 'g'),
        Ingredient(name: 'tortillas', qty: 8, unit: 'count'),
      ],
    );
    final back = Recipe.fromMap(r.toMap());
    expect(back.name, 'Tacos');
    expect(back.prepTimeMinutes, 20);
    expect(back.ingredients.length, 2);
    expect(back.ingredients[0].name, 'ground beef');
    expect(back.ingredients[0].qty, 500);
    expect(back.ingredients[0].unit, 'g');
  });
}