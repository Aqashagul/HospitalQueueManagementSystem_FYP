import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:queue_management_system/data/appdata_store.dart';

// View model for one slice of the donut chart: a doctor's name,
// how many patients are assigned to them, and the color used to draw
// their slice.
class DoctorLoad {
  final String name;
  final int patients;
  final Color color;

  const DoctorLoad({
    required this.name,
    required this.patients,
    required this.color,
  });
}

// Donut chart showing patient distribution across doctors. Tapping a
// slice pops it out slightly and shows its name/count in the center.
class DoctorPatientsDonutChart extends StatefulWidget {
  const DoctorPatientsDonutChart({super.key});

  @override
  State<DoctorPatientsDonutChart> createState() =>
      _DoctorPatientsDonutChartState();
}

class _DoctorPatientsDonutChartState extends State<DoctorPatientsDonutChart> {
  // Index of the currently tapped/selected slice — null means nothing selected.
  int? touchedIndex;

  // Recomputed on every access so the chart always reflects the current
  // store state. Only doctors with at least one patient are included,
  // and each gets a color cycled from the fixed palette below.
  List<DoctorLoad> get doctorData {
    final patients = AppdataStore().patient;
    final doctors = AppdataStore().doctors;

    final List<Color> palette = [
      const Color(0xFFA25AE6),
      const Color.fromARGB(255, 103, 230, 189),
      const Color.fromARGB(255, 237, 202, 235),
      const Color(0xFF56CCF2),
      const Color.fromARGB(255, 87, 104, 174),
    ];

    final result = <DoctorLoad>[];
    for (final doctor in doctors) {
      final count = patients.where((p) => p.doctor == doctor.name).length;
      if (count > 0) {
        result.add(DoctorLoad(
          name: doctor.name,
          patients: count,
          color: palette[result.length % palette.length],
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Guard against an empty chart (no doctor has any patients yet) —
    // PieChart would otherwise divide by zero when computing percentages.
    if (doctorData.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text("No patient data yet", style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final int totalPatients =
        doctorData.fold(0, (sum, doc) => sum + doc.patients);

    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              // Empty space in the middle — larger value = more "donut",
              // smaller = closer to a full pie chart.
              centerSpaceRadius: 60,

              // Gap between adjacent slices.
              sectionsSpace: 3,

              // Handles tap/touch to select a slice. Clears the selection
              // when the user taps outside the chart, lifts their finger,
              // or taps the empty center hole (index -1).
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    final tappedIndex =
                        response?.touchedSection?.touchedSectionIndex;

                    if (!event.isInterestedForInteractions ||
                        tappedIndex == null ||
                        tappedIndex == -1) {
                      touchedIndex = null;
                      return;
                    }
                    touchedIndex = tappedIndex;
                  });
                },
              ),

              // One slice per doctor.
              sections: List.generate(doctorData.length, (index) {
                final doctor = doctorData[index];
                final isTouched = index == touchedIndex;

                // The "pop-out" effect: the touched slice gets a larger radius.
                final double radius = isTouched ? 65 : 55;

                return PieChartSectionData(
                  value: doctor.patients.toDouble(),
                  color: doctor.color,
                  radius: radius,
                  // Only show the percentage label on the touched slice.
                  title: isTouched
                      ? "${((doctor.patients / totalPatients) * 100).toStringAsFixed(0)}%"
                      : "",
                  titleStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
            // Smoothly animates the radius change when a slice is touched.
            swapAnimationDuration: const Duration(milliseconds: 300),
            swapAnimationCurve: Curves.easeOutCubic,
          ),

          // Text overlay in the center of the donut (possible because
          // of the Stack).
          _buildCenterLabel(),
        ],
      ),
    );
  }

  // Center label: shows the selected doctor's name and count if a slice
  // is selected, otherwise falls back to the total patient count.
  Widget _buildCenterLabel() {
    if (touchedIndex == null) {
      final total = doctorData.fold(0, (sum, doc) => sum + doc.patients);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$total",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Total Patients",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      );
    }

    final selectedDoctor = doctorData[touchedIndex!];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${selectedDoctor.patients}",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: selectedDoctor.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selectedDoctor.name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}