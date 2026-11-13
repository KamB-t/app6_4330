import 'package:flutter/material.dart';
import 'package:project6/models/shopping_item.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/services/shopping_list_service.dart';

class ShoppingScreen extends StatefulWidget {
  /// Tests pass a fake stream; the app leaves this null and uses Firestore.
  final Stream<List<ShoppingItem>>? itemsStream;
  const ShoppingScreen({super.key, this.itemsStream});
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  FirestoreService get _service => FirestoreService.instance; // only touched when used
  late final Stream<List<ShoppingItem>> _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.itemsStream ?? FirestoreService.instance.streamShoppingList();
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    try {
      final week = currentWeekRange();
      await _service.regenerateShoppingList(week[0], week[1]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not regenerate list: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 500.0 -> "500", 1.5 -> "1.5"
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _regenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ShoppingItem>>(
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
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your plan is empty. Add meals in the Plan tab, then generate your list.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView(
                children: [
                  for (final item in items)
                    CheckboxListTile(
                      value: item.checked,
                      onChanged: (v) =>
                          _service.setShoppingItemChecked(item.id, v ?? false),
                      title: Text(
                        '${_fmt(item.qty)} ${item.unit} ${item.name}',
                        style: TextStyle(
                          decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text('From: ${item.fromRecipes.join(', ')}'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}