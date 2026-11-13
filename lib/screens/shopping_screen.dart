import 'package:flutter/material.dart';
import 'package:project6/models/shopping_item.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';

class ShoppingScreen extends StatefulWidget {
  /// Tests pass a fake stream; the app leaves this null and uses Firestore.
  final Stream<List<ShoppingItem>>? itemsStream;

  /// Optional: when set, the empty screen shows a "Go to Plan" button.
  final VoidCallback? onGoToPlan;

  const ShoppingScreen({super.key, this.itemsStream, this.onGoToPlan});
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
          SnackBar(content: Text('Could not regenerate list: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                return EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Nothing to buy yet',
                  message:
                      'Your plan is empty. Add meals in the Plan tab, then generate your list.',
                  actionLabel: widget.onGoToPlan == null ? null : 'Go to Plan',
                  onAction: widget.onGoToPlan,
                );
              }
              final checked = items.where((i) => i.checked).length;
              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  _progress(context, checked, items.length),
                  for (final item in items) _itemCard(context, item),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _regenerate,
              icon: const Icon(Icons.refresh),
              label: Text(_busy ? 'Updating…' : 'Regenerate list'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, int checked, int total) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$checked of $total items checked',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: checked / total,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, ShoppingItem item) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    void toggle() => _service.setShoppingItemChecked(item.id, !item.checked);

    return AppCard(
      color: item.checked ? scheme.surfaceContainerHighest : null,
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.3,
              child: Checkbox(
                value: item.checked,
                onChanged: (v) =>
                    _service.setShoppingItemChecked(item.id, v ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capitalize(item.name),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                      color:
                          item.checked ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (item.fromRecipes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'From: ${item.fromRecipes.join(', ')}',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            InfoChip(label: '${formatQty(item.qty)} ${item.unit}'),
          ],
        ),
      ),
    );
  }
}
