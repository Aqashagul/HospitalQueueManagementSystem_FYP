import 'package:flutter/material.dart';
import 'package:queue_management_system/data/appdata_store.dart';

// >>> Make sure this import points to where you saved analytics_data.dart <<<
import 'analytics_data.dart';

class DoctorWorkload {
  final String name;
  final double workloadPercent;

  const DoctorWorkload({required this.name, required this.workloadPercent});
}

// Each doctor's workload in the selected period, live from Firestore.
// workload % = tokens / (kDailyPatientCapacity x days), capped at 100.
class DoctorWorkloadChart extends StatelessWidget {
  final QueueDocs docs;

  // How many days the selected period covers (7, 30, or the days so far
  // this month).
  final int days;

  const DoctorWorkloadChart({super.key, required this.docs, required this.days});

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
    // Rebuild when the admin adds, edits or removes a doctor.
    return ListenableBuilder(
      listenable: AppdataStore(),
      builder: (context, _) {
        // doctorId -> doctor name
        final doctorNames = <String, String>{
          for (final d in AppdataStore().doctors)
            if (d.id != null) d.id!: d.name,
        };

        final data = AnalyticsData.doctorWorkload(docs, doctorNames, days);

        if (data.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text(
                "No doctors added yet",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        // Convert Map data -> DoctorWorkload objects
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
      },
    );
  }
}