import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:queue_management_system/data/analytics_controller.dart';

class DepartmentEntry {
  final String name;
  final double percentage;
  final Color color;

  const DepartmentEntry({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

class PatientsByDepartmentChart extends StatelessWidget {
  const PatientsByDepartmentChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AnalyticsController().getPatientsByDepartment();

    final palette = [
      const Color(0xFFA25AE6),
      const Color(0xFF56CCF2),
      const Color(0xFF6FCF97),
      const Color(0xFFF2994A),
      const Color(0xFFEB5757),
    ];

    final List<DepartmentEntry> departmentEntries = List.generate(data.length, (
      i,
    ) {
      return DepartmentEntry(
        name: data[i]["name"] as String,
        percentage: data[i]["percentage"] as double,
        color: palette[i % palette.length],
      );
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 45,
              sectionsSpace: 3,
              sections: departmentEntries.map((d) {
                return PieChartSectionData(
                  value: d.percentage,
                  color: d.color,
                  radius: 50,
                  title: "",
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(width: 24),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: departmentEntries.map((d) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: d.color,
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        d.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    Text(
                      "${d.percentage.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
