import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/department_model.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/widgets/department_avatar.dart';
import 'package:queue_management_system/widgets/generic_p.dart/appform_dialog.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/search_controller.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';



class DepartmentManagementPage extends StatefulWidget {
  const DepartmentManagementPage({super.key});

  @override
  State<DepartmentManagementPage> createState() =>
      _DepartmentManagementPageState();
}

class _DepartmentManagementPageState extends State<DepartmentManagementPage> {
  String selectedStatusFilter = "All Status";
  String selectedSort = "Recently Added";

  // Handles text search across department name and head.
  late final GenericSearchController<Department> departmentSearch;

  @override
  void initState() {
    super.initState();
    departmentSearch = GenericSearchController<Department>(
      items: AppdataStore().departments,
      filterLogic: (dept, q) =>
          dept.name.toLowerCase().contains(q) ||
          dept.head.toLowerCase().contains(q),
    );
    // Rebuild whenever the search query or its results change.
    departmentSearch.addListener(() => setState(() {}));
    // Refresh when Firestore data arrives or changes in the store.
    AppdataStore().addListener(_onStoreChanged);
  }

  // Called whenever the store notifies (e.g. a Firestore snapshot arrived).
  void _onStoreChanged() {
    if (!mounted) return;
    departmentSearch.updateItems(AppdataStore().departments);
    setState(() {});
  }

  @override
  void dispose() {
    AppdataStore().removeListener(_onStoreChanged);
    departmentSearch.dispose();
    super.dispose();
  }

