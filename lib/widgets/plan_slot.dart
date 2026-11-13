import 'package:flutter/material.dart';
import 'package:project6/models/meal_plan.dart';

class PlanSlot extends StatelessWidget {
  final String meal; // "breakfast" | "lunch" | "dinner"
  final MealPlan? plan;
  final VoidCallback onTap;
  const PlanSlot({
    super.key,
    required this.meal,
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = meal[0].toUpperCase() + meal.substring(1);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: plan == null
            ? const Text('Add meal',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            : Text(plan!.recipeName),
        trailing: Icon(plan == null ? Icons.add : Icons.edit, size: 18),
        onTap: onTap,
      ),
    );
  }
}