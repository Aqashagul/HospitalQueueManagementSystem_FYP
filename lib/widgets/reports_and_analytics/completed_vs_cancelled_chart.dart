import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// >>> Make sure this import points to where you saved analytics_data.dart <<<
import 'analytics_data.dart';

// Completed vs cancelled tokens per department in the selected period,
// live from Firestore.
class CompletedVsCancelledChart extends StatelessWidget {
  final QueueDocs docs;
  const CompletedVsCancelledChart({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    final data = AnalyticsData.completedVsCancelled(docs);
    final departments = data["departments"] as List<String>;
    final completed = data["completed"] as List<double>;
    final cancelled = data["cancelled"] as List<double>;

    if (departments.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/no_data.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                "No data in this period",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    // Keep the chart readable even when every bar is 0.
    final double highest = [
      ...completed,
      ...cancelled,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final double maxY = highest < 4 ? 4 : highest + 1;

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
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= departments.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            departments[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY <= 8 ? 1 : null,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(departments.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: completed[index],
                        color: const Color(0xFF6FCF97),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: cancelled[index],
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}