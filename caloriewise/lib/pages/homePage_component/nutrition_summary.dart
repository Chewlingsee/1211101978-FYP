import 'package:flutter/material.dart';

class NutritionSummary extends StatelessWidget {
  final Map<String, dynamic> totals;
  final Map<String, double> dailyTargets;
  final bool loading;

  const NutritionSummary({
    super.key,
    required this.totals,
    required this.dailyTargets,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final targetCalories = dailyTargets['calories'] ?? 2000;
    final targetFat = dailyTargets['fat'] ?? 65;
    final targetCarbs = dailyTargets['carbs'] ?? 300;
    final targetProtein = dailyTargets['protein'] ?? 150;

    // Determine if values exceed targets
    final caloriesExceeded = totals['calories'] > targetCalories;
    final fatExceeded = totals['fat'] > targetFat;
    final carbsExceeded = totals['carbs'] > targetCarbs;
    final proteinExceeded = totals['protein'] > targetProtein;

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
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 43, 29, 192),
                ),
                children: [
                  TextSpan(
                    text: '${totals['calories']?.toStringAsFixed(1) ?? '0'}',
                    style: TextStyle(
                      color:
                          caloriesExceeded
                              ? Colors.red
                              : const Color.fromARGB(255, 43, 29, 192),
                    ),
                  ),
                  const TextSpan(text: '/'),
                  TextSpan(text: '$targetCalories kcal'),
                ],
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
                    exceeded: fatExceeded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMacroCard(
                    'Carbs',
                    totals['carbs'],
                    targetCarbs,
                    Colors.green[100]!,
                    exceeded: carbsExceeded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMacroCard(
                    'Protein',
                    totals['protein'],
                    targetProtein,
                    Colors.blue[100]!,
                    exceeded: proteinExceeded,
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
    Color cardColor, {
    required bool exceeded,
  }) {
    return Card(
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 8, 49),
              ),
            ),
            const SizedBox(height: 5),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: Color.fromARGB(255, 42, 27, 159),
                ),
                children: [
                  TextSpan(
                    text: '${current?.toStringAsFixed(1) ?? '0'}',
                    style: TextStyle(
                      color:
                          exceeded
                              ? Colors.red
                              : const Color.fromARGB(255, 43, 29, 192),
                    ),
                  ),
                  const TextSpan(text: '/\n'),
                  TextSpan(text: '$target g'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
