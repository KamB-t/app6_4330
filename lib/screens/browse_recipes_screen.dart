import 'package:flutter/material.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/services/meal_api_service.dart';
import 'package:project6/theme/app_theme.dart';

/// Looks up recipes for [query]; an empty query means "show featured recipes".
typedef RecipeSearchFn = Future<List<Recipe>> Function(String query);

/// Opened by "Add recipe": a list of online recipes to add with one tap, with
/// a button at the top to type in your own recipe instead.
class BrowseRecipesScreen extends StatefulWidget {
  /// Saves a recipe to the user's collection.
  final Future<void> Function(Recipe recipe) onSave;

  /// Tests pass a fake; the app leaves this null and uses TheMealDB.
  final RecipeSearchFn? search;

  const BrowseRecipesScreen({super.key, required this.onSave, this.search});

  @override
  State<BrowseRecipesScreen> createState() => _BrowseRecipesScreenState();
}

class _BrowseRecipesScreenState extends State<BrowseRecipesScreen> {
  final _controller = TextEditingController();
  final _api = MealApi();
  final Set<String> _added = {}; // recipe names added during this visit
  List<Recipe> _results = [];
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

  Future<List<Recipe>> _defaultSearch(String q) =>
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

  void _preview(Recipe recipe) {
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

  Widget _resultCard(Recipe r) {
    final textTheme = Theme.of(context).textTheme;
    final added = _added.contains(r.name);
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => _preview(r),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final t in r.tags.take(2))
                        InfoChip(label: capitalize(t)),
                      InfoChip(label: '${r.ingredients.length} ingredients'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: ElevatedButton(
                onPressed: added ? null : () => _add(r),
                child: Text(added ? 'Added' : 'Add'),
              ),
            ),
          ],
        ),
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
      body: ListView(
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
            for (final r in _results) _resultCard(r),
        ],
      ),
    );
  }
}
