import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/widgets/dashboard_widgets/Queue_traffic_line_chart.dart';
import 'package:queue_management_system/widgets/dashboard_widgets/current_queue.dart';
import 'package:queue_management_system/widgets/dashboard_widgets/doctor_patient_donut_chart.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/icon_circle.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';
import 'package:google_fonts/google_fonts.dart';



class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patients = AppdataStore().patient;
    final doctors = AppdataStore().doctors;

    final int patientsWaiting = patients.where((p) => p.status == "Waiting").length;
    final int patientsServed = patients.where((p) => p.status == "Completed").length;
    final int inConsultation = patients.where((p) => p.status == "In Consultation").length;
    final int totalPatients = patients.length;

    final int totalDepartments = AppdataStore().departments.length;

    final int availableDoctors = doctors.where((d) => d.status == "Available").length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Dashboard",
                      style: AppTypography.title,
                    ),
                     const Spacer(), 
    const LiveDateTimeWidget(),
                  ],
                ),
                const SizedBox(height: 6),
                Text("A quick snapshot of today’s hospital queue, patients, doctors, and overall activity.",
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 25),

                // Top row: two gradient highlight cards (waiting/served) +
                // a 2x2 grid of smaller stat cards on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoundedCard(
                      width: 275,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 200, 158, 223),
                          Color(0xFF5FA6A8),
                          Color.fromARGB(255, 24, 152, 152),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconCircle(
                            icon: Icons.groups_outlined,
                            iconSize: 25,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Patients Waiting",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            "$patientsWaiting",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 25),

                    RoundedCard(
                      width: 275,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 200, 183, 211),
                          Color.fromARGB(255, 138, 97, 169),
                          Color.fromARGB(255, 27, 113, 193),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconCircle(icon: Icons.check, iconSize: 25),
                          const SizedBox(height: 16),
                          Text(
                            "Patients Served",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            "$patientsServed",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 25),

                    // 2x2 grid: in consultation, total patients, departments, available doctors
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.person_2_outlined,
                                  iconColor: AppColors.primary,
                                  iconBgColor: Colors.deepPurple.shade50,
                                  label: "In Consultation",
                                  value: "$inConsultation",
                                ),
                              ),

                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.groups_3_rounded,
                                  iconColor: AppColors.primary,
                                  iconBgColor: Colors.deepPurple.shade50,
                                  label: "Total Patients",
                                  value: "$totalPatients",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.apartment_outlined,
                                  iconColor: AppColors.primary,
                                  iconBgColor: const Color(0xFFE4D9F9),
                                  label: "Departments",
                                  value: "$totalDepartments",
                                ),
                              ),

                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.medical_services,
                                  iconColor: AppColors.primary,
                                  iconBgColor: Colors.deepPurple.shade50,
                                  label: "Available Doctors",
                                  value: "$availableDoctors",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Queue traffic line/bar chart + per-doctor donut chart
        // Queue traffic line/bar chart + per-doctor donut chart
Row(
  children: [
    RoundedCard(
      width: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Queue Traffic",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "Last 8 hours",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260, // fixed height — chart ko bounded space deta hai
            child: const QueueTrafficChart(),
          ),
        ],
      ),
    ),

    const SizedBox(width: 10),

    Expanded(
      child: RoundedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Patients per doctor",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Move over a slice to see the doctor and their patient count",
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            const DoctorPatientsDonutChart(),
          ],
        ),
      ),
    ),
  ],
),

const SizedBox(height: 10),

// Bottom row: live current queue
RoundedCard(child: CurrentQueue()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}