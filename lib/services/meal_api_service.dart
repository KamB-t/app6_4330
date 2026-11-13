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

/// A recipe from the API. [imageUrl] is the same link stored on the recipe,
/// kept here for convenience; [category] is TheMealDB's category, lowercase
/// ("beef", "breakfast", ...), used for the meal-type filters.
class OnlineRecipe {
  final Recipe recipe;
  final String? imageUrl;
  final String category;
  const OnlineRecipe(this.recipe, this.imageUrl, {this.category = ''});
}

class MealApi {
  static const _base = 'https://www.themealdb.com/api/json/v1/1';

  /// Every recipe seen so far this session, keyed by lowercase name.
  static final Map<String, OnlineRecipe> _cache = {};

  /// Name searches that fill the catalog, on top of one search per letter.
  static const _catalogTerms = [
    'chicken', 'beef', 'pork', 'lamb', 'fish', 'salmon', 'pasta', 'rice',
    'egg', 'soup', 'salad', 'curry', 'pie', 'cake', 'pancake', 'breakfast',
    'vegetable', 'potato',
  ];

  /// Recipes whose name matches [query]. Results are also remembered in the
  /// catalog.
  Future<List<OnlineRecipe>> search(String query) async {
    final uri = Uri.parse('$_base/search.php')
        .replace(queryParameters: {'s': query.trim()});
    return _remember(await _getJson(uri));
  }

  /// A big mixed list: one lookup per first letter plus a few popular words,
  /// merged without duplicates. Loaded once, then served from memory. Only
  /// throws if every single lookup fails (for example, no internet).
  Future<List<OnlineRecipe>> catalog() async {
    if (_cache.isNotEmpty) return _cache.values.toList();
    Object? firstError;
    var failures = 0;
    final uris = <Uri>[
      for (var c = 97; c <= 122; c++)
        Uri.parse('$_base/search.php')
            .replace(queryParameters: {'f': String.fromCharCode(c)}),
      for (final t in _catalogTerms)
        Uri.parse('$_base/search.php').replace(queryParameters: {'s': t}),
    ];
    await Future.wait(uris.map((u) async {
      try {
        _remember(await _getJson(u));
      } catch (e) {
        failures++;
        firstError ??= e;
      }
    }));
    if (failures == uris.length) throw firstError!;
    return _cache.values.toList();
  }

  /// Pulls recipes that fit [f] straight from the API, so a filter can find
  /// recipes that weren't in the starter list. The API's category and
  /// ingredient lists only hold names, so the best few are looked up in full
  /// and remembered in the catalog. Nothing is returned: callers re-read
  /// [catalog] and filter as usual.
  Future<void> fetchForFilters(RecipeFilters f, {int maxLookups = 24}) async {
    final uris = <Uri>[];
    if (f.ingredients.isNotEmpty) {
      // Most selective first; the other ingredients are checked afterwards.
      final word = f.ingredients.first.trim().replaceAll(' ', '_');
      uris.add(Uri.parse('$_base/filter.php')
          .replace(queryParameters: {'i': word}));
    } else {
      final cats = <String>{
        for (final t in f.mealTypes) ...?mealTypeCategories[t],
      };
      for (final c in cats) {
        final name = c[0].toUpperCase() + c.substring(1);
        uris.add(Uri.parse('$_base/filter.php')
            .replace(queryParameters: {'c': name}));
      }
    }
    if (uris.isEmpty) return;

    // Each list holds {idMeal, strMeal, strMealThumb}.
    final lists = await Future.wait(uris.map((u) async {
      try {
        final meals = (await _getJson(u))['meals'];
        return meals is List ? meals : <dynamic>[];
      } catch (_) {
        return <dynamic>[];
      }
    }));

    // Take turns between lists so one big category doesn't crowd out the rest.
    final ids = <String>[];
    for (var i = 0; ids.length < maxLookups; i++) {
      var any = false;
      for (final list in lists) {
        if (i >= list.length) continue;
        any = true;
        final m = list[i];
        if (m is! Map) continue;
        final name = (m['strMeal'] ?? '').toString().toLowerCase();
        final id = (m['idMeal'] ?? '').toString();
        if (id.isEmpty || _cache.containsKey(name) || ids.contains(id)) continue;
        ids.add(id);
        if (ids.length >= maxLookups) break;
      }
      if (!any) break;
    }

    await Future.wait(ids.map((id) async {
      try {
        _remember(await _getJson(Uri.parse('$_base/lookup.php')
            .replace(queryParameters: {'i': id})));
      } catch (_) {
        // Skip a recipe that fails to load.
      }
    }));
  }

  List<OnlineRecipe> _remember(Map<String, dynamic> json) {
    final meals = json['meals'];
    if (meals is! List) return []; // the API sends null when nothing matches
    final out = <OnlineRecipe>[];
    for (final m in meals) {
      if (m is! Map<String, dynamic>) continue;
      final r = mealToRecipe(m);
      if (r == null) continue;
      final online = OnlineRecipe(
        r,
        r.imageUrl,
        category: (m['strCategory'] ?? '').toString().trim().toLowerCase(),
      );
      _cache.putIfAbsent(r.name.toLowerCase(), () => online);
      out.add(online);
    }
    return out;
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

  final image = (m['strMealThumb'] ?? '').toString().trim();

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
    imageUrl: image.isEmpty ? null : image,
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


// ---------------------------------------------------------------------------
// Filters for the online recipe list
// ---------------------------------------------------------------------------

/// TheMealDB has no lunch or dinner, so each meal type is a group of its
/// categories. They overlap on purpose (pasta works for lunch or dinner).
const Map<String, Set<String>> mealTypeCategories = {
  'Breakfast': {'breakfast'},
  'Lunch': {'starter', 'side', 'pasta', 'vegetarian', 'vegan'},
  'Dinner': {
    'beef', 'chicken', 'lamb', 'pork', 'goat', 'seafood', 'pasta',
    'vegetarian', 'vegan', 'miscellaneous',
  },
  'Dessert': {'dessert'},
};

/// What the user picked in the Filters pop-up.
class RecipeFilters {
  /// Meal types (keys of [mealTypeCategories]). A recipe matches if it fits
  /// any selected type.
  final Set<String> mealTypes;

  /// Ingredient words, lowercase. A recipe must use all of them.
  final Set<String> ingredients;

  RecipeFilters({Set<String>? mealTypes, Set<String>? ingredients})
      : mealTypes = mealTypes ?? <String>{},
        ingredients = ingredients ?? <String>{};

  RecipeFilters copy() =>
      RecipeFilters(mealTypes: {...mealTypes}, ingredients: {...ingredients});

  int get count => mealTypes.length + ingredients.length;
}

bool matchesMealType(OnlineRecipe r, String type) {
  final cats = mealTypeCategories[type] ?? const <String>{};
  return cats.contains(r.category) ||
      r.recipe.tags.contains(type.toLowerCase());
}

/// True if the recipe passes the pop-up filters. An ingredient word matches
/// part of a name, so "chicken" also finds "chicken breast".
bool matchesFilters(OnlineRecipe r, RecipeFilters f) {
  if (f.mealTypes.isNotEmpty &&
      !f.mealTypes.any((t) => matchesMealType(r, t))) {
    return false;
  }
  for (final word in f.ingredients) {
    if (!r.recipe.ingredients.any((i) => i.name.contains(word))) return false;
  }
  return true;
}
