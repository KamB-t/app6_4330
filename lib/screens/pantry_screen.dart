import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/screens/add_pantry_item_screen.dart';
import 'package:project6/services/firestore_service.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});
  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _service = FirestoreService.instance;
  late final Stream<List<PantryItem>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.streamPantry();
  }

  Future<bool> _confirmDelete(PantryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pantry item?'),
        content: Text('Delete "${item.name}"?'),
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
    return ok == true;
  }

  // 500.0 -> "500", 1.5 -> "1.5"
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<PantryItem>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('Your pantry is empty. Tap + to add an item.'));
          }
          return ListView(
            children: [
              for (final item in items)
                Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(item),
                  onDismissed: (_) => _service.deletePantryItem(item.id),
                  child: ListTile(
                    title: Text('${_fmt(item.qty)} ${item.unit} ${item.name}'),
                    subtitle: item.expiryDate == null
                        ? null
                        : Text(
                        'Expires ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}'),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPantryItemScreen(onSave: _service.addPantryItem),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}