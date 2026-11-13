import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/theme/app_theme.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe recipe; // the version on screen; replaced after an edit
  bool _busy = false; // a start/complete request is running

  static const _green = Color(0xFF2E6B34);

  /// Subtracts the ingredients from the pantry and marks the recipe started.
  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final short = await FirestoreService.instance.startRecipe(recipe);
      if (!mounted) return;
      setState(() => recipe.inProgress = true);
      final names = short.map(capitalize).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            short.isEmpty
                ? 'Started. Ingredients were subtracted from your pantry.'
                : 'Started. Your pantry did not fully cover: $names. '
                    'It used what you had.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Marks the recipe completed. Its card goes back to normal.
  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.completeRecipe(recipe.id);
      if (mounted) setState(() => recipe.inProgress = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    recipe = widget.recipe;
  }

  void _edit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(
          initial: recipe,
          onSave: (updated) async {
            await FirestoreService.instance.updateRecipe(updated);
            if (mounted) setState(() => recipe = updated);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text(
          'Delete "${recipe.name}"? Meal plan slots that use it are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.instance.deleteRecipe(recipe.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit recipe',
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (recipe.imageUrl != null) ...[
            SizedBox(
              height: 220,
              child: Image.network(
                recipe.imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: 1000,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              recipe.name,
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (recipe.prepTimeMinutes > 0)
                  InfoChip(
                    icon: Icons.schedule,
                    label: '${recipe.prepTimeMinutes} min',
                  ),
                if (recipe.calories != null)
                  InfoChip(
                    icon: Icons.local_fire_department_outlined,
                    label: '${recipe.calories} kcal',
                  ),
                for (final t in recipe.tags) InfoChip(label: t),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: recipe.inProgress
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _busy ? null : _complete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Completed recipe'),
                  )
                : ElevatedButton.icon(
                    onPressed: _busy ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start recipe'),
                  ),
          ),
          const SectionTitle('Ingredients'),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < recipe.ingredients.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              '${formatQty(recipe.ingredients[i].qty)} ${recipe.ingredients[i].unit}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              capitalize(recipe.ingredients[i].name),
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SectionTitle('Instructions'),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                recipe.instructions.isEmpty ? '—' : recipe.instructions,
                style: textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit recipe'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 52),
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete recipe'),
            ),
          ),
        ],
      ),
    );
  }
}
