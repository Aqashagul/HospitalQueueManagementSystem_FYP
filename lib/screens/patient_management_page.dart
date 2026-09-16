import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/patient_model.dart';
import 'package:queue_management_system/widgets/generic_p.dart/appform_dialog.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/search_controller.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';


class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  String selectedDepartmentFilter = "Department";
  String selectedStatusFilter = "Status";

  // Handles text search across name, token, and phone number.
  late final GenericSearchController<PatientModel> patientSearch;

  @override
  void initState() {
    super.initState();
    patientSearch = GenericSearchController<PatientModel>(
      items: AppdataStore().patient,
      filterLogic: (p, q) =>
          p.name.toLowerCase().contains(q) ||
          p.token.toLowerCase().contains(q) ||
          p.phoneNumber.toLowerCase().contains(q),
    );
    // Rebuild whenever the search query or its results change.
    patientSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    patientSearch.dispose();
    super.dispose();
  }

  // Search results narrowed further by the selected department and status filters.
  // ignore: unused_element
  List<PatientModel> get _visiblePatients {
    return patientSearch.filteredItems.where((p) {
      final matchesDepartment = selectedDepartmentFilter == "Department" ||
          p.department == selectedDepartmentFilter;
      final matchesStatus = selectedStatusFilter == "Status" ||
          p.status.toLowerCase() == selectedStatusFilter.toLowerCase();
      return matchesDepartment && matchesStatus;
    }).toList();
  }

  // Opens the "Add New Patient" form. On submit, generates a queue token
  // for the assigned doctor and adds the patient with status "Waiting".
  void _openAddPatientDialog() {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Add New Patient",
        submitLabel: "Generate Token",
        fields: [
          const FormFieldConfig(
            key: "name",
            label: "Full Name",
            type: FieldType.text,
            hint: "e.g. Ahmed Khan",
            required: true,
          ),
          const FormFieldConfig(
            key: "age",
            label: "Age",
            type: FieldType.text,
            hint: "e.g. 28",
            required: true,
            halfWidth: true,
          ),
          const FormFieldConfig(
            key: "gender",
            label: "Gender",
            type: FieldType.dropdown,
            options: ["Male", "Female", "Other"],
            halfWidth: true,
          ),
          const FormFieldConfig(
            key: "phone",
            label: "Phone Number",
            type: FieldType.text,
            hint: "e.g. 0300-1234567",
            required: true,
          ),
          FormFieldConfig(
            key: "department",
            label: "Department",
            type: FieldType.dropdown,
            required: true,
            // Pulled live from the store, so new departments show up automatically.
            options: AppdataStore().departments
                .map((d) => d.name)
                .toList(),
          ),
         FormFieldConfig(
  key: "doctor",
  label: "Assign Doctor",
  type: FieldType.dropdown,
  required: true,
  emptyOptionsMessage: "No doctors available in this department", 
  dependentOptions: (currentValues) {
    final selectedDepartment = currentValues["department"];
    return AppdataStore().doctors
        .where((d) => d.department == selectedDepartment)
        .map((d) => d.name)
        .toList();
  },
),
          const FormFieldConfig(
            key: "reason",
            label: "Reason for Visit",
            type: FieldType.textArea,
            hint: "Brief reason...",
          ),
        ],
        onSubmit: (values) {
          setState(() {
            AppdataStore().patient.insert(0,
              PatientModel(
                // Token is generated per-doctor so numbering stays scoped
                // to that doctor's queue.
                token: AppdataStore().generateTokenForDoctor(
                  values["doctor"],
                ),
                name: values["name"],
                department: values["department"],
                doctor: values["doctor"],
                phoneNumber: values["phone"],
                status: "Waiting",
                registrationTime: DateTime.now(),
              ),
            );
          });
        },
      ),
    );
  }

  // Opens the "Edit Patient" form pre-filled with the given patient's data.
  // Token, status, and registration time are preserved as-is — this form
  // only edits identity/assignment fields.
  void _openEditPatientDialog(PatientModel patient) {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Edit Patient",
        submitLabel: "Save Changes",
        initialValues: {
          "name": patient.name,
          "phone": patient.phoneNumber,
          "department": patient.department,
          "doctor": patient.doctor,
        },
        fields: [
          const FormFieldConfig(key: "name",
           label: "Full Name",
            type: FieldType.text, 
            required: true
            ),
          const FormFieldConfig(key: "phone", label: "Phone Number", type: FieldType.text, required: true),
          FormFieldConfig(
            key: "department",
            label: "Department",
            type: FieldType.dropdown,
            required: true,
            options: AppdataStore().departments.map((d) => d.name).toList(),
          ),
          FormFieldConfig(
            key: "doctor",
            label: "Assign Doctor",
            type: FieldType.dropdown,
            required: true,
            dependentOptions: (currentValues) {
              final selectedDept = currentValues["department"];
              return AppdataStore().doctors.where((d) => d.department == selectedDept).map((d) => d.name).toList();
            },
          ),
        ],
        onSubmit: (values) {
          setState(() {
            final index = AppdataStore().patient.indexOf(patient);
            if (index == -1) return;

            AppdataStore().patient[index] = PatientModel(
              token: patient.token, 
              name: values["name"],
              department: values["department"],
              doctor: values["doctor"],
              phoneNumber: values["phone"],
              status: patient.status, 
              registrationTime: patient.registrationTime, 
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PatientModel> allPatients = AppdataStore().patient;

    // Sort by registration time — most recently registered first.
    List<PatientModel> patients = List<PatientModel>.from(allPatients)
      ..sort((a, b) => b.registrationTime.compareTo(a.registrationTime));

    // Apply department filter.
    if (selectedDepartmentFilter != "Department") {
      patients = patients.where((p) => p.department == selectedDepartmentFilter).toList();
    }

    // Apply status filter.
    if (selectedStatusFilter != "Status") {
      patients = patients
          .where((p) => p.status.toLowerCase() == selectedStatusFilter.toLowerCase())
          .toList();
    }

    // Intersect with the current search query — matched by token, since
    // that's unique per patient (unlike name, which can repeat).
    final searchedTokens = patientSearch.filteredItems.map((p) => p.token).toSet();
    patients = patients.where((p) => searchedTokens.contains(p.token)).toList();

    final int totalPatients = allPatients.length;
    final int waitingCount =
        allPatients.where((p) => p.status.toLowerCase() == "waiting").length;
    final int inConsultationCount =
        allPatients.where((p) => p.status.toLowerCase() == "in consultation").length;
    final int completedCount =
        allPatients.where((p) => p.status.toLowerCase() == "completed").length;

    final departmentOptions = [
      "Department",
      ...AppdataStore().departments.map((d) => d.name),
    ];

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
                          Text("Patient Management", style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "View, search, and manage patient records and their queue status.",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 15),


                       // Search bar, department/status filters, and add-patient button
                    _buildToolbar(isMobile: isMobile, departmentOptions: departmentOptions),
                    const SizedBox(height: 24),

                    // Summary stat cards: total, waiting, in consultation, completed
                    // — always computed from the full unfiltered list.
                    _buildStatCardsSection(
                      isMobile: isMobile,
                      totalPatients: totalPatients,
                      waitingCount: waitingCount,
                      inConsultationCount: inConsultationCount,
                      completedCount: completedCount,
                    ),
                    const SizedBox(height: 24),

                   

                    // Patient records table
                    _buildTable(patients, isMobile: isMobile),

                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Secondary entry point for adding a patient 
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openAddPatientDialog();
        },
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
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
    final cardPadding = isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
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

  // Search bar + filters + add button
  Widget _buildToolbar({
    required bool isMobile,
    required List<String> departmentOptions,
  }) {
    final searchBar = DashboardSearchBar(
      hintText: "Search patient...",
      onChanged: (query) => patientSearch.search(query),
    );

    final addButton = ElevatedButton.icon(
      onPressed: () {
        _openAddPatientDialog();
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add Patient"),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (isMobile) {
      // fillWidth: true — these sit inside Expanded(), so isExpanded is safe here.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: selectedDepartmentFilter,
                  items: departmentOptions,
                  onChanged: (value) => setState(() => selectedDepartmentFilter = value!),
                  fillWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  value: selectedStatusFilter,
                  items: const ["Status", "Waiting", "In Consultation", "Completed"],
                  onChanged: (value) => setState(() => selectedStatusFilter = value!),
                  fillWidth: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: addButton),
        ],
      );
    }

    // fillWidth: false (default) — these sit directly in a Row without
    // Expanded, so they must size to their content, not try to fill infinite width.
    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedDepartmentFilter,
          items: departmentOptions,
          onChanged: (value) => setState(() => selectedDepartmentFilter = value!),
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedStatusFilter,
          items: const ["Status", "Waiting", "In Consultation", "Completed"],
          onChanged: (value) => setState(() => selectedStatusFilter = value!),
        ),
        const SizedBox(width: 12),
        addButton,
      ],
    );
  }

  
  Widget _buildTable(List<PatientModel> patients, {required bool isMobile}) {
    final table = DataTableCard<PatientModel>(
      items: patients,
      emptyMessage: "No patients match the selected filters",
      columns: [
        TableColumn<PatientModel>(
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
        TableColumn<PatientModel>(
          label: "Patient",
          flex: 2,
          cellBuilder: (p) => Text(
            p.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TableColumn<PatientModel>(
          label: "Department",
          flex: 2,
          cellBuilder: (p) => Text(
            p.department,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TableColumn<PatientModel>(
          label: "Doctor",
          flex: 2,
          cellBuilder: (p) =>
              Text(p.doctor, style: const TextStyle(fontSize: 14)),
        ),
        TableColumn<PatientModel>(
          label: "Phone",
          flex: 2,
          cellBuilder: (p) => Text(
            p.phoneNumber,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        TableColumn<PatientModel>(
          label: "Status",
          flex: 2,
          cellBuilder: (p) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(status: p.status),
          ),
        ),
        TableColumn<PatientModel>(
          label: "Actions",
          flex: 2,
          cellBuilder: (p) => Row(
            children: [
              // Edit patient
              GestureDetector(
                onTap: () => _openEditPatientDialog(p),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 14),
              // Remove patient record — no confirmation dialog currently
              GestureDetector(
                onTap: () {
                  setState(() {
                    AppdataStore().patient.remove(p);
                  });
                },
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.redAccent,
                ),
              ),
            ],
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
        border: Border.all(color: const Color.fromARGB(255, 196, 196, 196), width: 0.5),
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