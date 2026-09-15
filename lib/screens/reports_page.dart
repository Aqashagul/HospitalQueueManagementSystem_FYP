import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/completed_vs_cancelled_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/doctor_overload_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/patients_by_department.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/peak_hour_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/weekly_patient_flow_chart.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';


class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Currently selected date-range filter. Not yet wired to actually
  // filter the data below — only affects the dropdown's displayed value.
  String selectedRange = "Last 7 Days";

  @override
  Widget build(BuildContext context) {
    // Pulls the full patient list from the shared in-memory store.
    // No backend/API call here — all stats are derived client-side.
    final patients = AppdataStore().patient;

    final int totalTokens = patients.length;
    final int completedCount =
        patients.where((p) => p.status.toLowerCase() == "completed").length;
    final int cancelledCount =
        patients.where((p) => p.status.toLowerCase() == "cancelled").length;

    // Hardcoded placeholder — not calculated from actual wait times yet.
    const avgWaitingMinutes = 8;

    final int completionPercent =
        totalTokens == 0 ? 0 : ((completedCount / totalTokens) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 700;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   
                    if (!isMobile) ...[
                      Row(
                        children: [
                          Text("Reports & Analytics", style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Analyze queue performance, patient flow, waiting times, and operational efficiency.",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 15),

                    // Date-range filter dropdown
                          _buildFilterDropdown(
                            icon: Icons.calendar_today_outlined,
                            value: selectedRange,
                            items: const ["Last 7 Days", "Last 30 Days", "This Month"],
                            onChanged: (v) => setState(() => selectedRange = v!),
                          ),
                        
                    const SizedBox(height: 20),

                    // Summary stat cards: total, completed, cancelled, avg wait, completion rate
                   if (!isMobile) ...[
  _buildStatCardsSection(
    isMobile: isMobile,
    totalTokens: totalTokens,
    completedCount: completedCount,
    cancelledCount: cancelledCount,
    avgWaitingMinutes: avgWaitingMinutes,
    completionPercent: completionPercent,
  ),
  const SizedBox(height: 28),
],

                    // Weekly patient flow chart (7-day trend)
                    RoundedCard(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SevenDayPatientsChart(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Peak hour + department distribution charts —
                    // desktop: side by side. Mobile: stacked full-width.
                    isMobile
                        ? Column(
                            children: [
                              RoundedCard(
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Peak Hour Patient Count",
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 16),
                                    const PeakHourChart(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              RoundedCard(
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Patients by Department",
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 16),
                                    const PatientsByDepartmentChart(),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: RoundedCard(
                                  color: Colors.white,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Peak Hour Patient Count",
                                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 16),
                                      const PeakHourChart(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: RoundedCard(
                                  color: Colors.white,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Patients by Department",
                                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 16),
                                      const PatientsByDepartmentChart(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),

                    // Completed vs cancelled comparison chart
                    RoundedCard(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Completed vs Cancelled Queues",
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          const CompletedVsCancelledChart(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Doctor workload breakdown chart
                    RoundedCard(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Doctor Workload",
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          const DoctorWorkloadChart(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5 stat cards 
  Widget _buildStatCardsSection({
    required bool isMobile,
    required int totalTokens,
    required int completedCount,
    required int cancelledCount,
    required int avgWaitingMinutes,
    required int completionPercent,
  }) {
    final card1 = StatCard(
      icon: Icons.confirmation_number_outlined,
      iconColor: AppColors.primaryPurple,
      iconBgColor: const Color(0xFFE4D9F9),
      label: "Total Tokens",
      value: "$totalTokens",
    );
    final card2 = StatCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: "Completed",
      value: "$completedCount",
    );
    final card3 = StatCard(
      icon: Icons.cancel_outlined,
      iconColor: const Color(0xFFC62828),
      iconBgColor: const Color(0xFFF8D7DA),
      label: "Cancelled",
      value: "$cancelledCount",
    );
    final card4 = StatCard(
      icon: Icons.hourglass_empty,
      iconColor: const Color(0xFFB8860B),
      iconBgColor: const Color(0xFFFAF3D0),
      label: "Avg Waiting",
      value: "$avgWaitingMinutes min",
    );
    final card5 = StatCard(
      icon: Icons.trending_up,
      iconColor: AppColors.primaryPurple,
      iconBgColor: const Color(0xFFE4D9F9),
      label: "Completion",
      value: "$completionPercent%",
    );

    if (isMobile) {
  return const SizedBox.shrink();
}

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 14),
        Expanded(child: card2),
        const SizedBox(width: 14),
        Expanded(child: card3),
        const SizedBox(width: 14),
        Expanded(child: card4),
        const SizedBox(width: 14),
        Expanded(child: card5),
      ],
    );
  }

  // Builds a bordered dropdown with a leading icon, used for the
  // date-range filter above the stat cards.
  Widget _buildFilterDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: items
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis, 
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}