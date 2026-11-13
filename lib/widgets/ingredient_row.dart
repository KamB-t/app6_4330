import 'package:flutter/material.dart';
import 'package:project6/theme/app_theme.dart';

const kUnits = ['g', 'kg', 'lbs', 'ml', 'l', 'count', 'tbsp', 'tsp', 'cup', 'fl oz'];

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

/// One ingredient: name on its own full-width line, then quantity, unit, remove.
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
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: widget.draft.name,
              style: const TextStyle(fontSize: 17),
              decoration: const InputDecoration(labelText: 'Ingredient'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: widget.draft.qty,
                    style: const TextStyle(fontSize: 17),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      contentPadding: EdgeInsets.fromLTRB(16, 6, 8, 6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: widget.draft.unit,
                        style: TextStyle(
                          fontSize: 17,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: kUnits
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => widget.draft.unit = v!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  tooltip: 'Remove ingredient',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
