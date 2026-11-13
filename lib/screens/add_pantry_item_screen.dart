import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/widgets/ingredient_row.dart' show kUnits;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Add pantry item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _unit,
                items: kUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(_expiry == null
                    ? 'No expiry date'
                    : 'Expires ${DateFormat('yyyy-MM-dd').format(_expiry!)}'),
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text('Pick expiry date'),
              ),
              if (_expiry != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Remove expiry date',
                  onPressed: () => setState(() => _expiry = null),
                ),
            ],
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