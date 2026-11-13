import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/meal_api_service.dart';

void main() {
  group('parseMeasure', () {
    void check(String raw, double qty, String unit) {
      final p = parseMeasure(raw);
      expect(p.qty, closeTo(qty, 0.001), reason: raw);
      expect(p.unit, unit, reason: raw);
    }

    test('metric with and without a space', () {
      check('500g', 500, 'g');
      check('1.5 kg', 1.5, 'kg');
      check('250 ml', 250, 'ml');
      check('2 Litres', 2, 'l');
    });
    test('fractions and mixed numbers', () {
      check('1/2 cup', 0.5, 'cup');
      check('1 1/2 cups', 1.5, 'cup');
      check('1½ tsp', 1.5, 'tsp');
    });
    test('spoons', () {
      check('2 tbs', 2, 'tbsp');
      check('1 Tablespoon', 1, 'tbsp');
      check('3 teaspoons', 3, 'tsp');
    });
    test('ranges use the first number', () {
      check('2-3 cups', 2, 'cup');
    });
    test('pounds, fluid ounces and ounces', () {
      check('1 lb', 1, 'lbs');
      check('8 fl oz', 8, 'fl oz');
      check('2 oz', 56.699, 'g');
    });
    test('unknown units are counted', () {
      check('3 cloves', 3, 'count');
      check('1 large', 1, 'count');
    });
    test('no number', () {
      check('Pinch', 0.25, 'tsp');
      check('sprinkling', 0.25, 'tsp');
      check('1 tin ', 1, 'count');
      check('1 pound', 1, 'lbs');
      check('To taste', 1, 'count');
      check('', 1, 'count');
    });
  });

  group('mealToRecipe', () {
    test('builds a recipe from a TheMealDB meal', () {
      final r = mealToRecipe({
        'strMeal': 'Garlic Chicken',
        'strCategory': 'Chicken',
        'strArea': 'Italian',
        'strTags': 'Quick,Easy',
        'strInstructions': 'Cook it.',
        'strMealThumb': 'https://example.com/chicken.jpg',
        'strIngredient1': 'Chicken Breast',
        'strMeasure1': '500g',
        'strIngredient2': 'Garlic',
        'strMeasure2': '3 cloves',
        'strIngredient3': '',
        'strMeasure3': ' ',
        'strIngredient4': null,
      })!;

      expect(r.name, 'Garlic Chicken');
      expect(r.ingredients.length, 2);
      expect(r.ingredients[0].name, 'chicken breast');
      expect(r.ingredients[0].qty, 500);
      expect(r.ingredients[0].unit, 'g');
      expect(r.ingredients[1].unit, 'count');
      expect(r.tags, ['chicken', 'italian', 'quick', 'easy']);
      expect(r.instructions, 'Cook it.');
      expect(r.imageUrl, 'https://example.com/chicken.jpg');
      expect(Recipe.fromMap(r.toMap()).imageUrl, r.imageUrl);
    });

    test('returns null without a name or ingredients', () {
      expect(mealToRecipe({'strMeal': ''}), isNull);
      expect(mealToRecipe({'strMeal': 'Empty'}), isNull);
    });
  });
}
