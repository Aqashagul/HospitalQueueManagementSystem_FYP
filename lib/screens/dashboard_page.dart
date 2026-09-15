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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 700;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
               
                    if (!isMobile) ...[
                      Row(
                        children: [
                          Text("Dashboard", style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "A quick snapshot of today's hospital queue, patients, doctors, and overall activity.",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 25),
                    ] else
                      const SizedBox(height: 15),

                    // Top stats section
                    _buildStatsSection(
                      isMobile: isMobile,
                      patientsWaiting: patientsWaiting,
                      patientsServed: patientsServed,
                      inConsultation: inConsultation,
                      totalPatients: totalPatients,
                      totalDepartments: totalDepartments,
                      availableDoctors: availableDoctors,
                    ),

                    const SizedBox(height: 15),

                    isMobile
                        ? Column(
                            children: [
                              RoundedCard(
                                color: Colors.white,
                                width: double.infinity,
                                child: _queueTrafficContent(),
                              ),
                              const SizedBox(height: 10),
                              RoundedCard(
                                color: Colors.white,
                                width: double.infinity,
                                child: _donutContent(),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              RoundedCard(
                                color: Colors.white,
                                width: 680,
                                child: _queueTrafficContent(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RoundedCard(
                                  color: Colors.white,
                                  child: _donutContent(),
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 10),
                    RoundedCard(child: CurrentQueue()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatsSection({
    required bool isMobile,
    required int patientsWaiting,
    required int patientsServed,
    required int inConsultation,
    required int totalPatients,
    required int totalDepartments,
    required int availableDoctors,
  }) {
    final gradientCard1 = RoundedCard(
      width: isMobile ? null : 275,
      padding: isMobile ? const EdgeInsets.all(14) : const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB(255, 200, 158, 223),
          Color(0xFF5FA6A8),
          Color.fromARGB(255, 24, 152, 152),
        ],
      ),
      child: _gradientCardContent(
        icon: Icons.groups_outlined,
        label: "Patients Waiting",
        value: "$patientsWaiting",
        isMobile: isMobile,
      ),
    );

    final gradientCard2 = RoundedCard(
      width: isMobile ? null : 275,
      padding: isMobile ? const EdgeInsets.all(14) : const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB(255, 200, 183, 211),
          Color.fromARGB(255, 138, 97, 169),
          Color.fromARGB(255, 27, 113, 193),
        ],
      ),
      child: _gradientCardContent(
        icon: Icons.check,
        label: "Patients Served",
        value: "$patientsServed",
        isMobile: isMobile,
      ),
    );

    final statGrid = Column(
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
                padding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18),
                iconContainerPadding: isMobile ? 8 : 12,
                iconSize: isMobile ? 18 : 22,
                valueFontSize: isMobile ? 18 : 22,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: StatCard(
                icon: Icons.groups_3_rounded,
                iconColor: AppColors.primary,
                iconBgColor: Colors.deepPurple.shade50,
                label: "Total Patients",
                value: "$totalPatients",
                padding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18),
                iconContainerPadding: isMobile ? 8 : 12,
                iconSize: isMobile ? 18 : 22,
                valueFontSize: isMobile ? 18 : 22,
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.apartment_outlined,
                iconColor: AppColors.primary,
                iconBgColor: const Color(0xFFE4D9F9),
                label: "Departments",
                value: "$totalDepartments",
                padding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18),
                iconContainerPadding: isMobile ? 8 : 12,
                iconSize: isMobile ? 18 : 22,
                valueFontSize: isMobile ? 18 : 22,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: StatCard(
                icon: Icons.medical_services,
                iconColor: AppColors.primary,
                iconBgColor: Colors.deepPurple.shade50,
                label: "Available Doctors",
                value: "$availableDoctors",
                padding: isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18),
                iconContainerPadding: isMobile ? 8 : 12,
                iconSize: isMobile ? 18 : 22,
                valueFontSize: isMobile ? 18 : 22,
              ),
            ),
          ],
        ),
      ],
    );

    
   if (isMobile) {
  return Row(
    children: [
      Expanded(child: gradientCard1),
      const SizedBox(width: 12),
      Expanded(child: gradientCard2),
    ],
  );
}

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gradientCard1,
        const SizedBox(width: 25),
        gradientCard2,
        const SizedBox(width: 25),
        Expanded(child: statGrid),
      ],
    );
  }

  Widget _gradientCardContent({
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconCircle(
          icon: icon,
          iconSize: isMobile ? 18 : 25,
          padding: isMobile ? 8 : 10,
        ),
        SizedBox(height: isMobile ? 10 : 16),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isMobile ? 12 : 15,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isMobile ? 5 : 9),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isMobile ? 24 : 34,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _queueTrafficContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Queue Traffic",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
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
        SizedBox(height: 260, child: const QueueTrafficChart()),
      ],
    );
  }

  Widget _donutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Patients per doctor",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(
          "Move over a slice to see the doctor and their patient count",
          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 12),
        const DoctorPatientsDonutChart(),
      ],
    );
  }
}