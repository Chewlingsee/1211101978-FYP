import 'package:flutter/material.dart';

class WeeklyExercise extends StatelessWidget {
  final List<dynamic> recommendations;
  final Map<int, bool> completedStatus;
  final Function(int index, bool isChecked) onStatusChanged;

  const WeeklyExercise({
    super.key,
    required this.recommendations,
    required this.completedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Text("No workout recommendations available.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Weekly Workouts",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "Please ensure all the workouts done by this week.",
          style: TextStyle(
            fontSize: 15,
            color: Color.fromARGB(255, 9, 11, 150),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(recommendations.length, (index) {
          final workout = recommendations[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    color: _getDynamicColor(index),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Session ${workout['session_number']}: ${workout['workout_name']}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("Type: ${workout['activity_type']}"),
                          Text("Intensity: ${workout['intensity']}"),
                          Text(
                            "Duration: ${workout['minutes_per_session']} minutes",
                          ),
                          Text(
                            "Calories Burned: ${workout['calories_per_session']} kcal",
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Checkbox(
                  value: completedStatus[index] ?? false,
                  onChanged: (value) => onStatusChanged(index, value ?? false),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getDynamicColor(int index) {
    const colors = [
      Color(0xFFE1F5FE),
      Color(0xFFFFF9C4),
      Color(0xFFC8E6C9),
      Color(0xFFFFCDD2),
      Color(0xFFD1C4E9),
    ];
    return colors[index % colors.length];
  }
}
