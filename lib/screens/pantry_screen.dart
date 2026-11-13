import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/screens/add_pantry_item_screen.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/theme/app_theme.dart';

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

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPantryItemScreen(onSave: _service.addPantryItem),
      ),
    );
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

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
            return EmptyState(
              icon: Icons.kitchen,
              title: 'Your pantry is empty',
              message:
                  'Add what you already have at home. It gets subtracted from your shopping list.',
              actionLabel: 'Add pantry item',
              onAction: _openAdd,
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Swipe an item left to remove it.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              for (final item in items) _itemRow(context, item),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Widget _itemRow(BuildContext context, PantryItem item) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          child: Icon(Icons.delete, color: scheme.onError, size: 28),
        ),
        confirmDismiss: (_) => _confirmDelete(item),
        onDismissed: (_) => _service.deletePantryItem(item.id),
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalize(item.name),
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.expiryDate == null
                                  ? 'No expiry date'
                                  : 'Expires ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}',
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InfoChip(label: '${formatQty(item.qty)} ${item.unit}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
