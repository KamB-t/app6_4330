import 'package:flutter/material.dart';
import 'package:project6/models/pantry_item.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/services/meal_api_service.dart';
import 'package:project6/services/shopping_list_service.dart';
import 'package:project6/theme/app_theme.dart';
import 'package:project6/widgets/recipe_card.dart' show PantryMatchSection;

/// Looks up recipes for [query]; an empty query means "show featured recipes".
typedef RecipeSearchFn = Future<List<OnlineRecipe>> Function(String query);

/// Opened by "Add recipe": a list of online recipes to add with one tap, with
/// a button at the top to type in your own recipe instead.
class BrowseRecipesScreen extends StatefulWidget {
  /// Saves a recipe to the user's collection.
  final Future<void> Function(Recipe recipe) onSave;

  /// Tests pass a fake; the app leaves this null and uses TheMealDB.
  final RecipeSearchFn? search;

  /// The user's pantry. When given, each recipe shows how much of it you
  /// already have, and the best matches come first. Null hides that.
  final Stream<List<PantryItem>>? pantryStream;

  const BrowseRecipesScreen({
    super.key,
    required this.onSave,
    this.search,
    this.pantryStream,
  });

  @override
  State<BrowseRecipesScreen> createState() => _BrowseRecipesScreenState();
}

class _BrowseRecipesScreenState extends State<BrowseRecipesScreen> {
  final _controller = TextEditingController();
  final _api = MealApi();
  final Set<String> _added = {}; // recipe names added during this visit
  List<OnlineRecipe> _results = [];
  bool _loading = true;
  String? _error;
  String _shownQuery = '';
  int _requestId = 0; // ignores slow answers to an older search

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<OnlineRecipe>> _defaultSearch(String q) =>
      q.isEmpty ? _api.featured() : _api.search(q);

  Future<void> _load(String rawQuery) async {
    final query = rawQuery.trim();
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _shownQuery = query;
    });
    try {
      final found = await (widget.search ?? _defaultSearch)(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = 'Could not load online recipes. Check your internet '
            'connection and try again.';
      });
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
  /// pantry, best matches come first; without one, the order is unchanged and
  /// the match is null.
  List<(OnlineRecipe, RecipeMatch?)> _withMatches(List<PantryItem> pantry) {
    if (pantry.isEmpty) return [for (final r in _results) (r, null)];
    final byRecipe = {for (final r in _results) r.recipe: r};
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
              onSubmitted: _load,
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
                          _load('');
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              _shownQuery.isEmpty
                  ? 'Popular recipes online'
                  : 'Results for "$_shownQuery"',
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
                    onPressed: () => _load(_shownQuery),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'No recipes found for "$_shownQuery". Try another word, '
                'or create your own recipe above.',
                style: textTheme.bodyLarge,
              ),
            )
          else
            for (final r in _withMatches(pantry)) _resultCard(r.$1, r.$2),
        ],
      );
        },
      ),
    );
  }
}
