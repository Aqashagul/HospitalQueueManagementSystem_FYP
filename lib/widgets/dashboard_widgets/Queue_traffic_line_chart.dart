import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Dashboard line chart showing patient registrations across the working
// hours of the day (8 AM–5 PM), with a purple gradient fill under the line.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queue_management_system/screens/queue_admin_service.dart';

// >>> KEEP YOUR OTHER EXISTING IMPORTS HERE <<<
// (QueueAdminService, from the same path your other files use.
//  AppdataStore is no longer needed in this file.)

class QueueTrafficChart extends StatefulWidget {
  const QueueTrafficChart({super.key});

  @override
  State<QueueTrafficChart> createState() => _QueueTrafficChartState();
}

class _QueueTrafficChartState extends State<QueueTrafficChart> {
  // Today's queue entries of all doctors, live from Firestore.
  final QueueAdminService _service = QueueAdminService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchTodaysEntries();
  }

  // Buckets today's tokens by the hour they were taken and returns one
  // point per hour in the 8 AM–5 PM range (hours with no patients still
  // get a zero point, so the line stays continuous).
  List<FlSpot> _calculateHourlyData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<int, int> hourCounts = {};
    for (int hour = 8; hour <= 17; hour++) {
      hourCounts[hour] = 0;
    }

    for (final d in docs) {
      final t = d.data()['joinedAt'];
      // joinedAt is null for a moment right after a patient joins, so
      // treat that as "now".
      final hour = (t is Timestamp ? t.toDate() : DateTime.now()).hour;
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 250,
            child: Center(
              child: Text(
                QueueAdminService.friendlyError(snapshot.error!),
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          );
        }

        // Zeros while loading, real numbers once data arrives.
        final List<FlSpot> dataPoints = _calculateHourlyData(
          snapshot.data?.docs ?? [],
        );

        return SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              // Light horizontal grid lines only — no vertical lines, for a
              // cleaner look.
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
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

                // X-axis: hour labels, shown every 2 hours to avoid
                // crowding, formatted as 12-hour time (e.g. "2PM").
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

              // Shows a small tooltip with the patient count when a point
              // is tapped.
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
      },
    );
  }
}