import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project6/models/recipe.dart';

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
}