  // Returns today's date like "Oct 13, 2026".
  String _formatToday() {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    final now = DateTime.now();
    return "${months[now.month - 1]} ${now.day}, ${now.year}";
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

  // Counts today's Waiting / In Consultation patients for one doctor
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

  // Returns {doctor name: active patient count} for doctors that are busy.
  Future<Map<String, int>> _busyDoctors(List<DoctorModel> doctors) async {
    final Map<String, int> busy = {};
    for (final doc in doctors) {
      final active = await _firestoreActivePatients(doc.id.toString());
      if (active > 0) busy[doc.name] = active;
    }
    return busy;
  }

  // Opens the "Add New Department" form and saves the department to
  // Firestore on submit. The list refreshes automatically via the listener.
  void _openAddDepartmentDialog() {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Add New Department",
        submitLabel: "Add Department",
        fields: const [
          FormFieldConfig(
            key: "photo",
            label: "Department Photo",
            type: FieldType.image,
          ),
          FormFieldConfig(
            key: "name",
            label: "Department Name",
            type: FieldType.text,
            hint: "e.g. Cardiology",
            required: true,
          ),
          FormFieldConfig(
            key: "head",
            label: "Head of Department",
            type: FieldType.text,
            hint: "e.g. Dr. Sarah Johnson",
            required: true,
          ),
          FormFieldConfig(
            key: "status",
            label: "Status",
            type: FieldType.pillSelector,
            options: ["Active", "Inactive"],
          ),
        ],
        onSubmit: (values) {
          AppdataStore().addDepartment(
            Department(
              name: values["name"],
              head: values["head"] ?? "",
              assignedDoctors: 0,
              status: values["status"],
              createdDate: _formatToday(),
              photoBytes: values["photo"],
            ),
          );
        },
      ),
    );
  }

  // Opens the "Edit Department" form pre-filled with the given department's
  // data. Updates the same Firestore document (matched by id).
  // assignedDoctors and createdDate are preserved as-is.
  void _openEditDepartmentDialog(Department dept) {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Edit Department",
        submitLabel: "Save Changes",
        initialValues: {
          "photo": dept.photoBytes,
          "name": dept.name,
          "head": dept.head,
          "status": dept.status,
        },
        fields: const [
          FormFieldConfig(
            key: "photo",
            label: "Department Photo",
            type: FieldType.image,
          ),
          FormFieldConfig(
            key: "name",
            label: "Department Name",
            type: FieldType.text,
            hint: "e.g. Cardiology",
            required: true,
          ),
          FormFieldConfig(
            key: "head",
            label: "Head of Department",
            type: FieldType.text,
            hint: "e.g. Dr. Sarah Johnson",
          ),
          FormFieldConfig(
            key: "status",
            label: "Status",
            type: FieldType.pillSelector,
            options: ["Active", "Inactive"],
          ),
        ],
        onSubmit: (values) {
          AppdataStore().updateDepartment(
            Department(
              id: dept.id, // tells Firestore which document to update
              name: values["name"],
              head: values["head"] ?? "",
              assignedDoctors: dept.assignedDoctors, // preserved
              status: values["status"],
              createdDate: dept.createdDate, // preserved
              photoBytes: values["photo"],
            ),
          );
        },
      ),
    );
  }

  // Shown when a department cannot be deleted because some of its doctors
  // still have patients waiting or in consultation.
  Future<void> _showBlockedDeleteDialog(
    Department dept,
    Map<String, int> busyDoctors,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cannot Delete Department"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "\"${dept.name}\" cannot be deleted because "
              "${busyDoctors.length == 1 ? 'a doctor' : 'some doctors'} "
              "in this department still ${busyDoctors.length == 1 ? 'has' : 'have'} "
              "patients (Waiting or In Consultation):",
            ),
            const SizedBox(height: 12),
            ...busyDoctors.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• ${e.key} (${e.value} ${e.value == 1 ? 'patient' : 'patients'})",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Asks for confirmation before deleting a department. Blocks the delete if
  // any doctor in it still has active patients. If it has doctors with no
  // active patients, warns that they will be deleted too.
  Future<void> _confirmDeleteDepartment(Department dept) async {
    final store = AppdataStore();
    final deptDoctors =
        store.doctors.where((d) => d.department == dept.name).toList();
    final doctorCount = deptDoctors.length;

    // Block: any doctor here with waiting / in-consultation patients
    // (checked live in Firestore).
    Map<String, int> busyDoctors;
    try {
      busyDoctors = await _busyDoctors(deptDoctors);
    } catch (e) {
      _showErrorSnack(_friendlyError(e));
      return;
    }
    if (!mounted) return;
    if (busyDoctors.isNotEmpty) {
      await _showBlockedDeleteDialog(dept, busyDoctors);
      return;
    }

    // No doctors inside: delete straight away.
    if (doctorCount == 0) {
      try {
        await store.removeDepartment(dept);
      } catch (e) {
        _showErrorSnack(_friendlyError(e));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Department"),
        content: Text(
          "\"${dept.name}\" has $doctorCount "
          "${doctorCount == 1 ? 'doctor' : 'doctors'}. "
          "If you delete this department, "
          "${doctorCount == 1 ? 'that doctor' : 'all of these doctors'} "
          "will also be deleted. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Re-check: a patient may have joined a queue while the dialog was open.
      Map<String, int> nowBusy;
      try {
        nowBusy = await _busyDoctors(deptDoctors);
      } catch (e) {
        _showErrorSnack(_friendlyError(e));
        return;
      }
      if (nowBusy.isNotEmpty) {
        if (mounted) await _showBlockedDeleteDialog(dept, nowBusy);
        return;
      }

      try {
        await store.removeDepartmentWithDoctors(dept);
      } catch (e) {
        _showErrorSnack(_friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // All derived lists/stats are computed here in build() so they always
    // reflect the latest store state and instance filters.
    final List<Department> allDepartments = AppdataStore().departments;

    // Step 1: apply the status filter.
    List<Department> departments = selectedStatusFilter == "All Status"
        ? List<Department>.from(allDepartments)
        : allDepartments
              .where((d) => d.status == selectedStatusFilter)
              .toList();

    // Step 2: apply sorting.
    if (selectedSort == "Most Doctors") {
      departments.sort((a, b) {
        final countA = AppdataStore().doctors
            .where((doc) => doc.department == a.name)
            .length;
        final countB = AppdataStore().doctors
            .where((doc) => doc.department == b.name)
            .length;
        return countB.compareTo(countA);
      });
    }
    // "Recently Added": the store already keeps the departments newest
    // first (it sorts by the createdAt timestamp), so nothing to do here.

    // Step 3: intersect the filtered+sorted list with the current search query.
    final searchedNames =
        departmentSearch.filteredItems.map((d) => d.name).toSet();
    departments =
        departments.where((d) => searchedNames.contains(d.name)).toList();

    // Stats always come from the full unfiltered list.
    final int totalDepartments = allDepartments.length;
    final int totalAssignedDoctors = allDepartments.fold(
      0,
      (sum, d) => sum + d.assignedDoctors,
    );
    final int activeCount = allDepartments
        .where((d) => d.status.toLowerCase() == "active")
        .length;
    final int inactiveCount = allDepartments.length - activeCount;

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
                    // Header: original Row on desktop/tablet, skipped on mobile.
                    if (!isMobile) ...[
                      Row(
                        children: [
                          Text("Department Management",
                              style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Manage hospital departments, assign department heads, and organize department information.",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 15),

                    // Search bar, status filter, sort dropdown, add button
                    _buildToolbar(isMobile: isMobile),
                    const SizedBox(height: 24),

                    // Summary stat cards: total, assigned doctors, active, inactive
                    _buildStatCardsSection(
                      isMobile: isMobile,
                      totalDepartments: totalDepartments,
                      totalAssignedDoctors: totalAssignedDoctors,
                      activeCount: activeCount,
                      inactiveCount: inactiveCount,
                    ),
                    const SizedBox(height: 24),

                    // Department records table
                    _buildTable(departments, isMobile: isMobile),

                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Secondary entry point for adding a department.
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDepartmentDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 4 stat cards. Desktop: 1 row of 4. Mobile: 2x2 grid with tighter sizing.
  Widget _buildStatCardsSection({
    required bool isMobile,
    required int totalDepartments,
    required int totalAssignedDoctors,
    required int activeCount,
    required int inactiveCount,
  }) {
    final cardPadding =
        isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
    final cardIconPadding = isMobile ? 8.0 : 12.0;
    final cardIconSize = isMobile ? 18.0 : 22.0;
    final cardValueFontSize = isMobile ? 18.0 : 22.0;

    final card1 = StatCard(
      icon: Icons.apartment_outlined,
      iconColor: Colors.grey.shade700,
      iconBgColor: Colors.grey.shade200,
      label: "Total Departments",
      value: "$totalDepartments",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card2 = StatCard(
      icon: Icons.medical_services_outlined,
      iconColor: const Color(0xFFB8860B),
      iconBgColor: const Color(0xFFFAF3D0),
      label: "Assigned Doctors",
      value: "$totalAssignedDoctors",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card3 = StatCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: "Active Departments",
      value: "$activeCount",
      padding: cardPadding,
      iconContainerPadding: cardIconPadding,
      iconSize: cardIconSize,
      valueFontSize: cardValueFontSize,
    );
    final card4 = StatCard(
      icon: Icons.error_outline,
      iconColor: const Color(0xFFC62828),
      iconBgColor: const Color(0xFFF8D7DA),
      label: "Inactive Departments",
      value: "$inactiveCount",
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

  // Search bar + filters + add button. Desktop: 1 row. Mobile: stacked.
  Widget _buildToolbar({required bool isMobile}) {
    final searchBar = DashboardSearchBar(
      hintText: "Search department...",
      onChanged: (query) => departmentSearch.search(query),
    );

    final addButton = ElevatedButton.icon(
      onPressed: _openAddDepartmentDialog,
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add Department"),
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
                  value: selectedStatusFilter,
                  items: const ["All Status", "Active", "Inactive"],
                  onChanged: (value) =>
                      setState(() => selectedStatusFilter = value!),
                  fillWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  value: selectedSort,
                  items: const ["Recently Added", "Most Doctors"],
                  onChanged: (value) => setState(() => selectedSort = value!),
                  prefixLabel: "Sort: ",
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

    // fillWidth: false (default), because these sit directly in a Row
    // without Expanded, so they must size to their content.
    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedStatusFilter,
          items: const ["All Status", "Active", "Inactive"],
          onChanged: (value) => setState(() => selectedStatusFilter = value!),
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          value: selectedSort,
          items: const ["Recently Added", "Most Doctors"],
          onChanged: (value) => setState(() => selectedSort = value!),
          prefixLabel: "Sort: ",
        ),
        const SizedBox(width: 12),
        addButton,
      ],
    );
  }

  // Table. Desktop: renders as-is. Mobile: wrapped in horizontal scroll
  // with a fixed min-width so flex columns don't get squeezed.
  Widget _buildTable(List<Department> departments, {required bool isMobile}) {
    final table = DataTableCard<Department>(
      items: departments,
      emptyMessage: "No departments added yet",
      columns: [
        TableColumn<Department>(
          label: "Department",
          flex: 3,
          cellBuilder: (dept) => Row(
            children: [
              // Picture added by the admin, or initials when there is none.
              DepartmentAvatar(department: dept),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dept.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        TableColumn<Department>(
          label: "Department Head",
          flex: 3,
          cellBuilder: (dept) =>
              Text(dept.head, style: const TextStyle(fontSize: 14)),
        ),
        TableColumn<Department>(
          label: "Assigned Doctors",
          flex: 2,
          cellBuilder: (dept) {
            // Computed live from the doctors list rather than
            // trusting dept.assignedDoctors, so it can't drift stale.
            final count = AppdataStore().doctors
                .where((d) => d.department == dept.name)
                .length;
            return Text(
              "$count",
              style: const TextStyle(fontSize: 14),
            );
          },
        ),
        TableColumn<Department>(
          label: "Status",
          flex: 2,
          cellBuilder: (dept) => Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(status: dept.status),
          ),
        ),
        TableColumn<Department>(
          label: "Created Date",
          flex: 2,
          cellBuilder: (dept) => Text(
            dept.createdDate,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        TableColumn<Department>(
          label: "Actions",
          flex: 2,
          cellBuilder: (dept) => Row(
            children: [
              // Edit department
              GestureDetector(
                onTap: () => _openEditDepartmentDialog(dept),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 16),
              // Delete department from Firestore. Blocked if any of its
              // doctors has active patients. The list refreshes
              // automatically via the listener.
              GestureDetector(
                onTap: () => _confirmDeleteDepartment(dept),
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
      child: SizedBox(width: 900, child: table),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String prefixLabel = "",
    bool fillWidth = false, // only stretch when the caller has bounded width
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
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                "$prefixLabel$item",
                style: AppTypography.normaltext,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}