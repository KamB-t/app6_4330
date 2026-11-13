import 'package:intl/intl.dart';

class MealPlan {
  String id; // "yyyy-MM-dd_meal"
  DateTime date; // midnight local
  String meal; // "breakfast" | "lunch" | "dinner"
  String recipeId;
  String recipeName;

  MealPlan({
    required DateTime date,
    required this.meal,
    required this.recipeId,
    required this.recipeName,
  })  : date = DateTime(date.year, date.month, date.day),
        id = buildId(date, meal);

  static String buildId(DateTime date, String meal) =>
      '${DateFormat('yyyy-MM-dd').format(date)}_$meal';

  factory MealPlan.fromMap(Map<String, dynamic> m) => MealPlan(
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    meal: m['meal'] as String,
    recipeId: m['recipeId'] as String,
    recipeName: m['recipeName'] as String,
  );

  Map<String, dynamic> toMap() => {
    'date': date.millisecondsSinceEpoch,
    'meal': meal,
    'recipeId': recipeId,
    'recipeName': recipeName,
  };
}