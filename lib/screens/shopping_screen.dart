import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/shopping_item.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';
import 'package:project6/widgets/ingredient_row.dart' show kUnits;

class ShoppingScreen extends StatefulWidget {
  /// Tests pass a fake stream; the app leaves this null and uses Firestore.
  final Stream<List<ShoppingItem>>? itemsStream;

  /// Optional: when set, the empty screen shows a "Go to Plan" button.
  final VoidCallback? onGoToPlan;

  /// Called when the user confirms the Bought sheet: the pantry items to add
  /// and the ids of the shopping-list items to remove. The app leaves this
  /// null and saves to Firestore.
  final Future<void> Function(List<PantryItem> items, List<String> shoppingIds)?
      onBought;

  const ShoppingScreen({
    super.key,
    this.itemsStream,
    this.onGoToPlan,
    this.onBought,
  });
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  FirestoreService get _service => FirestoreService.instance; // only touched when used
  late final Stream<List<ShoppingItem>> _stream;
  bool _busy = false;

  /// What the user entered when they checked each item off, keyed by shopping
  /// item id. Lives in memory only; if the app restarts, the Bought button asks
  /// again for any checked item that has no details.
  final Map<String, PantryItem> _details = {};

  @override
  void initState() {
    super.initState();
    _stream = widget.itemsStream ?? FirestoreService.instance.streamShoppingList();
  }

  /// Checking an item off asks right away how much was bought and when it
  /// expires, so it can be done in the store. Cancelling leaves it unchecked.
  /// Unchecking forgets the details.
  Future<void> _onToggle(ShoppingItem item) async {
    if (item.checked) {
      setState(() => _details.remove(item.id));
      await _service.setShoppingItemChecked(item.id, false);
      return;
    }
    final result = await showModalBottomSheet<List<PantryItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BoughtSheet(
        items: [item],
        title: 'How much did you buy?',
        confirmLabel: 'Save',
      ),
    );
    if (result == null || result.isEmpty) return; // cancelled
    setState(() => _details[item.id] = result.first);
    await _service.setShoppingItemChecked(item.id, true);
  }

  /// Moves every checked item to the pantry and off the shopping list, using
  /// the details entered at check-off. Any checked item without details (for
  /// example after an app restart) is asked for first.
  Future<void> _bought(List<ShoppingItem> checkedItems) async {
    final missing =
        checkedItems.where((i) => !_details.containsKey(i.id)).toList();
    if (missing.isNotEmpty) {
      final result = await showModalBottomSheet<List<PantryItem>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _BoughtSheet(
          items: missing,
          title: 'Finish these items',
          confirmLabel: 'Continue',
        ),
      );
      if (result == null) return; // cancelled
      for (var i = 0; i < missing.length; i++) {
        _details[missing[i].id] = result[i];
      }
    }
    final toAdd = [for (final i in checkedItems) _details[i.id]!];
    final ids = checkedItems.map((i) => i.id).toList();
    try {
      await (widget.onBought ?? _service.markBought)(toAdd, ids);
      setState(() {
        for (final id in ids) {
          _details.remove(id);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toAdd.length == 1
                  ? 'Added 1 item to your pantry'
                  : 'Added ${toAdd.length} items to your pantry',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update pantry: $e')),
        );
      }
    }
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
              final checkedItems = items.where((i) => i.checked).toList();
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      children: [
                        _progress(context, checkedItems.length, items.length),
                        for (final item in items) _itemCard(context, item),
                      ],
                    ),
                  ),
                  if (checkedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _bought(checkedItems),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text('Bought (${checkedItems.length})'),
                        ),
                      ),
                    ),
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

  String _summary(PantryItem d) {
    final bought = 'Bought ${formatQty(d.qty)} ${d.unit}';
    if (d.expiryDate == null) return bought;
    return '$bought \u00b7 expires ${DateFormat('yyyy-MM-dd').format(d.expiryDate!)}';
  }

  Widget _itemCard(BuildContext context, ShoppingItem item) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    void toggle() => _onToggle(item);

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
                onChanged: (_) => toggle(),
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
                  if (item.checked && _details[item.id] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _summary(_details[item.id]!),
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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


/// One editable row in the Bought sheet.
class _Draft {
  final ShoppingItem source;
  final TextEditingController name;
  final TextEditingController qty;
  final List<String> units;
  String unit;
  DateTime? expiry;

  _Draft(this.source)
      : name = TextEditingController(text: capitalize(source.name)),
        qty = TextEditingController(text: formatQty(source.qty)),
        unit = source.unit,
        units = kUnits.contains(source.unit)
            ? kUnits
            : [...kUnits, source.unit];

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

/// Bottom sheet opened when an item is checked off (and, as a fallback, by the
/// Bought button). Each item is pre-filled with the amount the list needed; the user can raise it if they bought more,
/// fix the name or unit, and set an expiry date before confirming.
class _BoughtSheet extends StatefulWidget {
  final List<ShoppingItem> items;
  final String title;
  final String confirmLabel;
  const _BoughtSheet({
    required this.items,
    this.title = 'What did you buy?',
    this.confirmLabel = 'Save',
  });

  @override
  State<_BoughtSheet> createState() => _BoughtSheetState();
}

class _BoughtSheetState extends State<_BoughtSheet> {
  late final List<_Draft> _drafts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = widget.items.map((i) => _Draft(i)).toList();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(_Draft d) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.expiry ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => d.expiry = picked);
  }

  void _confirm() {
    final out = <PantryItem>[];
    for (final d in _drafts) {
      final qty = double.tryParse(d.qty.text.trim());
      if (d.name.text.trim().isEmpty || qty == null || qty <= 0) {
        setState(() => _error =
            'Every item needs a name and a quantity greater than 0.');
        return;
      }
      out.add(PantryItem(
        name: d.name.text,
        qty: qty,
        unit: d.unit,
        expiryDate: d.expiry,
      ));
    }
    Navigator.pop(context, out);
  }

  Widget _draftCard(_Draft d) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const fieldStyle = TextStyle(fontSize: 17);
    final entered = double.tryParse(d.qty.text.trim());
    final extra = (entered != null && d.unit == d.source.unit)
        ? entered - d.source.qty
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Needed: ${formatQty(d.source.qty)} ${d.source.unit}',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: d.name,
                style: fieldStyle,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: d.qty,
                      style: fieldStyle,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration:
                          const InputDecoration(labelText: 'Quantity bought'),
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
                          value: d.unit,
                          style: TextStyle(
                              fontSize: 17, color: scheme.onSurface),
                          items: d.units
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => d.unit = v!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (extra > 0.0001)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${formatQty(extra)} ${d.unit} more than you need. '
                    'It all goes into your pantry.',
                    style:
                        textTheme.bodyMedium?.copyWith(color: scheme.primary),
                  ),
                ),
              const SizedBox(height: 12),
              AppCard(
                margin: EdgeInsets.zero,
                onTap: () => _pickDate(d),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: const Icon(Icons.event),
                  title: Text(
                    d.expiry == null
                        ? 'Expiry date (optional)'
                        : 'Expires ${DateFormat('yyyy-MM-dd').format(d.expiry!)}',
                    style: fieldStyle,
                  ),
                  trailing: d.expiry == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Remove expiry date',
                          onPressed: () => setState(() => d.expiry = null),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.title,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final d in _drafts) _draftCard(d),
                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
