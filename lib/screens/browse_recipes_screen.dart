import 'package:flutter/material.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/services/meal_api_service.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';
import 'package:project6/widgets/recipe_card.dart' show PantryMatchSection;

/// Loads the full list of online recipes (tests pass a fake).
typedef RecipeLoader = Future<List<OnlineRecipe>> Function();

/// Opened by "Add recipe": a list of online recipes to add with one tap, with
/// a button at the top to type in your own recipe instead.
class BrowseRecipesScreen extends StatefulWidget {
  /// Saves a recipe to the user's collection.
  final Future<void> Function(Recipe recipe) onSave;

  /// Tests pass a fake; the app leaves this null and uses TheMealDB.
  final RecipeLoader? loadAll;

  /// The user's pantry. When given, each recipe shows how much of it you
  /// already have, and the best matches come first. Null hides that.
  final Stream<List<PantryItem>>? pantryStream;

  const BrowseRecipesScreen({
    super.key,
    required this.onSave,
    this.loadAll,
    this.pantryStream,
  });

  @override
  State<BrowseRecipesScreen> createState() => _BrowseRecipesScreenState();
}

class _BrowseRecipesScreenState extends State<BrowseRecipesScreen> {
  static const _pageSize = 20;

  final _controller = TextEditingController();
  final _api = MealApi();
  final Set<String> _added = {}; // recipe names added during this visit
  List<OnlineRecipe> _all = [];
  bool _loading = true;
  bool _searching = false; // an extra online lookup is running
  String? _error;
  String _query = '';
  bool _currentOnly = false; // base filter: "Current ingredients"
  RecipeFilters _filters = RecipeFilters(); // the Filters pop-up
  int _visible = _pageSize; // how many results are shown

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await (widget.loadAll ?? _api.catalog)();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load online recipes. Check your internet '
            'connection and try again.';
      });
    }
  }

  /// Re-reads the catalog after extra lookups added recipes to it.
  Future<void> _lookup(List<String> queries) async {
    if (widget.loadAll != null || queries.isEmpty) return;
    setState(() => _searching = true);
    try {
      await Future.wait(queries.map(
        (q) => _api.search(q).catchError((_) => <OnlineRecipe>[]),
      ));
      final list = await _api.catalog();
      if (mounted) setState(() => _all = list);
    } catch (_) {
      // Keep what we already have.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Typing filters the list straight away. Pressing search also asks the
  /// API, so a recipe missing from the starter list can still be found.
  void _submitSearch(String raw) {
    final q = raw.trim();
    if (q.length >= 2) _lookup([q]);
  }

  /// "Current ingredients" also looks up recipes named after what you have.
  void _setCurrentOnly(bool value, List<PantryItem> pantry) {
    setState(() {
      _currentOnly = value;
      _visible = _pageSize;
    });
    if (value) {
      _lookup(pantry.map((p) => p.name).toSet().take(8).toList());
    }
  }

  Future<void> _openFilters(List<PantryItem> pantry) async {
    // Most common ingredients across the loaded recipes (not the basics).
    const skip = {'salt', 'water', 'pepper', 'black pepper', 'sea salt', 'sugar'};
    final counts = <String, int>{};
    for (final r in _all) {
      for (final i in r.recipe.ingredients) {
        counts[i.name] = (counts[i.name] ?? 0) + 1;
      }
    }
    final pantryNames = pantry.map((p) => p.name).toSet().toList()..sort();
    final common = (counts.entries
            .where((e) => !skip.contains(e.key) && !pantryNames.contains(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(20)
        .map((e) => e.key)
        .toList();

    final result = await showModalBottomSheet<RecipeFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initial: _filters.copy(),
        pantryNames: pantryNames,
        commonNames: common,
      ),
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _visible = _pageSize;
      });
      _fetchForFilters();
    }
  }

  /// Asks the API for recipes that fit the filters, then re-reads the catalog.
  Future<void> _fetchForFilters() async {
    if (widget.loadAll != null || _filters.count == 0) return;
    setState(() => _searching = true);
    try {
      await _api.fetchForFilters(_filters);
      final list = await _api.catalog();
      if (mounted) setState(() => _all = list);
    } catch (_) {
      // Keep what we already have.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Recipe recipe) async {
    if (_added.contains(recipe.name)) return;
    try {
      await widget.onSave(recipe);
      if (!mounted) return;
      setState(() => _added.add(recipe.name));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${recipe.name} to your recipes')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save recipe: $e')),
        );
      }
    }
  }

  void _createOwn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRecipeScreen(onSave: widget.onSave)),
    );
  }

  /// Photo for a recipe, or the tinted placeholder (also shown while loading
  /// and if the picture can't be loaded).
  Widget _photo(String? url, double height) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant_menu,
          size: 44, color: scheme.onPrimaryContainer),
    );
    if (url == null) return placeholder;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 900,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }

  void _preview(OnlineRecipe online) {
    final recipe = online.recipe;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        final added = _added.contains(recipe.name);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    if (online.imageUrl != null) ...[
                      _photo(online.imageUrl, 200),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      recipe.name,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ingredients',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final i in recipe.ingredients)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${formatQty(i.qty)} ${i.unit}  ${capitalize(i.name)}',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    if (recipe.instructions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Instructions',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(recipe.instructions, style: textTheme.bodyLarge),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: added
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _add(recipe);
                          },
                    child: Text(added ? 'Added' : 'Add to my recipes'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pairs each online recipe with how well the pantry covers it. With a
  /// pantry, best matches come first; without one, recipes are A to Z and the
  /// match is null.
  List<(OnlineRecipe, RecipeMatch?)> _withMatches(
    List<OnlineRecipe> list,
    List<PantryItem> pantry,
  ) {
    if (pantry.isEmpty) {
      final sorted = [...list]
        ..sort((a, b) => a.recipe.name.compareTo(b.recipe.name));
      return [for (final r in sorted) (r, null)];
    }
    final byRecipe = {for (final r in list) r.recipe: r};
    final ranked = rankRecipesByPantry(byRecipe.keys.toList(), pantry);
    return [for (final m in ranked) (byRecipe[m.recipe]!, m)];
  }

  /// Same look as the recipe list's cards (square corners, header, name,
  /// chips, tags), but one per row and larger, with the recipe's photo.
  Widget _resultCard(OnlineRecipe online, RecipeMatch? match) {
    final r = online.recipe;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final added = _added.contains(r.name);
    final count = r.ingredients.length;
    return AppCard(
      radius: 0, // square corners, like the recipe list
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () => _preview(online),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _photo(online.imageUrl, 190),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (match == null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoChip(
                        icon: Icons.shopping_basket_outlined,
                        label: '$count item${count == 1 ? '' : 's'}',
                      ),
                    ],
                  )
                else
                  PantryMatchSection(match: match),
                if (r.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    r.tags.join(' · '),
                    style: textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: added ? null : () => _add(r),
                    icon: Icon(added ? Icons.check : Icons.add),
                    label: Text(added ? 'Added' : 'Add to my recipes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add a recipe',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<PantryItem>>(
        stream: widget.pantryStream,
        builder: (context, pantrySnap) {
          // Expired food doesn't count as "in the pantry".
          final pantry = (pantrySnap.data ?? const <PantryItem>[])
              .where((p) => !p.isExpired())
              .toList();
          // Search and the pop-up filters first, then the pantry ranking.
          final q = _query.toLowerCase();
          final filtered = [
            for (final r in _all)
              if ((q.isEmpty || r.recipe.name.toLowerCase().contains(q)) &&
                  matchesFilters(r, _filters))
                r,
          ];
          var rows = _withMatches(filtered, pantry);
          if (_currentOnly) {
            // You have at least half of the ingredients.
            rows = rows
                .where((x) => x.$2 != null && x.$2!.score >= 0.5)
                .toList();
          }
          final shown = rows.take(_visible).toList();

          return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AppCard(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            onTap: _createOwn,
            child: const ListTile(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(Icons.edit_note, size: 30),
              title: Text(
                'Create your own recipe',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Type in your own recipe instead'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 17),
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: 'Search online recipes',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _visible = _pageSize;
                          });
                        },
                      ),
              ),
              onChanged: (v) => setState(() {
                _query = v.trim();
                _visible = _pageSize;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('All recipes'),
                  selected: !_currentOnly,
                  onSelected: (_) => _setCurrentOnly(false, pantry),
                ),
                ChoiceChip(
                  label: const Text('Current ingredients'),
                  selected: _currentOnly,
                  onSelected: (_) => _setCurrentOnly(true, pantry),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: () => _openFilters(pantry),
                  icon: const Icon(Icons.tune),
                  label: Text(
                    _filters.count == 0
                        ? 'Filters'
                        : 'Filters (${_filters.count})',
                  ),
                ),
              ],
            ),
          ),
          if (_filters.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in _filters.mealTypes)
                    InputChip(
                      label: Text(t),
                      onDeleted: () => setState(() {
                        _filters.mealTypes.remove(t);
                        _visible = _pageSize;
                      }),
                    ),
                  for (final i in _filters.ingredients)
                    InputChip(
                      label: Text(capitalize(i)),
                      onDeleted: () => setState(() {
                        _filters.ingredients.remove(i);
                        _visible = _pageSize;
                      }),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              _loading
                  ? 'Loading recipes…'
                  : _searching
                      ? 'Looking for more recipes…'
                      : _currentOnly
                          ? '${rows.length} recipe${rows.length == 1 ? '' : 's'} you can mostly make'
                          : '${rows.length} recipe${rows.length == 1 ? '' : 's'}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ErrorBanner(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (rows.isEmpty && _searching)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                _currentOnly && pantry.isEmpty
                    ? 'Add items to your pantry to use "Current ingredients".'
                    : 'No recipes match. Try removing a filter, search another '
                        'word, or create your own recipe above.',
                style: textTheme.bodyLarge,
              ),
            )
          else ...[
            for (final r in shown) _resultCard(r.$1, r.$2),
            if (rows.length > shown.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton(
                  onPressed: () => setState(() => _visible += _pageSize),
                  child: Text('Show more (${rows.length - shown.length} left)'),
                ),
              ),
          ],
        ],
      );
        },
      ),
    );
  }
}

