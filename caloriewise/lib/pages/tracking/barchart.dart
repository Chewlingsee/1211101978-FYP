import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalorieBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final double targetCalories;

  const CalorieBarChart({
    super.key,
    required this.logs,
    required this.targetCalories,
  });

  @override
  Widget build(BuildContext context) {
    final double interval = 500;
    final double rawMaxY = targetCalories * 1.5;
    final double maxY = (rawMaxY / interval).ceil() * interval;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = DateFormat(
                  'MM/dd',
                ).format(DateTime.parse(logs[group.x.toInt()]['date']));
                final calories = rod.toY;
                final difference = calories - targetCalories;
                final absoluteDifference = difference.abs();

                String status;
                if (difference > 0) {
                  status = 'Exceeds by ${absoluteDifference.toInt()} cal';
                } else if (difference < 0) {
                  status = 'Below by ${absoluteDifference.toInt()} cal';
                } else {
                  status = 'Exactly on target';
                }

                return BarTooltipItem(
                  '$date\n${calories.toInt()} cal\n$status',
                  const TextStyle(color: Colors.white),
                );
              },
              tooltipMargin: 8, // Add margin to prevent touching edges
              tooltipPadding: const EdgeInsets.all(8), // Inner padding
              fitInsideHorizontally: true, // Ensure horizontal fit
              fitInsideVertically: true, // Ensure vertical fit
              direction: TooltipDirection.top, // Display above bars
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Calories',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              axisNameSize: 30,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Day',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < logs.length) {
                    final date = DateTime.parse(logs[index]['date']);
                    return Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine:
                (value) => FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                  dashArray: [5, 4],
                ),
          ),
          barGroups:
              logs.asMap().entries.map((entry) {
                final index = entry.key;
                final calories =
                    (entry.value['actual_calories'] as num).toDouble();
                final difference = calories - targetCalories;
                final epsilon =
                    0.99; // Small value to account for floating point precision

                Color barColor;
                if (difference > 0 && difference.abs() > epsilon) {
                  barColor = const Color.fromARGB(
                    255,
                    251,
                    165,
                    145,
                  ); // Exceeds - orange
                } else {
                  barColor = const Color.fromARGB(
                    255,
                    195,
                    166,
                    255,
                  ); // Below - purple
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: calories,
                      color: barColor,
                      width: 30,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }).toList(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetCalories,
                color: Colors.red,
                strokeWidth: 2,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (_) => 'Target: ${targetCalories.toInt()} cal',
                  alignment: Alignment.centerRight,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }
}
