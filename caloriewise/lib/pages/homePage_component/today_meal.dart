import 'package:flutter/material.dart';
import 'package:caloriewise/pages/search/recipe_card.dart';
import 'package:caloriewise/pages/search/recipe_modal.dart';
import 'package:intl/intl.dart';

class TodaysMeals extends StatelessWidget {
  final Map<String, dynamic>? todayMeals;
  final Map<String, dynamic>? weeklyPlan;
  final int currentDayIndex;
  final Function(String, bool) onMealStatusChanged;
  final Function(Map<String, dynamic>) onAddToIntake; // Add this line

  const TodaysMeals({
    super.key,
    required this.todayMeals,
    required this.weeklyPlan,
    required this.currentDayIndex,
    required this.onMealStatusChanged,
    required this.onAddToIntake, // Add this line
  });

  List<MapEntry<String, dynamic>> _sortMealEntries(
    Iterable<MapEntry<String, dynamic>> entries,
  ) {
    const mealOrder = ['breakfast', 'lunch', 'brunch', 'dinner', 'snack'];

    return entries.toList()..sort((a, b) {
      final indexA = mealOrder.indexOf(a.key);
      final indexB = mealOrder.indexOf(b.key);

      // If mealType is not found in the list, push it to the end
      return (indexA == -1 ? mealOrder.length : indexA).compareTo(
        indexB == -1 ? mealOrder.length : indexB,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (todayMeals == null) {
      return const Text('No meal plan available for today');
    }

    final meals = todayMeals!['meals'] as Map<String, dynamic>;
    final dayKey = weeklyPlan!.keys.elementAt(currentDayIndex);
    final dayDate = DateTime.parse(todayMeals!['date']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$dayKey (${DateFormat('EEE, d MMMM y').format(dayDate)})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "Today's Recommended Meals:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        ..._sortMealEntries(meals.entries).map((mealEntry) {
          final mealType = mealEntry.key;
          final meal = mealEntry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: RecipeCard(
                    recipe: {
                      'label':
                          '${mealType.capitalize()}: ${meal['recipe_name']}',
                      'calories': meal['calories']?.toStringAsFixed(0),
                      'servings': meal['servings']?.toStringAsFixed(1),
                      'protein': meal['protein']?.toStringAsFixed(1),
                      'carbs': meal['carbs']?.toStringAsFixed(1),
                      'fat': meal['fat']?.toStringAsFixed(1),
                      'ingredient_lines': meal['ingredients'] ?? [],
                      'recipe_instructions': meal['instructions'] ?? '',
                    },
                    cardColor: _getMealTypeColor(mealType),
                    onTap:
                        () => RecipeModal.show(context, {
                          ...meal,
                          'label': meal['recipe_name'],
                          // Ensure all required nutrition fields are included
                          'calories': meal['calories']?.toString() ?? '0',
                          'fat': meal['fat']?.toString() ?? '0',
                          'carbs': meal['carbs']?.toString() ?? '0',
                          'protein': meal['protein']?.toString() ?? '0',
                        }, onAddToIntake: onAddToIntake),
                  ),
                ),
                Checkbox(
                  value: meal['status'] == 'completed',
                  onChanged:
                      (value) => onMealStatusChanged(mealType, value ?? false),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Colors.orange[100]!;
      case 'lunch':
        return Colors.green[100]!;
      case 'dinner':
        return Colors.blue[100]!;
      case 'snack':
        return Colors.purple[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
