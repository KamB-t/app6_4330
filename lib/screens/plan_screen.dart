import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/meal_plan.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/widgets/plan_slot.dart';
import 'package:project6/theme/app_theme.dart';

const kMeals = ['breakfast', 'lunch', 'dinner'];

class PlanScreen extends StatefulWidget {
  final VoidCallback onGenerated;
  const PlanScreen({super.key, required this.onGenerated});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _service = FirestoreService.instance;
  late final List<DateTime> _days; // Monday..Sunday of the current week
  late final Stream<List<MealPlan>> _stream;
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await _service.regenerateShoppingList(_days.first, _days.last);
      widget.onGenerated(); // switches to the Shopping tab
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate list: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final monday =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));
    _days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    _stream = _service.streamMealPlans(_days.first, _days.last);
  }

  Future<void> _openPicker(DateTime day, String meal, MealPlan? current) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecipePicker(
        onPick: (recipe) => _service.assignRecipe(day, meal, recipe),
        onClear: current == null ? null : () => _service.clearSlot(day, meal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildWeek()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text(
                _generating ? 'Generating…' : 'Generate shopping list',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeek() {
    return StreamBuilder<List<MealPlan>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Look up a slot by its document id, e.g. "2026-11-10_dinner".
        final bySlot = {for (final p in snapshot.data!) p.id: p};
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            _header(context, bySlot.length),
            for (final day in _days) _dayCard(context, day, bySlot),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, int planned) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (planned == 0) {
      // New-user guide: tells them exactly what to do on an empty week.
      return AppCard(
        color: scheme.secondaryContainer,
        borderColor: AppColors.orange,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: scheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap any meal below to pick a recipe. When you are done, '
                  'tap Generate shopping list.',
                  style: textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        '$planned of 21 meals planned this week',
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _dayCard(
    BuildContext context,
    DateTime day,
    Map<String, MealPlan> bySlot,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return AppCard(
      borderColor: isToday ? scheme.primary : null,
      borderWidth: isToday ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('EEEE').format(day),
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat('MMM d').format(day),
                  style: textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (isToday) ...[
                  const Spacer(),
                  const InfoChip(icon: Icons.today, label: 'Today'),
                ],
              ],
            ),
            const SizedBox(height: 8),
            for (final meal in kMeals)
              PlanSlot(
                meal: meal,
                plan: bySlot[MealPlan.buildId(day, meal)],
                onTap: () => _openPicker(
                  day,
                  meal,
                  bySlot[MealPlan.buildId(day, meal)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: searchable list of all recipes, plus "Clear slot" if filled.
class _RecipePicker extends StatefulWidget {
  final void Function(Recipe recipe) onPick;
  final VoidCallback? onClear;
  const _RecipePicker({required this.onPick, this.onClear});

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  late final Stream<List<Recipe>> _recipes;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _recipes = FirestoreService.instance.streamRecipes();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a recipe',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(
                  hintText: 'Search recipes',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            if (widget.onClear != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(Icons.close, color: scheme.error),
                title: Text(
                  'Clear slot',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
                onTap: () {
                  widget.onClear!();
                  Navigator.pop(context);
                },
              ),
            Expanded(
              child: StreamBuilder<List<Recipe>>(
                stream: _recipes,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final shown = snapshot.data!
                      .where((r) => r.name.toLowerCase().contains(_search))
                      .toList();
                  if (shown.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off,
                      title: 'No matches',
                      message: 'No recipes match your search.',
                    );
                  }
                  return ListView(
                    children: [
                      for (final r in shown)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          title: Text(
                            r.name,
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: _subtitle(r) == null
                              ? null
                              : Text(_subtitle(r)!),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () {
                            widget.onPick(r);
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _subtitle(Recipe r) {
    final parts = <String>[
      if (r.prepTimeMinutes > 0) '${r.prepTimeMinutes} min',
      if (r.tags.isNotEmpty) r.tags.join(', '),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
