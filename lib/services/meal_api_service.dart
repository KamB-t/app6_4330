import 'dart:convert';
import 'dart:io';

import 'package:project6/models/recipe.dart';

// ---------------------------------------------------------------------------
// Online recipes from TheMealDB (https://www.themealdb.com/api.php)
// ---------------------------------------------------------------------------
// Free test key "1", no sign-up. Uses dart:io's HttpClient so no extra
// package is needed. Online recipes give ingredient amounts as free text
// ("1/2 cup", "500g", "3 cloves"), so [parseMeasure] turns them into the
// quantity + unit the rest of the app understands.

class MealApi {
  static const _base = 'https://www.themealdb.com/api/json/v1/1';

  /// Searched together to fill the screen before the user types anything.
  static const featuredQueries = [
    'chicken',
    'beef',
    'pasta',
    'salmon',
    'egg',
    'rice',
  ];

  /// Recipes whose name matches [query].
  Future<List<Recipe>> search(String query) async {
    final uri = Uri.parse('$_base/search.php')
        .replace(queryParameters: {'s': query.trim()});
    final json = await _getJson(uri);
    final meals = json['meals'];
    if (meals is! List) return []; // the API sends null when nothing matches
    final out = <Recipe>[];
    for (final m in meals) {
      if (m is! Map<String, dynamic>) continue;
      final r = mealToRecipe(m);
      if (r != null) out.add(r);
    }
    return out;
  }

  /// A mixed starter list (a few recipes per popular search, no duplicates).
  Future<List<Recipe>> featured() async {
    Object? firstError;
    var failures = 0;
    final lists = await Future.wait(featuredQueries.map((q) async {
      try {
        return (await search(q)).take(5).toList();
      } catch (e) {
        failures++;
        firstError ??= e;
        return <Recipe>[];
      }
    }));
    if (failures == featuredQueries.length) throw firstError!;

    final seen = <String>{};
    return [
      for (final list in lists)
        for (final r in list)
          if (seen.add(r.name.toLowerCase())) r,
    ];
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw HttpException('Server returned ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}

/// Converts one TheMealDB meal object to a [Recipe]. Null if it has no name or
/// no ingredients.
Recipe? mealToRecipe(Map<String, dynamic> m) {
  final name = (m['strMeal'] ?? '').toString().trim();
  if (name.isEmpty) return null;

  final ingredients = <Ingredient>[];
  for (var i = 1; i <= 20; i++) {
    final ingredient = (m['strIngredient$i'] ?? '').toString().trim();
    if (ingredient.isEmpty) continue;
    final parsed = parseMeasure((m['strMeasure$i'] ?? '').toString());
    ingredients.add(
      Ingredient(name: ingredient, qty: parsed.qty, unit: parsed.unit),
    );
  }
  if (ingredients.isEmpty) return null;

  final tags = <String>[];
  void addTag(Object? v) {
    final t = (v ?? '').toString().trim().toLowerCase();
    if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
  }

  addTag(m['strCategory']);
  addTag(m['strArea']);
  for (final t in (m['strTags'] ?? '').toString().split(',')) {
    addTag(t);
  }

  return Recipe(
    name: name,
    ingredients: ingredients,
    instructions: (m['strInstructions'] ?? '').toString().trim(),
    tags: tags,
  );
}

class ParsedMeasure {
  final double qty;
  final String unit;
  const ParsedMeasure(this.qty, this.unit);
}

const _unitWords = <String, String>{
  'g': 'g', 'gr': 'g', 'gram': 'g', 'grams': 'g',
  'kg': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'kilogram': 'kg', 'kilograms': 'kg',
  'lb': 'lbs', 'lbs': 'lbs', 'pound': 'lbs', 'pounds': 'lbs',
  'ml': 'ml', 'milliliter': 'ml', 'milliliters': 'ml',
  'millilitre': 'ml', 'millilitres': 'ml',
  'l': 'l', 'liter': 'l', 'liters': 'l', 'litre': 'l', 'litres': 'l',
  'tbs': 'tbsp', 'tbsp': 'tbsp', 'tblsp': 'tbsp',
  'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
  'tsp': 'tsp', 'teaspoon': 'tsp', 'teaspoons': 'tsp',
  'cup': 'cup', 'cups': 'cup',
};

// Ounces aren't an app unit, so they become grams.
const _ounceWords = {'oz', 'ounce', 'ounces'};
const _gramsPerOunce = 28.3495;

// Tiny amounts become a quarter teaspoon each.
const _pinchWords = {
  'pinch', 'pinches', 'dash', 'dashes', 'sprinkle', 'sprinkling', 'splash',
};

const _unicodeFractions = {
  '½': ' 1/2', '¼': ' 1/4', '¾': ' 3/4',
  '⅓': ' 1/3', '⅔': ' 2/3', '⅛': ' 1/8',
};

/// Turns text like "1 1/2 cups", "500g" or "3 cloves" into a quantity and one
/// of the app's units. Anything it can't read as a known unit is counted
/// ("3 cloves" -> 3 count). With no number, a pinch/dash becomes 1/4 tsp and
/// everything else becomes 1 count.
ParsedMeasure parseMeasure(String raw) {
  var s = raw.trim().toLowerCase();
  _unicodeFractions.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  double? qty;
  var rest = s;

  final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)').firstMatch(s);
  final fraction = RegExp(r'^(\d+)/(\d+)').firstMatch(s);
  final decimal = RegExp(
    r'^(\d+(?:\.\d+)?)(?:\s*(?:-|to)\s*\d+(?:\.\d+)?)?',
  ).firstMatch(s);

  if (mixed != null) {
    final d = double.parse(mixed.group(3)!);
    if (d != 0) {
      qty = double.parse(mixed.group(1)!) + double.parse(mixed.group(2)!) / d;
      rest = s.substring(mixed.end);
    }
  } else if (fraction != null) {
    final d = double.parse(fraction.group(2)!);
    if (d != 0) {
      qty = double.parse(fraction.group(1)!) / d;
      rest = s.substring(fraction.end);
    }
  } else if (decimal != null) {
    qty = double.parse(decimal.group(1)!);
    rest = s.substring(decimal.end);
  }
  rest = rest.trim();

  if (qty == null || qty <= 0) {
    final isPinch = _pinchWords.any((w) => s.contains(w));
    return isPinch ? const ParsedMeasure(0.25, 'tsp') : const ParsedMeasure(1, 'count');
  }

  if (RegExp(r'^fl\.?\s*oz').hasMatch(rest)) {
    return ParsedMeasure(_round(qty), 'fl oz');
  }
  final word = RegExp(r'^[a-z]+').firstMatch(rest)?.group(0) ?? '';
  if (_unitWords.containsKey(word)) {
    return ParsedMeasure(_round(qty), _unitWords[word]!);
  }
  if (_ounceWords.contains(word)) {
    return ParsedMeasure(_round(qty * _gramsPerOunce), 'g');
  }
  if (_pinchWords.contains(word)) {
    return ParsedMeasure(_round(qty * 0.25), 'tsp');
  }
  return ParsedMeasure(_round(qty), 'count');
}

double _round(double v) => (v * 10000).round() / 10000;
