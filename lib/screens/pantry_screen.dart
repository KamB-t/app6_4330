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
    final status = item.expiryStatus();
    final style = _styleFor(status); // null = no expiry date, theme colors
    final expired = status == ExpiryStatus.expired;
    final subtle = style?.accent ?? scheme.onSurfaceVariant;
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
          color: style?.bg,
          borderColor: style?.border,
          borderWidth: style == null ? 1 : 1.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style == null
                        ? scheme.primaryContainer
                        : Colors.white.withAlpha(expired ? 140 : 200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: style?.accent ?? scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalize(item.name),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: expired ? subtle : null,
                          decoration:
                              expired ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 16,
                            color: subtle,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _expiryText(item),
                              style: textTheme.bodyMedium?.copyWith(
                                color: subtle,
                                fontWeight: style == null
                                    ? null
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (style == null)
                  InfoChip(label: '${formatQty(item.qty)} ${item.unit}')
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(expired ? 140 : 220),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${formatQty(item.qty)} ${item.unit}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: style.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card colors for one expiry status. Kept private to this screen on purpose,
/// so the shared theme file is untouched.
class _ExpiryStyle {
  final Color bg, border, accent;
  const _ExpiryStyle(this.bg, this.border, this.accent);
}

const _freshStyle =
    _ExpiryStyle(Color(0xFFE3F2E1), Color(0xFF4C9A52), Color(0xFF2E6B34));
const _soonStyle =
    _ExpiryStyle(Color(0xFFFFF3C4), Color(0xFFE0A800), Color(0xFF7A5C00));
const _urgentStyle =
    _ExpiryStyle(Color(0xFFFBD9D5), Color(0xFFC62828), Color(0xFF8A1C14));
const _expiredStyle =
    _ExpiryStyle(Color(0xFFE9E7E4), Color(0xFFC9C5C0), Color(0xFF8A8580));

/// Null means "no expiry date": use the normal theme card.
_ExpiryStyle? _styleFor(ExpiryStatus status) {
  switch (status) {
    case ExpiryStatus.fresh:
      return _freshStyle;
    case ExpiryStatus.soon:
      return _soonStyle;
    case ExpiryStatus.urgent:
      return _urgentStyle;
    case ExpiryStatus.expired:
      return _expiredStyle;
    case ExpiryStatus.none:
      return null;
  }
}

String _expiryText(PantryItem item) {
  final d = item.daysUntilExpiry();
  if (d == null) return 'No expiry date';
  final date = DateFormat('MMM d').format(item.expiryDate!);
  if (d < 0) return 'Expired $date';
  if (d == 0) return 'Expires today';
  if (d == 1) return 'Expires tomorrow';
  return 'Expires in $d days \u00b7 $date';
}
