import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/widgets/ingredient_row.dart';

class AddRecipeScreen extends StatefulWidget {
  /// Passed in by the caller so this screen can be widget-tested without Firebase.
  final Future<void> Function(Recipe recipe) onSave;
  const AddRecipeScreen({super.key, required this.onSave});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _name = TextEditingController();
  final _prep = TextEditingController();
  final _calories = TextEditingController();
  final _tags = TextEditingController();
  final _instructions = TextEditingController();
  final List<IngredientDraft> _drafts = [IngredientDraft()];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _prep.dispose();
    _calories.dispose();
    _tags.dispose();
    _instructions.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Recipe name is required.');
      return;
    }
    final ingredients = <Ingredient>[];
    for (final d in _drafts) {
      final qty = double.tryParse(d.qty.text.trim());
      if (d.name.text.trim().isEmpty || qty == null || qty <= 0) {
        setState(() => _error =
        'Every ingredient needs a name and a quantity greater than 0.');
        return;
      }
      ingredients.add(Ingredient(name: d.name.text, qty: qty, unit: d.unit));
    }
    final recipe = Recipe(
      name: _name.text.trim(),
      ingredients: ingredients,
      instructions: _instructions.text.trim(),
      prepTimeMinutes: int.tryParse(_prep.text.trim()) ?? 0,
      calories: int.tryParse(_calories.text.trim()),
      tags: _tags.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList(),
    );
    setState(() {
      _error = null;
      _saving = true;
    });
    await widget.onSave(recipe);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add recipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _prep,
            keyboardType: TextInputType.number,
            decoration:
            const InputDecoration(labelText: 'Prep time (minutes, optional)'),
          ),
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Calories (optional)'),
          ),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
                labelText: 'Tags (comma-separated, optional)'),
          ),
          const SizedBox(height: 16),
          const Text('Ingredients',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final d in _drafts)
            IngredientRow(
              key: ObjectKey(d),
              draft: d,
              onRemove: () => setState(() {
                if (_drafts.length > 1) {
                  _drafts.remove(d);
                  d.dispose();
                }
              }),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _drafts.add(IngredientDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Add ingredient'),
          ),
          TextField(
            controller: _instructions,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}