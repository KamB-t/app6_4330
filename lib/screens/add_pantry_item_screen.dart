import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/widgets/ingredient_row.dart' show kUnits;
import 'package:project6/theme/app_theme.dart';

class AddPantryItemScreen extends StatefulWidget {
  final Future<void> Function(PantryItem item) onSave;
  const AddPantryItemScreen({super.key, required this.onSave});

  @override
  State<AddPantryItemScreen> createState() => _AddPantryItemScreenState();
}

class _AddPantryItemScreenState extends State<AddPantryItemScreen> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  String _unit = kUnits.first;
  DateTime? _expiry;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text.trim());
    if (_name.text.trim().isEmpty || qty == null || qty <= 0) {
      setState(() => _error = 'Enter a name and a quantity greater than 0.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    await widget.onSave(PantryItem(
      name: _name.text,
      qty: qty,
      unit: _unit,
      expiryDate: _expiry,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const fieldStyle = TextStyle(fontSize: 17);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add pantry item',
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
              hintText: 'e.g. Ground beef',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _qty,
                  style: fieldStyle,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              const SizedBox(width: 12),
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
                      value: _unit,
                      style: TextStyle(fontSize: 17, color: scheme.onSurface),
                      items: kUnits
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            margin: EdgeInsets.zero,
            onTap: _pickDate,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.event),
              title: Text(
                _expiry == null
                    ? 'Expiry date (optional)'
                    : 'Expires ${DateFormat('yyyy-MM-dd').format(_expiry!)}',
                style: fieldStyle,
              ),
              trailing: _expiry == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Remove expiry date',
                      onPressed: () => setState(() => _expiry = null),
                    ),
            ),
          ),
          const SizedBox(height: 26),
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
