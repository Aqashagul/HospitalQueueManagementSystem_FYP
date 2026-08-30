import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:queue_management_system/data/analytics_controller.dart';

class CompletedVsCancelledChart extends StatelessWidget {
  const CompletedVsCancelledChart({super.key});

  @override
  Widget build(BuildContext context) {
  final data = AnalyticsController().getCompletedVsCancelled();
final departments = data["departments"] as List<String>;
final completed = data["completed"] as List<double>;
final cancelled = data["cancelled"] as List<double>;

    return SizedBox(
      height: 260,
      child: Column(
        children: [
          Row(
            children: [
              _legendDot(const Color(0xFF6FCF97), "Completed"),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFFEB5757), "Cancelled"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= departments.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(departments[index],
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
             
                barGroups: List.generate(departments.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: completed[index].toDouble(),
                        color: const Color(0xFF6FCF97),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: cancelled[index].toDouble(),
                        color: const Color(0xFFEB5757),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    barsSpace: 4, 
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}