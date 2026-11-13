import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (recipe.prepTimeMinutes > 0) '${recipe.prepTimeMinutes} min',
      if (recipe.tags.isNotEmpty) recipe.tags.join(', '),
    ];
    return Card(
      child: ListTile(
        title: Text(recipe.name),
        subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}