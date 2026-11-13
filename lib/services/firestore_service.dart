import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project6/models/recipe.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> deleteRecipe(String id) => _recipes.doc(id).delete();

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