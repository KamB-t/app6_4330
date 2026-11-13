import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planner/models/meal_plan.dart';
import 'package:meal_planner/models/recipe.dart';

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

  test('MealPlan id matches yyyy-MM-dd_meal', () {
    final p = MealPlan(
      date: DateTime(2026, 11, 16),
      meal: 'dinner',
      recipeId: 'r1',
      recipeName: 'Tacos',
    );
    expect(p.id, '2026-11-16_dinner');
  });
}