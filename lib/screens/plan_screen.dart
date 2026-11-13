import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project6/models/meal_plan.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/services/firestore_service.dart';
import 'package:project6/widgets/plan_slot.dart';

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
            SnackBar(content: Text('Could not generate list: $e')));
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
        7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    _stream = _service.streamMealPlans(_days.first, _days.last);
  }

  Future<void> _openPicker(DateTime day, String meal, MealPlan? current) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generating ? null : _generate,
              child: const Text('Generate shopping list'),
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
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            for (final day in _days) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  DateFormat('EEEE, MMM d').format(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final meal in kMeals)
                PlanSlot(
                  meal: meal,
                  plan: bySlot[MealPlan.buildId(day, meal)],
                  onTap: () => _openPicker(
                      day, meal, bySlot[MealPlan.buildId(day, meal)]),
                ),
            ],
          ],
        );
      },
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search recipes',
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            if (widget.onClear != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear slot'),
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
                    return const Center(child: Text('No recipes match your search.'));
                  }
                  return ListView(
                    children: [
                      for (final r in shown)
                        ListTile(
                          title: Text(r.name),
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
}