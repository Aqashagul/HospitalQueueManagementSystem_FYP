import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:queue_management_system/data/analytics_controller.dart';

class SevenDayPatientsChart extends StatelessWidget {
   const SevenDayPatientsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AnalyticsController().getWeeklyPatientFlow();
    final days = data["days"] as List<String>;
    final served = data["served"] as List<double>;


    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
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
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(days[index],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.grey.shade800,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "${spot.y.toInt()} patients",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                days.length,
                (i) => FlSpot(i.toDouble(), served[i]),
              ),
              isCurved: true,
              color: const Color(0xFFA25AE6),
              barWidth: 3,
              
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFA25AE6).withValues(alpha: .25),
                    const Color(0xFFA25AE6).withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}