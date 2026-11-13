class Ingredient {
  String name; // lowercase, trimmed
  double qty;
  String unit; // "g", "ml", "count", "tbsp", "tsp", "cup", ...

  Ingredient({required String name, required this.qty, required this.unit})
      : name = name.trim().toLowerCase();

  factory Ingredient.fromMap(Map<String, dynamic> m) => Ingredient(
    name: m['name'] as String,
    qty: (m['qty'] as num).toDouble(),
    unit: m['unit'] as String,
  );

  Map<String, dynamic> toMap() => {'name': name, 'qty': qty, 'unit': unit};
}

class Recipe {
  String id;
  String name;
  List<Ingredient> ingredients;
  String instructions;
  int prepTimeMinutes; // 0 if unknown
  List<String> tags;
  int? calories;
  String? imageUrl; // photo link (online recipes); null if none
  bool isFavorite;
  DateTime createdAt;

  Recipe({
    this.id = '',
    required this.name,
    required this.ingredients,
    this.instructions = '',
    this.prepTimeMinutes = 0,
    this.tags = const [],
    this.calories,
    this.imageUrl,
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Recipe.fromMap(Map<String, dynamic> m, {String id = ''}) => Recipe(
    id: id,
    name: m['name'] as String,
    ingredients: ((m['ingredients'] ?? []) as List)
        .map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    instructions: (m['instructions'] ?? '') as String,
    prepTimeMinutes: (m['prepTimeMinutes'] ?? 0) as int,
    tags: List<String>.from(m['tags'] ?? []),
    calories: m['calories'] as int?,
    imageUrl: m['imageUrl'] as String?,
    isFavorite: (m['isFavorite'] ?? false) as bool,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['createdAt'] ?? 0) as int),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'instructions': instructions,
    'prepTimeMinutes': prepTimeMinutes,
    'tags': tags,
    'calories': calories,
    'imageUrl': imageUrl,
    'isFavorite': isFavorite,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}