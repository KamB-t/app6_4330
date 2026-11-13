import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/screens/recipe_detail_screen.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/widgets/recipe_card.dart';
import 'package:project6/theme/app_theme.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _service = FirestoreService.instance;
  late final Stream<List<Recipe>> _stream;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _stream = _service.streamRecipes();
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(onSave: _service.addRecipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Recipe>>(
              stream: _stream,
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
                  return EmptyState(
                    icon: Icons.menu_book,
                    title: 'Your recipe book is empty',
                    message: 'No recipes yet. Tap + to add one.',
                    actionLabel: 'Add a recipe',
                    onAction: _openAdd,
                  );
                }
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'No recipes match your search.',
                  );
                }
                final cards = [
                  for (final r in shown)
                    RecipeCard(
                      recipe: r,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: r),
                        ),
                      ),
                    ),
                ];
                // Two cards per row. IntrinsicHeight makes both cards in a row
                // the same height, so nothing overflows at larger text sizes.
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    for (var i = 0; i < cards.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: cards[i]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: i + 1 < cards.length
                                    ? cards[i + 1]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add recipe'),
      ),
    );
  }
}
