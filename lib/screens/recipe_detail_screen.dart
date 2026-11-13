import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/theme/app_theme.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

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
      appBar: AppBar(title: const Text('Recipe')),
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
