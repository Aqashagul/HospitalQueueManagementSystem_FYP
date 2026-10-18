import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';


/// Simple read-only view of one Firestore `queue_entries` document.
class _PatientRow {
  final String id;
  final String token; // e.g. "A-001"
  final String name;
  final String department;
  final String doctor;
  final String phone;
  final String status; // Waiting / In Consultation / Completed

  const _PatientRow({
    required this.id,
    required this.token,
    required this.name,
    required this.department,
    required this.doctor,
    required this.phone,
    required this.status,
  });

  factory _PatientRow.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    return _PatientRow(
      id: doc.id,
      token: (d['token'] ?? '-').toString(),
      name: (d['patientName'] ?? '-').toString(),
      department: (d['department'] ?? '-').toString(),
      doctor: (d['doctorName'] ?? '-').toString(),
      phone: (d['phone'] ?? '-').toString(),
      status: _statusLabel(d['status']?.toString()),
    );
  }

  // Maps any stored status text to one of the three labels shown in the UI.
  static String _statusLabel(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'in-progress':
      case 'in progress':
      case 'in consultation':
        return 'In Consultation';
      case 'done':
      case 'completed':
        return 'Completed';
      default:
        return 'Waiting';
    }
  }
}

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  String selectedStatusFilter = "Status";
  String _searchQuery = "";

  // All queue entries, newest first. A single orderBy needs no composite index.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _patientsStream =
      FirebaseFirestore.instance
          .collection('queue_entries')
          .orderBy('joinedAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _patientsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                );
              }

              final allPatients =
                  snapshot.data!.docs.map(_PatientRow.fromDoc).toList();

              // Status filter + search (name / token / phone / doctor / department)
              final query = _searchQuery.trim().toLowerCase();
              final patients = allPatients.where((p) {
                final matchesStatus = selectedStatusFilter == "Status" ||
                    p.status.toLowerCase() ==
                        selectedStatusFilter.toLowerCase();
                final matchesSearch = query.isEmpty ||
                    p.name.toLowerCase().contains(query) ||
                    p.token.toLowerCase().contains(query) ||
                    p.phone.toLowerCase().contains(query) ||
                    p.doctor.toLowerCase().contains(query) ||
                    p.department.toLowerCase().contains(query);
                return matchesStatus && matchesSearch;
              }).toList();

              final int totalPatients = allPatients.length;
              final int waitingCount =
                  allPatients.where((p) => p.status == "Waiting").length;
              final int inConsultationCount = allPatients
                  .where((p) => p.status == "In Consultation")
                  .length;
              final int completedCount =
                  allPatients.where((p) => p.status == "Completed").length;

              return SingleChildScrollView(
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
                              Text("Patient Management",
                                  style: AppTypography.title),
                              const Spacer(),
                              const LiveDateTimeWidget(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Patients who take a token appear here live.",
                            style: AppTypography.subtitle,
                          ),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 15),

                        _buildToolbar(isMobile: isMobile),
                        const SizedBox(height: 24),

                        _buildStatCardsSection(
                          isMobile: isMobile,
                          totalPatients: totalPatients,
                          waitingCount: waitingCount,
                          inConsultationCount: inConsultationCount,
                          completedCount: completedCount,
                        ),
                        const SizedBox(height: 24),

                        _buildTable(patients, isMobile: isMobile),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 4 stat cards
  Widget _buildStatCardsSection({
    required bool isMobile,
    required int totalPatients,
    required int waitingCount,
    required int inConsultationCount,
    required int completedCount,
  }) {
    final cardPadding =
        isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
    final cardIconPadding = isMobile ? 8.0 : 12.0;
    final cardIconSize = isMobile ? 18.0 : 22.0;
    final cardValueFontSize = isMobile ? 18.0 : 22.0;

    final card1 = StatCard(
      icon: Icons.people_outline,
      iconColor: AppColors.primaryPurple,
      iconBgColor: const Color(0xFFE4D9F9),
      label: "Total Patients",
      value: "$totalPatients",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card2 = StatCard(
      icon: Icons.hourglass_empty,
      iconColor: const Color(0xFFB8860B),
      iconBgColor: const Color(0xFFFAF3D0),
      label: "Waiting",
      value: "$waitingCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card3 = StatCard(
      icon: Icons.medical_information_outlined,
      iconColor: const Color(0xFF3B82C4),
      iconBgColor: const Color(0xFFD6EAF8),
      label: "In Consultation",
      value: "$inConsultationCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card4 = StatCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: "Completed",
      value: "$completedCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 8),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 8),
              Expanded(child: card4),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 16),
        Expanded(child: card2),
        const SizedBox(width: 16),
        Expanded(child: card3),
        const SizedBox(width: 16),
        Expanded(child: card4),
      ],
    );
  }

  // Search bar + status filter
  Widget _buildToolbar({required bool isMobile}) {
    final searchBar = DashboardSearchBar(
      hintText: "Search patient...",
      onChanged: (query) => setState(() => _searchQuery = query),
    );

    final statusDropdown = _buildDropdown(
      value: selectedStatusFilter,
      items: const ["Status", "Waiting", "In Consultation", "Completed"],
      onChanged: (value) => setState(() => selectedStatusFilter = value!),
      fillWidth: isMobile,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 12),
          statusDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 12),
        statusDropdown,
      ],
    );
  }

  // Read-only table: Token, Patient, Department, Doctor, Phone, Status.
  Widget _buildTable(List<_PatientRow> patients, {required bool isMobile}) {
    // No patients yet: show the empty-state picture instead of the table.
    if (patients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Image.asset(
            'assets/images/patients.png',
            width: isMobile ? 260 : 380,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final table = DataTableCard<_PatientRow>(
      items: patients,
      emptyMessage: "No patients found",
      columns: [
        TableColumn<_PatientRow>(
          label: "Token",
          flex: 2,
          cellBuilder: (p) => Text(
            p.token,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
        TableColumn<_PatientRow>(
          label: "Patient",
          flex: 3,
          cellBuilder: (p) => Text(
            p.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TableColumn<_PatientRow>(
          label: "Department",
          flex: 3,
          cellBuilder: (p) => Text(
            p.department,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TableColumn<_PatientRow>(
          label: "Doctor",
          flex: 3,
          cellBuilder: (p) => Text(
            p.doctor,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TableColumn<_PatientRow>(
          label: "Phone",
          flex: 3,
          cellBuilder: (p) => Text(
            p.phone,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        TableColumn<_PatientRow>(
          label: "Status",
          flex: 2,
          cellBuilder: (p) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(status: p.status),
          ),
        ),
      ],
    );

    if (!isMobile) return table;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 1000, child: table),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool fillWidth = false,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 196, 196, 196),
          width: 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: fillWidth,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: AppTypography.normaltext,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}