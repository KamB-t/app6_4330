import 'package:flutter/material.dart';
import 'package:project6/models/meal_plan.dart';

/// One meal row (Breakfast / Lunch / Dinner) inside a day card on the Plan tab.
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

  IconData get _icon => switch (meal) {
        'breakfast' => Icons.free_breakfast,
        'lunch' => Icons.lunch_dining,
        _ => Icons.dinner_dining,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = meal[0].toUpperCase() + meal.substring(1);
    final filled = plan != null;
    final onColor = filled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: filled ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(_icon, size: 28, color: onColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: textTheme.labelLarge?.copyWith(color: onColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          filled ? plan!.recipeName : 'Add meal',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                            color: filled ? onColor : scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    filled ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: filled ? onColor : scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
