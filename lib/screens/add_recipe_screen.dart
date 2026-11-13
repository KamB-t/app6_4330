import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/widgets/ingredient_row.dart';
import 'package:project6/theme/app_theme.dart';

class AddRecipeScreen extends StatefulWidget {
  /// Passed in by the caller so this screen can be widget-tested without Firebase.
  final Future<void> Function(Recipe recipe) onSave;

  /// When set, the screen edits this recipe instead of creating a new one.
  final Recipe? initial;
  const AddRecipeScreen({super.key, required this.onSave, this.initial});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _name = TextEditingController();
  final _prep = TextEditingController();
  final _calories = TextEditingController();
  final _tags = TextEditingController();
  final _instructions = TextEditingController();
  List<IngredientDraft> _drafts = [IngredientDraft()];
  String? _error;
  bool _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r == null) return;
    _name.text = r.name;
    _prep.text = r.prepTimeMinutes > 0 ? '${r.prepTimeMinutes}' : '';
    _calories.text = r.calories == null ? '' : '${r.calories}';
    _tags.text = r.tags.join(', ');
    _instructions.text = r.instructions;
    for (final d in _drafts) {
      d.dispose();
    }
    _drafts = [
      for (final i in r.ingredients)
        IngredientDraft()
          ..name.text = i.name
          ..qty.text = formatQty(i.qty)
          ..unit = i.unit,
    ];
    if (_drafts.isEmpty) _drafts.add(IngredientDraft());
  }

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
    final old = widget.initial;
    final recipe = Recipe(
      // Editing keeps the recipe's identity, favorite flag, date and photo.
      id: old?.id ?? '',
      isFavorite: old?.isFavorite ?? false,
      createdAt: old?.createdAt,
      imageUrl: old?.imageUrl,
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
    const fieldStyle = TextStyle(fontSize: 17);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? 'Edit recipe' : 'Add recipe',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            style: fieldStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Chicken stir fry',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _prep,
            style: fieldStyle,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Prep time in minutes (optional)',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _calories,
            style: fieldStyle,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Calories (optional)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tags,
            style: fieldStyle,
            decoration: const InputDecoration(
              labelText: 'Tags (optional)',
              hintText: 'comma-separated, e.g. quick, vegetarian',
            ),
          ),
          const SectionTitle('Ingredients'),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => setState(() => _drafts.add(IngredientDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
            ),
          ),
          const SectionTitle('Instructions'),
          TextField(
            controller: _instructions,
            style: fieldStyle,
            maxLines: null,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              hintText: 'Steps to make it',
            ),
          ),
          const SizedBox(height: 22),
          if (_error != null) ErrorBanner(_error!),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
