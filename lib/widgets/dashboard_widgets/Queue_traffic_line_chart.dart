import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/data/appdata_store.dart';

// Dashboard line chart showing patient registrations across the working
// hours of the day (8 AM–5 PM), with a purple gradient fill under the line.
class QueueTrafficChart extends StatelessWidget {
  const QueueTrafficChart({super.key});

  // Buckets all patients by registration hour and returns one point per
  // hour in the 8 AM–5 PM range (hours with no patients still get a
  // zero point, so the line stays continuous).
  List<FlSpot> _calculateHourlyData() {
    final patients = AppdataStore().patient;

    final Map<int, int> hourCounts = {};
    for (int hour = 8; hour <= 17; hour++) {
      hourCounts[hour] = 0;
    }

    for (final patient in patients) {
      final hour = patient.registrationTime.hour;
      if (hourCounts.containsKey(hour)) {
        hourCounts[hour] = hourCounts[hour]! + 1;
      }
    }

    return hourCounts.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> dataPoints = _calculateHourlyData();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          // Light horizontal grid lines only — no vertical lines, for a cleaner look.
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),

          // No border around the chart, for a cleaner look.
          borderData: FlBorderData(show: false),

          titlesData: FlTitlesData(
            // No labels needed on the top or right edges.
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            // X-axis: hour labels, shown every 2 hours to avoid crowding,
            // formatted as 12-hour time (e.g. "2PM").
            bottomTitles: AxisTitles(
              axisNameSize: 38,
              axisNameWidget: Transform.translate(
                offset: const Offset(0, 12),
                child: const Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color.fromARGB(255, 164, 164, 164),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  final label = hour == 12
                      ? "12PM"
                      : hour > 12
                          ? "${hour - 12}PM"
                          : "${hour}AM";
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Y-axis: patient count labels.
            leftTitles: AxisTitles(
              axisNameSize: 35,
              axisNameWidget: Transform.translate(
                offset: const Offset(25, -13),
                child: const Text(
                  'Patients',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color.fromARGB(255, 164, 164, 164),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),

          // The line itself, with a soft gradient fill underneath
          // to give it an area-chart look.
          lineBarsData: [
            LineChartBarData(
              spots: dataPoints,
              isCurved: true,
              color: const Color(0xFFA25AE6),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFA25AE6).withValues(alpha: .25),
                    const Color(0xFFA25AE6).withValues(alpha: .0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],

          // Shows a small tooltip with the patient count when a point is tapped.
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.grey.shade800,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "${spot.y.toInt()} patients",
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}