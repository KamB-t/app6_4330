import 'package:flutter/material.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/screens/recipe_detail_screen.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';
import 'package:project6/widgets/recipe_card.dart';

/// How the recipe list is ordered / filtered.
enum _Mode { best, all, ready }

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _service = FirestoreService.instance;
  late final Stream<List<Recipe>> _stream;
  late final Stream<List<PantryItem>> _pantryStream;
  String _search = '';
  _Mode _mode = _Mode.best;

  @override
  void initState() {
    super.initState();
    _stream = _service.streamRecipes();
    _pantryStream = _service.streamPantry();
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(onSave: _service.addRecipe),
      ),
    );
  }

  Widget _modeChip(String label, _Mode mode) {
    return ChoiceChip(
      label: Text(label),
      selected: _mode == mode,
      onSelected: (_) => setState(() => _mode = mode),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _modeChip('Best match', _Mode.best),
                  _modeChip('Ready to cook', _Mode.ready),
                  _modeChip('All recipes', _Mode.all),
                ],
              ),
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
                if (all.isEmpty && _search.isEmpty) {
                  return EmptyState(
                    icon: Icons.menu_book,
                    title: 'Your recipe book is empty',
                    message: 'No recipes yet. Tap + to add one.',
                    actionLabel: 'Add a recipe',
                    onAction: _openAdd,
                  );
                }
                return StreamBuilder<List<PantryItem>>(
                  stream: _pantryStream,
                  builder: (context, pantrySnap) {
                    // Expired items don't count as "in the pantry" here.
                    final pantry = (pantrySnap.data ?? const <PantryItem>[])
                        .where((p) => !p.isExpired())
                        .toList();
                    return _buildList(context, all, pantry);
                  },
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

  Widget _buildList(
    BuildContext context,
    List<Recipe> all,
    List<PantryItem> pantry,
  ) {
    final ranked = rankRecipesByPantry(all, pantry); // best match first
    final readyCount = ranked.where((m) => m.canMakeNow).length;

    // "All recipes" keeps the original order; the others use the ranking.
    List<RecipeMatch> ordered = ranked;
    if (_mode == _Mode.all) {
      final byId = {for (final m in ranked) m.recipe.id: m};
      ordered = [for (final r in all) byId[r.id]!];
    }

    var shown = ordered
        .where((m) => m.recipe.name.toLowerCase().contains(_search))
        .toList();
    if (_mode == _Mode.ready) {
      shown = shown.where((m) => m.canMakeNow).toList();
    }

    if (shown.isEmpty) {
      if (_mode == _Mode.ready && _search.isEmpty) {
        return EmptyState(
          icon: Icons.kitchen,
          title: 'Nothing ready to cook yet',
          message: pantry.isEmpty
              ? 'Add items in the Pantry tab and the recipes you can make will show up here.'
              : 'Every recipe is missing at least one ingredient. Try Best match to see which are closest.',
        );
      }
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No recipes match your search.',
      );
    }

    final cards = [
      for (final m in shown)
        RecipeCard(
          recipe: m.recipe,
          match: pantry.isEmpty ? null : m,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: m.recipe),
            ),
          ),
        ),
    ];

    // Two cards per row. IntrinsicHeight makes both cards in a row the same
    // height, so nothing overflows at larger text sizes.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _summary(context, pantry.isEmpty, readyCount),
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
  }

  /// One line above the grid that tells the user what the ranking means.
  Widget _summary(BuildContext context, bool pantryEmpty, int readyCount) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String text;
    final IconData icon;
    if (pantryEmpty) {
      text = 'Add what you have in the Pantry tab, and these recipes will be '
          'ranked by what you can cook.';
      icon = Icons.lightbulb_outline;
    } else if (readyCount == 0) {
      text = 'No recipe is fully covered yet. Closest matches are first.';
      icon = Icons.kitchen;
    } else {
      text = 'You can cook $readyCount recipe${readyCount == 1 ? '' : 's'} '
          'right now.';
      icon = Icons.check_circle;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        margin: EdgeInsets.zero,
        color: scheme.secondaryContainer,
        borderColor: AppColors.orange,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: scheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
