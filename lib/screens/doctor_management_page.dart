import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/widgets/doctor_image.dart';
import 'package:queue_management_system/widgets/generic_p.dart/appform_dialog.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/search_controller.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/generic_p.dart/view_detail_doctor_dialog.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';


class DoctorManagementPage extends StatefulWidget {
  const DoctorManagementPage({super.key});

  @override
  State<DoctorManagementPage> createState() => _DoctorManagementPageState();
}

class _DoctorManagementPageState extends State<DoctorManagementPage> {
  String selectedDepartmentFilter = "Department";
  String selectedAvailabilityFilter = "Availability";

  // Handles text search across doctor name, department, and specialization.
  late final GenericSearchController<DoctorModel> doctorSearch;

  @override
  void initState() {
    super.initState();
    doctorSearch = GenericSearchController<DoctorModel>(
      items: AppdataStore().doctors,
      filterLogic: (doc, q) =>
          doc.name.toLowerCase().contains(q) ||
          doc.department.toLowerCase().contains(q) ||
          doc.specialization.toLowerCase().contains(q),
    );
    // Rebuild whenever the search query or its results change.
    doctorSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    doctorSearch.dispose();
    super.dispose();
  }

  // Opens the "Add New Doctor" form and appends the new doctor to the store on submit.
  void _openAddDoctorDialog() {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Add New Doctor",
        submitLabel: "Add Doctor",
        fields: [
          const FormFieldConfig(key: "photo", label: "Doctor Photo", type: FieldType.image),
          const FormFieldConfig(key: "name", label: "Full Name", type: FieldType.text, hint: "e.g. Dr. Sarah Ahmed", required: true),
          const FormFieldConfig(key: "specialization", label: "Specialization", type: FieldType.text, hint: "e.g. Cardiology", required: true),
          FormFieldConfig(
            key: "department",
            label: "Department",
            type: FieldType.dropdown,
            required: true,
            options: AppdataStore().departments.map((d) => d.name).toList(),
          ),
          const FormFieldConfig(key: "experience", label: "Experience", type: FieldType.text, hint: "e.g. 12 Years", halfWidth: true),
          const FormFieldConfig(key: "workingHours", label: "Working Hours", type: FieldType.text, hint: "e.g. 9:00 AM - 5:00 PM", halfWidth: true),
          const FormFieldConfig(key: "qualification", label: "Qualification", type: FieldType.text, hint: "e.g. MBBS, FCPS"),
          const FormFieldConfig(key: "tokenPrefix", label: "Token Prefix", type: FieldType.text, hint: "e.g. CD (leave blank for auto)"),
          const FormFieldConfig(key: "availability", label: "Availability", type: FieldType.pillSelector, options: ["Available", "Unavailable"]),
        ],
        onSubmit: (values) {
          setState(() {
            AppdataStore().doctors.insert(0,DoctorModel(
              name: values["name"],
              specialization: values["specialization"],
              department: values["department"],
              patientsCount: 0,
              status: values["availability"],
              photoBytes: values["photo"],
              experience: values["experience"],
              workingHours: values["workingHours"],
              qualification: values["qualification"],
              tokenPrefix: values["tokenPrefix"],
            ));
            // Keep the search controller's source list in sync with the new doctor.
            doctorSearch.updateItems(AppdataStore().doctors);
          });
        },
      ),
    );
  }

  // Opens the "Edit Doctor" form pre-filled with the given doctor's data.
  // patientsCount is preserved as-is since it's not an editable field here.
  void _openEditDoctorDialog(DoctorModel doc) {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Edit Doctor",
        submitLabel: "Save Changes",
        initialValues: {
          "name": doc.name,
          "specialization": doc.specialization,
          "department": doc.department,
          "availability": doc.status,
          "photo": doc.photoBytes,
          "experience": doc.experience,
          "workingHours": doc.workingHours,
          "qualification": doc.qualification,
          "tokenPrefix": doc.tokenPrefix,
        },
        fields: [
          const FormFieldConfig(key: "photo", label: "Doctor Photo", type: FieldType.image),
          const FormFieldConfig(key: "name", label: "Full Name", type: FieldType.text, required: true),
          const FormFieldConfig(key: "specialization", label: "Specialization", type: FieldType.text, required: true),
          FormFieldConfig(
            key: "department",
            label: "Department",
            type: FieldType.dropdown,
            required: true,
            options: AppdataStore().departments.map((d) => d.name).toList(),
          ),
          const FormFieldConfig(key: "experience", label: "Experience", type: FieldType.text, hint: "e.g. 12 Years", halfWidth: true),
          const FormFieldConfig(key: "workingHours", label: "Working Hours", type: FieldType.text, hint: "e.g. 9:00 AM - 5:00 PM", halfWidth: true),
          const FormFieldConfig(key: "qualification", label: "Qualification", type: FieldType.text, hint: "e.g. MBBS, FCPS"),
          const FormFieldConfig(key: "tokenPrefix", label: "Token Prefix", type: FieldType.text, hint: "e.g. CD (leave blank for auto)"),
          const FormFieldConfig(key: "availability", label: "Availability", type: FieldType.pillSelector, options: ["Available", "Unavailable"]),
        ],
        onSubmit: (values) {
          setState(() {
            final index = AppdataStore().doctors.indexOf(doc);
            if (index == -1) return;

            AppdataStore().doctors[index] = DoctorModel(
              name: values["name"],
              specialization: values["specialization"],
              department: values["department"],
              patientsCount: doc.patientsCount, // preserved — not editable from this form
              status: values["availability"],
              photoBytes: values["photo"],
              experience: values["experience"],
              workingHours: values["workingHours"],
              qualification: values["qualification"],
              tokenPrefix: values["tokenPrefix"],
            );
            doctorSearch.updateItems(AppdataStore().doctors);
          });
        },
      ),
    );
  }

  // Opens a read-only detail dialog for the given doctor.
  void _openViewDoctorDialog(DoctorModel doc) {
    showDialog(
      context: context,
      builder: (_) => ViewDetailsDialog(
        headerName: doc.name,
        headerSubtitle: doc.specialization,
        headerBadge: StatusPill(status: doc.status),
        doctor: doc,
        rows: [
          DetailRow(
            label: "Department",
            value: doc.department,
            icon: Icons.apartment_outlined,
            iconColor: const Color(0xFF56CCF2),
          ),
          DetailRow(
            label: "Patients",
            value: "${_activePatientsCount(doc.name)}",
            icon: Icons.people_outline,
            iconColor: const Color(0xFF6FCF97),
          ),
          DetailRow(
            label: "Specialization",
            value: doc.specialization,
            icon: Icons.medical_services_outlined,
            iconColor: AppColors.primaryPurple,
          ),
          DetailRow(
            label: "Availability",
            value: doc.status,
            icon: Icons.event_available_outlined,
            iconColor: const Color(0xFFF2994A),
          ),
          // Optional fields fall back to an em dash when not set.
          DetailRow(
            label: "Experience",
            value: doc.experience?.isNotEmpty == true ? doc.experience! : "—",
            icon: Icons.work_history_outlined,
            iconColor: const Color(0xFF9B59B6),
          ),
          DetailRow(
            label: "Working Hours",
            value: doc.workingHours?.isNotEmpty == true ? doc.workingHours! : "—",
            icon: Icons.access_time_outlined,
            iconColor: const Color(0xFF3B82C4),
          ),
          DetailRow(
            label: "Qualification",
            value: doc.qualification?.isNotEmpty == true ? doc.qualification! : "—",
            icon: Icons.school_outlined,
            iconColor: const Color(0xFFB8860B),
          ),
          DetailRow(
            label: "Token Prefix",
            value: doc.tokenPrefix?.isNotEmpty == true ? doc.tokenPrefix! : "—",
            icon: Icons.confirmation_number_outlined,
            iconColor: const Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  // Number of patients currently assigned to this doctor who are either
  // waiting or in consultation (i.e. still occupying their queue).
  int _activePatientsCount(String doctorName) {
    return AppdataStore().patient
        .where((p) =>
            p.doctor == doctorName &&
            (p.status == "Waiting" || p.status == "In Consultation"))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final List<DoctorModel> allDoctors = AppdataStore().doctors;

    final int totalDoctors = allDoctors.length;
    final int availableCount =
        allDoctors.where((d) => d.status.toLowerCase() == "available").length;
    final int unavailableCount =
        allDoctors.where((d) => d.status.toLowerCase() == "unavailable").length;

    // "Free" = has no active patients right now, regardless of availability status.
    final int freeCount =
        allDoctors.where((d) => _activePatientsCount(d.name) == 0).length;

    // Apply department filter first...
    List<DoctorModel> filteredDoctors = selectedDepartmentFilter == "Department"
        ? List<DoctorModel>.from(allDoctors)
        : allDoctors.where((d) => d.department == selectedDepartmentFilter).toList();

    // ...then availability filter...
    if (selectedAvailabilityFilter != "Availability") {
      filteredDoctors = filteredDoctors
          .where((d) =>
              d.status.toLowerCase() == selectedAvailabilityFilter.toLowerCase())
          .toList();
    }

    // ...then intersect with the current search results.
    final searchedNames = doctorSearch.filteredItems.map((d) => d.name).toSet();
    filteredDoctors = filteredDoctors.where((d) => searchedNames.contains(d.name)).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                Text("Doctor Management", style: AppTypography.title),
                 const Spacer(), 
    const LiveDateTimeWidget(),],),
                const SizedBox(height: 6),
                Text(
                  "Manage doctors, assign departments, monitor availability, and maintain doctor records.",
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 24),

                // Summary stat cards: total, available, unavailable, free
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.groups_outlined,
                        iconColor: AppColors.primaryPurple,
                        iconBgColor: const Color(0xFFE4D9F9),
                        label: "Total Doctors",
                        value: "$totalDoctors",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.check_circle_outline,
                        iconColor: const Color(0xFF2E7D32),
                        iconBgColor: const Color(0xFFD4EDDA),
                        label: "Available Doctors",
                        value: "$availableCount",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.work_outline,
                        iconColor: const Color(0xFFB8860B),
                        iconBgColor: const Color(0xFFFAF3D0),
                        label: "Unavailable",
                        value: "$unavailableCount",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.event_available_outlined,
                        iconColor: const Color(0xFF2E7D32),
                        iconBgColor: const Color(0xFFD4EDDA),
                        label: "Free",
                        value: "$freeCount",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search bar, department/availability filters, and add-doctor button
                Row(
                  children: [
                    Expanded(
                      child: DashboardSearchBar(
                        hintText: "Search doctor...",
                        onChanged: (query) => doctorSearch.search(query),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildDropdown(
                      value: selectedDepartmentFilter,
                      items: [
                        "Department",
                        ...AppdataStore().departments.map((d) => d.name),
                      ],
                      onChanged: (value) {
                        setState(() => selectedDepartmentFilter = value!);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildDropdown(
                      value: selectedAvailabilityFilter,
                      items: const ["Availability", "Available", "Unavailable"],
                      onChanged: (value) {
                        setState(() => selectedAvailabilityFilter = value!);
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAddDoctorDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Doctor"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Doctor records table
                DataTableCard<DoctorModel>(
                  items: filteredDoctors,
                  emptyMessage: "No doctors added yet",
                  columns: [
                    TableColumn<DoctorModel>(
                      label: "Doctor",
                      flex: 3,
                      cellBuilder: (doc) => Row(
                        children: [
                          DoctorAvatar(doctor: doc),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              doc.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TableColumn<DoctorModel>(
                      label: "Specialization",
                      flex: 2,
                      cellBuilder: (doc) =>
                          Text(doc.specialization, style: const TextStyle(fontSize: 14)),
                    ),
                    TableColumn<DoctorModel>(
                      label: "Department",
                      flex: 2,
                      cellBuilder: (doc) =>
                          Text(doc.department, style: const TextStyle(fontSize: 14)),
                    ),
                    TableColumn<DoctorModel>(
                      label: "Patients",
                      flex: 1,
                      cellBuilder: (doc) =>
                          Text("${_activePatientsCount(doc.name)}", style: const TextStyle(fontSize: 14)),
                    ),
                    TableColumn<DoctorModel>(
                      label: "Availability",
                      flex: 2,
                      cellBuilder: (doc) => Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(status: doc.status),
                      ),
                    ),
                    TableColumn<DoctorModel>(
                      label: "Actions",
                      flex: 2,
                      cellBuilder: (doc) => Row(
                        children: [
                          // View details
                          GestureDetector(
                            onTap: () => _openViewDoctorDialog(doc),
                            child: Icon(Icons.visibility_outlined, size: 18, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 14),
                          // Edit doctor
                          GestureDetector(
                            onTap: () => _openEditDoctorDialog(doc),
                            child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 14),
                          // Remove doctor record — no confirmation dialog currently
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                AppdataStore().doctors.remove(doc);
                                doctorSearch.updateItems(AppdataStore().doctors);
                              });
                            },
                            child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      // Secondary entry point for adding a doctor (mirrors the "Add Doctor" button above).
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDoctorDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: AppTypography.normaltext),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}