/// The in-depth Filters pop-up: meal type and specific ingredients.
class _FilterSheet extends StatefulWidget {
  final RecipeFilters initial;
  final List<String> pantryNames; // what you have
  final List<String> commonNames; // popular ingredients in the recipes

  const _FilterSheet({
    required this.initial,
    required this.pantryNames,
    required this.commonNames,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final RecipeFilters _f = widget.initial;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _addCustom(String raw) {
    final word = raw.trim().toLowerCase();
    if (word.isNotEmpty) setState(() => _f.ingredients.add(word));
    _custom.clear();
  }

  Widget _ingredientChips(List<String> names) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in names)
          FilterChip(
            label: Text(capitalize(n)),
            selected: _f.ingredients.contains(n),
            onSelected: (on) => setState(() {
              on ? _f.ingredients.add(n) : _f.ingredients.remove(n);
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final listed = {...widget.pantryNames, ...widget.commonNames};
    final custom = _f.ingredients.where((i) => !listed.contains(i)).toList();
    final titleStyle =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text(
                    'Filters',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text('Meal type', style: titleStyle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in mealTypeCategories.keys)
                        FilterChip(
                          label: Text(t),
                          selected: _f.mealTypes.contains(t),
                          onSelected: (on) => setState(() {
                            on ? _f.mealTypes.add(t) : _f.mealTypes.remove(t);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Ingredients', style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Recipes must use every ingredient you pick.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _custom,
                    style: const TextStyle(fontSize: 17),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _addCustom,
                    decoration: InputDecoration(
                      hintText: 'Type an ingredient',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add ingredient',
                        onPressed: () => _addCustom(_custom.text),
                      ),
                    ),
                  ),
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ingredientChips(custom),
                  ],
                  if (widget.pantryNames.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('In your pantry', style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _ingredientChips(widget.pantryNames),
                  ],
                  if (widget.commonNames.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Popular ingredients', style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _ingredientChips(widget.commonNames),
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
                      onPressed: () => setState(() {
                        _f.mealTypes.clear();
                        _f.ingredients.clear();
                      }),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _f),
                      child: const Text('Show recipes'),
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
