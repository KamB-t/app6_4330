import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';

/// Vertical recipe card, built to sit two per row (see RecipesScreen).
/// Tinted header with a meal icon, then name, chips, and (when a [match] is
/// given) how much of the recipe your pantry already covers.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  /// Pantry match for this recipe. Null hides the pantry section, e.g. when
  /// the pantry is empty.
  final RecipeMatch? match;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.match,
  });

  // Same icons as the Plan tab's meal rows; falls back to a generic one.
  IconData get _icon {
    if (recipe.tags.contains('breakfast')) return Icons.free_breakfast;
    if (recipe.tags.contains('lunch')) return Icons.lunch_dining;
    if (recipe.tags.contains('dinner')) return Icons.dinner_dining;
    return Icons.restaurant_menu;
  }

  /// The recipe's photo when it has one (and while it loads or fails, the
  /// tinted icon header).
  Widget _header(ColorScheme scheme) {
    final iconHeader = Container(
      height: recipe.imageUrl == null ? 76 : 110,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(_icon, size: 38, color: scheme.onPrimaryContainer),
    );
    final url = recipe.imageUrl;
    if (url == null) return iconHeader;
    return SizedBox(
      height: 110,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 600,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : iconHeader,
        errorBuilder: (context, error, stack) => iconHeader,
      ),
    );
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
          _header(scheme),
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
                    if (match == null)
                      InfoChip(
                        icon: Icons.shopping_basket_outlined,
                        label: '$count item${count == 1 ? '' : 's'}',
                      ),
                  ],
                ),
                if (match != null) ...[
                  const SizedBox(height: 12),
                  PantryMatchSection(match: match!),
                ],
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

/// "Ready to cook" badge, or a progress bar + "You have 4 of 5" + what is
/// missing. Shared by the recipe list and the online "Add recipe" list.
class PantryMatchSection extends StatelessWidget {
  final RecipeMatch match;
  const PantryMatchSection({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (m.canMakeNow) {
      return const InfoChip(icon: Icons.check_circle, label: 'Ready to cook');
    }

    final shown = m.missing.take(3).join(', ');
    final extra = m.missing.length - 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: m.score, minHeight: 6),
        const SizedBox(height: 8),
        Text(
          'You have ${m.have} of ${m.total}',
          style: textTheme.titleSmall,
        ),
        if (m.missing.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Need: $shown${extra > 0 ? ' +$extra more' : ''}',
            style:
                textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
