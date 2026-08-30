import 'package:flutter/material.dart';
import 'package:queue_management_system/data/analytics_controller.dart';

class DoctorWorkload {
  final String name;
  final double workloadPercent;

  const DoctorWorkload({
    required this.name,
    required this.workloadPercent,
  });
}

class DoctorWorkloadChart extends StatelessWidget {
  const DoctorWorkloadChart({super.key});

  Color _colorFor(double percent) {
    if (percent >= 80) {
      return const Color(0xFFEB5757);
    }

    if (percent >= 60) {
      return const Color(0xFFF2994A);
    }

    return const Color(0xFF6FCF97);
  }

  @override
  Widget build(BuildContext context) {

    // Get data from controller
    final data = AnalyticsController().getDoctorWorkload();

    // Convert Map data → DoctorWorkload objects
    final List<DoctorWorkload> doctors = data.map((doc) {
      return DoctorWorkload(
        name: doc["name"] as String,
        workloadPercent: (doc["workload"] as num).toDouble(),
      );
    }).toList();

    return Column(
      children: doctors.map((doc) {
        final color = _colorFor(doc.workloadPercent);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    doc.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    "${doc.workloadPercent.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: doc.workloadPercent / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}