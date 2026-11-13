import 'package:flutter/material.dart';

const kUnits = ['g', 'kg', 'ml', 'l', 'count', 'tbsp', 'tsp', 'cup'];

/// Holds the text fields for one ingredient row in the form.
class IngredientDraft {
  final name = TextEditingController();
  final qty = TextEditingController();
  String unit = 'g';

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class IngredientRow extends StatefulWidget {
  final IngredientDraft draft;
  final VoidCallback onRemove;
  const IngredientRow({super.key, required this.draft, required this.onRemove});

  @override
  State<IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<IngredientRow> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: widget.draft.name,
            decoration: const InputDecoration(labelText: 'Ingredient'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: TextField(
            controller: widget.draft.qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Qty'),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: widget.draft.unit,
          items: kUnits
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (v) => setState(() => widget.draft.unit = v!),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove ingredient',
          onPressed: widget.onRemove,
        ),
      ],
    );
  }
}