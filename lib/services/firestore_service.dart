import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project6/models/recipe.dart';
import 'package:flutter/foundation.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/shopping_item.dart';
import 'package:project6/services/shopping_list_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // Every document lives under users/{uid}/..., matching the security rules.
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection('users').doc(_uid).collection('recipes');

  // ---------- Recipes ----------

  Stream<List<Recipe>> streamRecipes() {
    return _recipes.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Recipe.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> addRecipe(Recipe recipe) async {
    final doc = _recipes.doc(); // Firestore generates the id
    recipe.id = doc.id;
    await doc.set(recipe.toMap());
  }

  /// Saves changes to an existing recipe.
  Future<void> updateRecipe(Recipe recipe) =>
      _recipes.doc(recipe.id).set(recipe.toMap());

  /// Starts a recipe: subtracts its ingredients from the pantry (items used up
  /// are deleted) and marks it in progress, in one batch. Returns the names of
  /// ingredients the pantry couldn't fully cover.
  Future<List<String>> startRecipe(Recipe recipe) async {
    final snap = await _pantry.get();
    final pantry = snap.docs
        .map((d) => PantryItem.fromMap(d.data(), id: d.id))
        .toList();
    final result = deductFromPantry(recipe.ingredients, pantry);

    final batch = _db.batch();
    result.newQty.forEach((id, qty) {
      if (qty <= 0) {
        batch.delete(_pantry.doc(id));
      } else {
        batch.update(_pantry.doc(id), {'qty': qty});
      }
    });
    batch.update(_recipes.doc(recipe.id), {'inProgress': true});
    await batch.commit();
    return result.shortfall;
  }

  /// Marks a started recipe completed. The pantry is not changed.
  Future<void> completeRecipe(String id) =>
      _recipes.doc(id).update({'inProgress': false});

  Future<void> deleteRecipe(String id) => _recipes.doc(id).delete();

  // ---------- Pantry ----------

  CollectionReference<Map<String, dynamic>> get _pantry =>
      _db.collection('users').doc(_uid).collection('pantry');

  Stream<List<PantryItem>> streamPantry() {
    return _pantry.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PantryItem.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> addPantryItem(PantryItem item) async {
    final doc = _pantry.doc();
    item.id = doc.id;
    await doc.set(item.toMap());
  }

  Future<void> deletePantryItem(String id) => _pantry.doc(id).delete();

  // ---------- Shopping list ----------

  CollectionReference<Map<String, dynamic>> get _shopping =>
      _db.collection('users').doc(_uid).collection('shoppingList');

  Stream<List<ShoppingItem>> streamShoppingList() {
    return _shopping.snapshots().map((snap) {
      final list = snap.docs.map((d) => ShoppingItem.fromMap(d.data())).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Replaces the stored list with [items]. Items that still exist keep their
  /// checked state; items no longer needed are deleted.
  Future<void> saveShoppingList(List<ShoppingItem> items) async {
    final existing = await _shopping.get();
    final oldChecked = {
      for (final d in existing.docs) d.id: (d.data()['checked'] ?? false) as bool
    };
    final newIds = items.map((i) => i.id).toSet();

    final batch = _db.batch();
    for (final d in existing.docs) {
      if (!newIds.contains(d.id)) batch.delete(d.reference);
    }
    for (final item in items) {
      item.checked = oldChecked[item.id] ?? false;
      batch.set(_shopping.doc(item.id), item.toMap());
    }
    await batch.commit();
  }

  Future<void> setShoppingItemChecked(String id, bool checked) =>
      _shopping.doc(id).update({'checked': checked});

  /// Adds [items] to the pantry, removes fully bought items from the shopping
  /// list, and for partly bought items lowers the quantity to what is still
  /// needed (and unchecks them). One batch: all of it happens or none of it.
  Future<void> markBought(
    List<PantryItem> items,
    List<String> removeIds,
    Map<String, double> remaining,
  ) async {
    final batch = _db.batch();
    for (final item in items) {
      final doc = _pantry.doc();
      item.id = doc.id;
      batch.set(doc, item.toMap());
    }
    for (final id in removeIds) {
      batch.delete(_shopping.doc(id));
    }
    remaining.forEach((id, qty) {
      batch.update(_shopping.doc(id), {'qty': qty, 'checked': false});
    });
    await batch.commit();
  }

  /// Works out which of [recipe]'s ingredients the pantry doesn't cover (same
  /// calculation as before: unit conversion, expired items ignored) and adds
  /// them to the shopping list. Existing list items are kept. If an item with
  /// the same name and unit is already on the list, the quantities are added
  /// together, the recipe name is appended, and the item is unchecked (its
  /// quantity changed). Returns how many items were added or updated; 0 means
  /// the pantry already covers the recipe.
  Future<int> addMissingToShoppingList(Recipe recipe) async {
    final pantrySnap = await _pantry.get();
    final pantry = pantrySnap.docs
        .map((d) => PantryItem.fromMap(d.data(), id: d.id))
        .toList();
    final missing = generateShoppingList([recipe], pantry);
    if (missing.isEmpty) return 0;

    final existing = await _shopping.get();
    final existingById = {
      for (final d in existing.docs) d.id: ShoppingItem.fromMap(d.data())
    };

    final batch = _db.batch();
    for (final item in missing) {
      final old = existingById[item.id];
      if (old != null) {
        item.qty = double.parse((old.qty + item.qty).toStringAsFixed(4));
        item.fromRecipes = [
          ...old.fromRecipes,
          for (final r in item.fromRecipes)
            if (!old.fromRecipes.contains(r)) r,
        ];
      }
      item.checked = false;
      batch.set(_shopping.doc(item.id), item.toMap());
    }
    await batch.commit();
    return missing.length;
  }

  // ---------- Seed data ----------

  /// Writes the 5 starter recipes if this user has no recipes yet.
  /// Fixed document ids make it safe to run twice (it overwrites, never duplicates).
  Future<void> seedStarterRecipesIfEmpty() async {
    final batch = _db.batch();
    _starterRecipes().forEach((id, recipe) {
      batch.set(_recipes.doc(id), recipe.toMap());
    });
    await batch.commit();
    debugPrint('Seeded starter recipes');
  }

  Map<String, Recipe> _starterRecipes() {
    final now = DateTime.now();
    DateTime t(int i) => now.add(Duration(milliseconds: i)); // keeps list order
    return {
      'starter_spaghetti': Recipe(
        name: 'Spaghetti',
        prepTimeMinutes: 25,
        tags: ['dinner'],
        ingredients: [
          Ingredient(name: 'pasta', qty: 0.5, unit: 'lbs'),
          Ingredient(name: 'pasta sauce', qty: 300, unit: 'ml'),
          Ingredient(name: 'ground beef', qty: 0.5, unit: 'lbs'),
          Ingredient(name: 'onion', qty: 1, unit: 'count'),
          Ingredient(name: 'garlic', qty: 2, unit: 'count'),
        ],
        instructions:
        'Boil pasta in salted water. Brown the ground beef with chopped onion and garlic. Add pasta sauce and simmer 10 minutes. Drain pasta and combine.',
        createdAt: t(0),
      ),
      'starter_tacos': Recipe(
        name: 'Tacos',
        prepTimeMinutes: 20,
        tags: ['dinner', 'quick'],
        ingredients: [
          Ingredient(name: 'ground beef', qty: 1, unit: 'lbs'),
          Ingredient(name: 'tortillas', qty: 8, unit: 'count'),
          Ingredient(name: 'shredded cheese', qty: 0.25, unit: 'lbs'),
          Ingredient(name: 'lettuce', qty: 100, unit: 'g'),
          Ingredient(name: 'tomato', qty: 2, unit: 'count'),
        ],
        instructions:
        'Brown the ground beef and season to taste. Warm the tortillas. Fill with beef, cheese, lettuce, and chopped tomato.',
        createdAt: t(1),
      ),
      'starter_chicken_stir_fry': Recipe(
        name: 'Chicken stir fry',
        prepTimeMinutes: 30,
        tags: ['dinner'],
        ingredients: [
          Ingredient(name: 'chicken breast', qty: 1, unit: 'lbs'),
          Ingredient(name: 'rice', qty: 0.5, unit: 'lbs'),
          Ingredient(name: 'bell pepper', qty: 2, unit: 'count'),
          Ingredient(name: 'soy sauce', qty: 3, unit: 'tbsp'),
          Ingredient(name: 'garlic', qty: 2, unit: 'count'),
        ],
        instructions:
        'Cook the rice. Slice chicken and peppers. Stir fry chicken until cooked, add peppers and garlic, then soy sauce. Serve over rice.',
        createdAt: t(2),
      ),
      'starter_pancakes': Recipe(
        name: 'Pancakes',
        prepTimeMinutes: 15,
        tags: ['breakfast', 'quick'],
        ingredients: [
          Ingredient(name: 'flour', qty: 250, unit: 'g'),
          Ingredient(name: 'milk', qty: 300, unit: 'ml'),
          Ingredient(name: 'egg', qty: 2, unit: 'count'),
          Ingredient(name: 'sugar', qty: 2, unit: 'tbsp'),
          Ingredient(name: 'butter', qty: 30, unit: 'g'),
        ],
        instructions:
        'Mix flour, sugar, milk, and eggs into a batter. Fry small ladles of batter in butter until golden on both sides.',
        createdAt: t(3),
      ),
      'starter_garden_salad': Recipe(
        name: 'Garden salad',
        prepTimeMinutes: 10,
        tags: ['lunch', 'quick', 'vegetarian'],
        ingredients: [
          Ingredient(name: 'lettuce', qty: 200, unit: 'g'),
          Ingredient(name: 'tomato', qty: 2, unit: 'count'),
          Ingredient(name: 'cucumber', qty: 1, unit: 'count'),
          Ingredient(name: 'olive oil', qty: 2, unit: 'tbsp'),
        ],
        instructions:
        'Chop the lettuce, tomato, and cucumber. Toss together and dress with olive oil.',
        createdAt: t(4),
      ),
    };
  }
}