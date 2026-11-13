import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/screens/recipe_detail_screen.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/widgets/recipe_card.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _service = FirestoreService.instance;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search recipes',
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Recipe>>(
              stream: _service.streamRecipes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final shown = all
                    .where((r) => r.name.toLowerCase().contains(_search))
                    .toList();
                if (all.isEmpty && _search.isEmpty) {
                  return const Center(
                      child: Text('No recipes yet. Tap + to add one.'));
                }
                if (shown.isEmpty) {
                  return const Center(child: Text('No recipes match your search.'));
                }
                return ListView(
                  children: [
                    for (final r in shown)
                      RecipeCard(
                        recipe: r,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(recipe: r)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddRecipeScreen(onSave: _service.addRecipe),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}