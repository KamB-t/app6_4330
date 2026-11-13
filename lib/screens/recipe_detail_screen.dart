import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/firestore_service.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Delete "${recipe.name}"? Meal plan slots that use it are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
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
    final meta = <String>[
      if (recipe.prepTimeMinutes > 0) '${recipe.prepTimeMinutes} min',
      if (recipe.tags.isNotEmpty) recipe.tags.join(', '),
      if (recipe.calories != null) '${recipe.calories} kcal',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (meta.isNotEmpty) Text(meta.join(' · ')),
          const SizedBox(height: 16),
          const Text('Ingredients',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final i in recipe.ingredients)
            Text('${_fmt(i.qty)} ${i.unit} ${i.name}'),
          const SizedBox(height: 16),
          const Text('Instructions',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(recipe.instructions.isEmpty ? '—' : recipe.instructions),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _confirmDelete(context),
            child: const Text('Delete recipe'),
          ),
        ],
      ),
    );
  }

  // 500.0 -> "500", 1.5 -> "1.5"
  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}