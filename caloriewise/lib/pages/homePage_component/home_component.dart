// ui_components.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caloriewise/pages/search/recipe_card.dart';
import 'package:caloriewise/pages/search/recipe_modal.dart';

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}

Widget buildNutritionSummary(
  Map<String, dynamic>? meals,
  Map<String, double> targets,
  bool loadingTargets,
) {
  final totals =
      meals?['totals'] ?? {'calories': 0, 'fat': 0, 'carbs': 0, 'protein': 0};
  final targetCalories = targets['calories'] ?? 2000;
  final targetFat = targets['fat'] ?? 65;
  final targetCarbs = targets['carbs'] ?? 300;
  final targetProtein = targets['protein'] ?? 150;

  if (loadingTargets) {
    return const Center(child: CircularProgressIndicator());
  }

  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          const Text(
            'Daily Calories & Macronutrients',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '${totals['calories']?.toStringAsFixed(1) ?? '0'}/$targetCalories kcal',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMacroCard(
                  'Fat',
                  totals['fat'],
                  targetFat,
                  Colors.red[100]!,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroCard(
                  'Carbs',
                  totals['carbs'],
                  targetCarbs,
                  Colors.green[100]!,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroCard(
                  'Protein',
                  totals['protein'],
                  targetProtein,
                  Colors.blue[100]!,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildMacroCard(
  String title,
  dynamic current,
  double target,
  Color color,
) {
  return Card(
    color: color,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(
            '${current?.toStringAsFixed(1) ?? '0'}/\n$target g',
            style: const TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget buildTodaysMeals(
  BuildContext context,
  Map<String, dynamic>? weeklyPlan,
  int currentDayIndex,
  Function(String, bool) onStatusChange,
  Function(Map<String, dynamic>) onAddToIntake,
) {
  if (weeklyPlan == null || weeklyPlan.isEmpty) {
    return const Text('No meal plan available for today');
  }

  final dayKey = weeklyPlan.keys.elementAt(currentDayIndex);
  final todayMeals = weeklyPlan[dayKey];
  final meals = todayMeals['meals'] as Map<String, dynamic>;
  final dayDate = DateTime.parse(todayMeals['date']);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$dayKey (${DateFormat('EEEE').format(dayDate)})',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      const Text(
        "Today's Recommended Meals:",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 10),
      ...meals.entries.map((entry) {
        final mealType = entry.key;
        final meal = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: RecipeCard(
                  recipe: {
                    'label': '${mealType.capitalize()}: ${meal['recipe_name']}',
                    'calories': meal['calories']?.toStringAsFixed(0),
                    'servings': meal['servings']?.toStringAsFixed(1),
                    'protein': meal['protein']?.toStringAsFixed(1),
                    'carbs': meal['carbs']?.toStringAsFixed(1),
                    'fat': meal['fat']?.toStringAsFixed(1),
                    'ingredient_lines': '',
                    'recipe_instructions': '',
                  },
                  cardColor: _getMealTypeColor(mealType),
                  onTap:
                      () => RecipeModal.show(context, {
                        ...meal,
                        'label': meal['recipe_name'],
                      }, onAddToIntake: onAddToIntake),
                ),
              ),
              Checkbox(
                value: meal['status'] == 'completed',
                onChanged: (value) => onStatusChange(mealType, value ?? false),
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
