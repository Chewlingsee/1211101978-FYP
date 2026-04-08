import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeightLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> weightLogs;

  const WeightLineChart({super.key, required this.weightLogs});

  @override
  Widget build(BuildContext context) {
    if (weightLogs.isEmpty) return const Center(child: Text("No weight data"));

    final processedLogs = _processWeightLogs(weightLogs);

    final spots =
        processedLogs.asMap().entries.map((entry) {
          int index = entry.key;
          double weight = entry.value['weight'];
          return FlSpot(index.toDouble(), weight);
        }).toList();

    final double minY =
        (processedLogs
            .map((e) => e['weight'] as double)
            .reduce((a, b) => a < b ? a : b)).floorToDouble();
    final double maxY =
        (processedLogs
            .map((e) => e['weight'] as double)
            .reduce((a, b) => a > b ? a : b)).ceilToDouble();

    // Total width: 60 pixels per point
    final double chartWidth = spots.length * 60.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width:
              chartWidth < MediaQuery.of(context).size.width
                  ? MediaQuery.of(context).size.width
                  : chartWidth,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 30.0,
              bottom: 16.0,
              left: 16.0,
              right: 30.0,
            ),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
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
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black),
                    left: BorderSide(color: Colors.black),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Weight (kg)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axisNameSize: 28,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1,
                      getTitlesWidget:
                          (value, _) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 12),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axisNameSize: 20,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index >= 0 && index < processedLogs.length) {
                          final date = DateTime.parse(
                            processedLogs[index]['date'],
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.deepPurple,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter:
                          (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.deepPurple,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color.fromARGB(67, 104, 58, 183),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = DateTime.parse(
                          processedLogs[spot.x.toInt()]['date'],
                        );
                        return LineTooltipItem(
                          '${DateFormat('MMM d, y').format(date)}\n'
                          '${spot.y.toStringAsFixed(1)} kg',
                          const TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 800),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _processWeightLogs(
    List<Map<String, dynamic>> logs,
  ) {
    final Map<String, Map<String, dynamic>> dateMap = {};

    for (var log in logs) {
      final dateStr = log['date'];
      final existing = dateMap[dateStr];
      if (existing == null) {
        dateMap[dateStr] = log;
      }
    }

    final uniqueLogs = dateMap.values.toList();
    uniqueLogs.sort((a, b) => a['date'].compareTo(b['date']));

    return uniqueLogs;
  }
}
