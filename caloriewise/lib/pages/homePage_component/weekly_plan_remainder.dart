import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyPlanReminder extends StatelessWidget {
  final Map<String, dynamic>? weeklyPlan;
  final DateTime today;
  final VoidCallback onGenerateNewPlan;

  const WeeklyPlanReminder({
    super.key,
    required this.weeklyPlan,
    required this.today,
    required this.onGenerateNewPlan,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyPlan == null) return const SizedBox();

    final startDate = DateTime.parse(weeklyPlan!.values.first['date']);
    final endDate = DateTime.parse(weeklyPlan!.values.last['date']);

    if (today.isAfter(endDate)) {
      return Column(
        children: [
          const Text(
            'Your weekly plan has ended today. \nYou will need to generate a new plan tomorrow.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 54, 130, 244),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    return Text(
      'Weekly Plan: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}',
      style: const TextStyle(fontSize: 14, color: Colors.grey),
    );
  }
}
