import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/department_model.dart';
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
  }

  @override
  void dispose() {
    departmentSearch.dispose();
    super.dispose();
  }

  // Opens the "Add New Department" form and appends the new department to the store on submit.
  void _openAddDepartmentDialog() {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Add New Department",
        submitLabel: "Add Department",
        fields: const [
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
          setState(() {
            AppdataStore().departments.insert(0,
              Department(
                name: values["name"],
                head: values["head"] ?? "",
                assignedDoctors: 0,
                status: values["status"],
                // TODO: hardcoded — should use the actual current date.
                createdDate: "Aug 14, 2026",
              ),
            );
            // Keep the search controller's source list in sync, otherwise
            // the new department won't show up in search results.
            departmentSearch.updateItems(AppdataStore().departments);
          });
        },
      ),
    );
  }

  // Opens the "Edit Department" form pre-filled with the given department's data.
  // assignedDoctors and createdDate are preserved as-is since they're not editable here.
  void _openEditDepartmentDialog(Department dept) {
    showDialog(
      context: context,
      builder: (_) => AppFormDialog(
        title: "Edit Department",
        submitLabel: "Save Changes",
        initialValues: {
          "name": dept.name,
          "head": dept.head,
          "status": dept.status,
        },
        fields: const [
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
          setState(() {
            final index = AppdataStore().departments.indexOf(dept);
            if (index == -1) return;

            AppdataStore().departments[index] = Department(
              name: values["name"],
              head: values["head"] ?? "",
              assignedDoctors: dept.assignedDoctors, // preserved
              status: values["status"],
              createdDate: dept.createdDate, // preserved
            );
            departmentSearch.updateItems(AppdataStore().departments);
          });
        },
      ),
    );
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
    } else if (selectedSort == "Recently Added") {
      // Departments are stored in insertion order, so reversing puts the
      // most recently added ones first.

    }

    // Step 3: intersect the filtered+sorted list with the current search query.
    final searchedNames = departmentSearch.filteredItems
        .map((d) => d.name)
        .toSet();
    departments = departments
        .where((d) => searchedNames.contains(d.name))
        .toList();

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
                final bool isMobile = constraints.maxWidth < 700; // NEW

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header — desktop/tablet pe original Row, mobile pe pura skip
                    if (!isMobile) ...[
                      Row(
                        children: [
                          Text("Department Management", style: AppTypography.title),
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

 // Search bar, status filter, sort dropdown, and add-department button
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
      // Secondary entry point for adding a department (mirrors the "Add Department" button above).
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDepartmentDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 4 stat cards — desktop: 1 row of 4. Mobile: 2x2 grid with tighter sizing.
  Widget _buildStatCardsSection({
    required bool isMobile,
    required int totalDepartments,
    required int totalAssignedDoctors,
    required int activeCount,
    required int inactiveCount,
  }) {
   
 final cardPadding = isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
final cardIconPadding = isMobile ? 8.0 : 12.0;
final cardIconSize = isMobile ? 18.0 : 22.0;
final cardValueFontSize = isMobile ? 18.0 : 22.0;
//final cardLabelFontSize = isMobile ? 10.0 : null;

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
     // labelFontSize: cardLabelFontSize,
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
     // labelFontSize: cardLabelFontSize,
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
     // labelFontSize: cardLabelFontSize,
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
      //labelFontSize: cardLabelFontSize,
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

  // Search bar + filters + add button — desktop: 1 row. Mobile: stacked.
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
                  value: selectedStatusFilter,
                  items: const ["All Status", "Active", "Inactive"],
                  onChanged: (value) => setState(() => selectedStatusFilter = value!),
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

    // fillWidth: false (default) — these sit directly in a Row without
    // Expanded, so they must size to their content, not try to fill infinite width.
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

  // Table — desktop: renders as-is (flex columns fit the wide screen).
  // Mobile: wrapped in horizontal scroll with a fixed min-width so flex
  // columns don't get squeezed (this is what was cutting off the status pill text).
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
              InitialsAvatar(name: dept.name),
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
              // Remove department — delegated to the store so it
              // can also handle any related cleanup.
              GestureDetector(
                onTap: () {
                  setState(() {
                    AppdataStore().removeDepartment(dept);
                    departmentSearch.updateItems(
                      AppdataStore().departments,
                    );
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
      child: SizedBox(width: 900, child: table), // NEW: gives columns room so they don't squeeze
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String prefixLabel = "",
    bool fillWidth = false, // CHANGED: only stretch when the caller has bounded width (Expanded)
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
          isExpanded: fillWidth, // CHANGED: was always true — crashed when placed directly in a Row
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                "$prefixLabel$item",
                style: AppTypography.normaltext,
                overflow: TextOverflow.ellipsis, // NEW
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}