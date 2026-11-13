import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/theme/app_theme.dart';

/// Vertical recipe card, built to sit two per row (see RecipesScreen).
/// Tinted header with a meal icon, then name, chips, and tags, like the
/// meal slots on the Plan tab.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  // Same icons as the Plan tab's meal rows; falls back to a generic one.
  IconData get _icon {
    if (recipe.tags.contains('breakfast')) return Icons.free_breakfast;
    if (recipe.tags.contains('lunch')) return Icons.lunch_dining;
    if (recipe.tags.contains('dinner')) return Icons.dinner_dining;
    return Icons.restaurant_menu;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = recipe.ingredients.length;
    return AppCard(
      radius: 0, // square corners
      margin: EdgeInsets.zero, // spacing is handled by the grid in RecipesScreen
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 76,
            color: scheme.primaryContainer,
            alignment: Alignment.center,
            child: Icon(_icon, size: 38, color: scheme.onPrimaryContainer),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (recipe.prepTimeMinutes > 0)
                      InfoChip(
                        icon: Icons.schedule,
                        label: '${recipe.prepTimeMinutes} min',
                      ),
                    InfoChip(
                      icon: Icons.shopping_basket_outlined,
                      label: '$count item${count == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                if (recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    recipe.tags.join(' · '),
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
