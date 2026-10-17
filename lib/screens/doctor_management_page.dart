import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/screens/queue_admin_service.dart';
import 'package:queue_management_system/widgets/doctor_image.dart';
import 'package:queue_management_system/widgets/generic_p.dart/appform_dialog.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/search_controller.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/generic_p.dart/view_detail_doctor_dialog.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';
import 'dart:async';


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

  // Today's queue entries of ALL doctors, live from Firestore. The
  // "Patients" column and the "Free" card are worked out from these.
  final QueueAdminService _queueService = QueueAdminService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _entriesSub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _todayEntries = [];

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
    // Refresh when Firestore data arrives or changes in the store.
    AppdataStore().addListener(_onStoreChanged);

    // Live queue data for the Patients column.
    _entriesSub = _queueService.watchTodaysEntries().listen(
      (snap) {
        if (!mounted) return;
        setState(() => _todayEntries = snap.docs);
      },
      onError: (Object e) {
        _showErrorSnack(_friendlyError(e));
      },
    );
  }

  // Called whenever the store notifies (e.g. a Firestore snapshot arrived).
  void _onStoreChanged() {
    if (!mounted) return;
    doctorSearch.updateItems(AppdataStore().doctors);
    setState(() {});
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    AppdataStore().removeListener(_onStoreChanged);
    doctorSearch.dispose();
    super.dispose();
  }

  // Turns an exception into a short, readable message for the user.
  String _friendlyError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return "You don't have permission to do this.";
        case 'unavailable':
        case 'network-request-failed':
        case 'deadline-exceeded':
          return "Network problem. Please check your internet and try again.";
      }
    }
    return "Something went wrong. Please try again.";
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
        ),
      );
  }

  void _showNoDepartmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("No Department Found"),
        content: const Text("Please add a department first."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Deletes a doctor only if they have no patients waiting or in
  // consultation. Otherwise shows a dialog explaining why it's blocked.
  // Network / permission failures show a snackbar instead of failing silently.
  // Today's key like "20261014", same format the patient app writes.
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  bool _isActiveStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'waiting':
      case 'in consultation':
      case 'in-progress':
      case 'in progress':
        return true;
      default:
        return false;
    }
  }

  // Counts today's Waiting / In Consultation patients for this doctor
  // straight from Firestore (queue_entries). Reads from the server, so if
  // the network is down it throws instead of silently returning 0.
  Future<int> _firestoreActivePatients(String doctorId) async {
    final snap = await FirebaseFirestore.instance
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', isEqualTo: _todayKey())
        .get(const GetOptions(source: Source.server));
    return snap.docs
        .where((d) => _isActiveStatus(d.data()['status']?.toString()))
        .length;
  }

  Future<void> _deleteDoctor(DoctorModel doc) async {
    int activePatients;
    try {
      activePatients = await _firestoreActivePatients(doc.id.toString());
    } catch (e) {
      _showErrorSnack(_friendlyError(e));
      return;
    }
    if (!mounted) return;

    if (activePatients > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Cannot Delete Doctor"),
          content: Text(
            "${doc.name} currently has $activePatients "
            "${activePatients == 1 ? 'patient' : 'patients'} "
            "(Waiting or In Consultation), so this doctor cannot be deleted. "
            "Please wait until the queue is clear.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await AppdataStore().removeDoctor(doc);
    } catch (e) {
      _showErrorSnack(_friendlyError(e));
    }
  }

  // Opens the "Add New Doctor" form and saves the doctor to Firestore on
  // submit. The list refreshes automatically via the listener.
  void _openAddDoctorDialog() {
    if (AppdataStore().departments.isEmpty) {
      _showNoDepartmentDialog();
      return;
    }
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
          const FormFieldConfig(key: "fee", label: "Doctor Fee", type: FieldType.text, hint: "e.g. 1500", isNumeric: true),
          const FormFieldConfig(key: "experience", label: "Experience", type: FieldType.text, hint: "e.g. 12 Years", halfWidth: true),
          const FormFieldConfig(key: "workingHours", label: "Working Hours", type: FieldType.text, hint: "e.g. 9:00 AM - 5:00 PM", halfWidth: true),
          const FormFieldConfig(key: "qualification", label: "Qualification", type: FieldType.text, hint: "e.g. MBBS, FCPS"),
          const FormFieldConfig(key: "tokenPrefix", label: "Token Prefix", type: FieldType.text, hint: "e.g. CD (leave blank for auto)"),
          const FormFieldConfig(key: "availability", label: "Availability", type: FieldType.pillSelector, options: ["Available", "Unavailable"]),
        ],
        onSubmit: (values) {
          AppdataStore().addDoctor(
            DoctorModel(
              name: values["name"],
              specialization: values["specialization"],
              department: values["department"],
              patientsCount: 0,
              status: values["availability"],
              // NOTE: uploaded photos are not saved to Firestore yet.
              photoBytes: values["photo"],
              experience: values["experience"],
              workingHours: values["workingHours"],
              qualification: values["qualification"],
              tokenPrefix: values["tokenPrefix"],
              fee: int.tryParse(values["fee"]?.toString() ?? "") ?? 0,
            ),
          );
        },
      ),
    );
  }

  // Opens the "Edit Doctor" form pre-filled with the given doctor's data.
  // Updates the same Firestore document (matched by id).
  void _openEditDoctorDialog(DoctorModel doc) {
    if (AppdataStore().departments.isEmpty) {
      _showNoDepartmentDialog();
      return;
    }
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
          "fee": doc.fee.toString(),
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
          const FormFieldConfig(key: "fee", label: "Doctor Fee", type: FieldType.text, hint: "e.g. 1500", isNumeric: true),
        ],
        onSubmit: (values) {
          AppdataStore().updateDoctor(
            DoctorModel(
              id: doc.id, // tells Firestore which document to update
              name: values["name"],
              specialization: values["specialization"],
              department: values["department"],
              patientsCount: doc.patientsCount,
              status: values["availability"],
              photoBytes: values["photo"],
              photoAssetPath: doc.photoAssetPath, // preserved
              experience: values["experience"],
              workingHours: values["workingHours"],
              qualification: values["qualification"],
              tokenPrefix: values["tokenPrefix"],
              fee: int.tryParse(values["fee"]?.toString() ?? "") ?? doc.fee,
            ),
          );
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
            label: "Fee",
            value: "Rs. ${doc.fee}",
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFF6FCF97),
          ),
          DetailRow(
            label: "Patients (in queue)",
            value: "${_activePatientsCount(doc.id)}",
            icon: Icons.people_outline,
            iconColor: const Color(0xFF6FCF97),
          ),
          DetailRow(
            label: "Completed Today",
            value: "${_completedTodayCount(doc.id)}",
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF2E7D32),
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
  // waiting or in consultation, counted from today's live queue entries.
  int _activePatientsCount(String? doctorId) {
    if (doctorId == null) return 0;
    return _todayEntries.where((d) {
      final data = d.data();
      return data['doctorId'] == doctorId &&
          _isActiveStatus(data['status']?.toString());
    }).length;
  }

  // Number of patients this doctor has finished seeing today.
  int _completedTodayCount(String? doctorId) {
    if (doctorId == null) return 0;
    return _todayEntries.where((d) {
      final data = d.data();
      return data['doctorId'] == doctorId &&
          QueueAdminService.normalizeStatus(data['status']?.toString()) ==
              'Completed';
    }).length;
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
        allDoctors.where((d) => _activePatientsCount(d.id) == 0).length;

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
    filteredDoctors =
        filteredDoctors.where((d) => searchedNames.contains(d.name)).toList();

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
                          Text("Doctor Management", style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Manage doctors, assign departments, monitor availability, and maintain doctor records.",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 15),

                    // Search bar, department/availability filters, add-doctor button
                    _buildToolbar(isMobile: isMobile),
                    const SizedBox(height: 24),

                    // Summary stat cards: total, available, unavailable, free
                    _buildStatCardsSection(
                      isMobile: isMobile,
                      totalDoctors: totalDoctors,
                      availableCount: availableCount,
                      unavailableCount: unavailableCount,
                      freeCount: freeCount,
                    ),
                    const SizedBox(height: 24),

                    // Doctor records table
                    _buildTable(filteredDoctors, isMobile: isMobile),

                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Secondary entry point for adding a doctor
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDoctorDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 4 stat cards
  Widget _buildStatCardsSection({
    required bool isMobile,
    required int totalDoctors,
    required int availableCount,
    required int unavailableCount,
    required int freeCount,
  }) {
    final cardPadding = isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
    final cardIconPadding = isMobile ? 8.0 : 12.0;
    final cardIconSize = isMobile ? 18.0 : 22.0;
    final cardValueFontSize = isMobile ? 18.0 : 22.0;

    final card1 = StatCard(
      icon: Icons.groups_outlined,
      iconColor: AppColors.primaryPurple,
      iconBgColor: const Color(0xFFE4D9F9),
      label: "Total Doctors",
      value: "$totalDoctors",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card2 = StatCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: "Available Doctors",
      value: "$availableCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card3 = StatCard(
      icon: Icons.work_outline,
      iconColor: const Color(0xFFB8860B),
      iconBgColor: const Color(0xFFFAF3D0),
      label: "Unavailable",
      value: "$unavailableCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card4 = StatCard(
      icon: Icons.event_available_outlined,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: "Free",
      value: "$freeCount",
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
  Widget _buildToolbar({required bool isMobile}) {
    final searchBar = DashboardSearchBar(
      hintText: "Search doctor...",
      onChanged: (query) => doctorSearch.search(query),
    );

    final addButton = ElevatedButton.icon(
      onPressed: _openAddDoctorDialog,
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add Doctor"),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (isMobile) {
      // fillWidth: true, because these sit inside Expanded().
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
                  items: [
                    "Department",
                    ...AppdataStore().departments.map((d) => d.name),
                  ],
                  onChanged: (value) => setState(() => selectedDepartmentFilter = value!),
                  fillWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  value: selectedAvailabilityFilter,
                  items: const ["Availability", "Available", "Unavailable"],
                  onChanged: (value) => setState(() => selectedAvailabilityFilter = value!),
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

    // fillWidth: false (default), because these sit directly in a Row without
    // Expanded, so they must size to their content.
    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedDepartmentFilter,
          items: [
            "Department",
            ...AppdataStore().departments.map((d) => d.name),
          ],
          onChanged: (value) => setState(() => selectedDepartmentFilter = value!),
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedAvailabilityFilter,
          items: const ["Availability", "Available", "Unavailable"],
          onChanged: (value) => setState(() => selectedAvailabilityFilter = value!),
        ),
        const SizedBox(width: 12),
        addButton,
      ],
    );
  }

  Widget _buildTable(List<DoctorModel> filteredDoctors, {required bool isMobile}) {
    final table = DataTableCard<DoctorModel>(
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
          cellBuilder: (doc) => Text(
            "${_activePatientsCount(doc.id)}",
            style: const TextStyle(fontSize: 14),
          ),
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
              // Delete doctor from Firestore. Blocked (with a dialog) if the
              // doctor has Waiting / In Consultation patients; errors show a
              // snackbar. The list refreshes automatically via the listener.
              GestureDetector(
                onTap: () => _deleteDoctor(doc),
                child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    );

    if (!isMobile) return table;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 900, child: table),
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