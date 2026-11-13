import 'dart:async';
import 'package:project6/models/recipe.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final List<Recipe> _recipes = [];
  final _controller = StreamController<List<Recipe>>.broadcast();

  Stream<List<Recipe>> streamRecipes() async* {
    yield List.of(_recipes);
    yield* _controller.stream;
  }

  Future<void> addRecipe(Recipe recipe) async {
    recipe.id = DateTime.now().microsecondsSinceEpoch.toString();
    _recipes.add(recipe);
    _controller.add(List.of(_recipes));
  }

  Future<void> deleteRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    _controller.add(List.of(_recipes));
  }
}