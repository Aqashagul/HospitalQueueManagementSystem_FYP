import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/data/queue_controller.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/models/queue_model.dart';
import 'package:queue_management_system/screens/doctor_queue_page.dart';
import 'package:queue_management_system/widgets/doctor_image.dart';
import 'package:queue_management_system/widgets/generic_p.dart/search_controller.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';


class QueueManagementPage extends StatefulWidget {
  const QueueManagementPage({super.key});

  @override
  State<QueueManagementPage> createState() => _QueueManagementPageState();
}

class _QueueManagementPageState extends State<QueueManagementPage> {
  String selectedDepartmentFilter = "All Departments";
  String selectedStatusFilter = "All Statuses";

  // Owns queue state and exposes the actions that mutate it
  // (call next, complete patient, etc.).
  final QueueController _controller = QueueController();

  // Always reads the current queue snapshot from the controller.
  List<DoctorQueueStatus> get queues => _controller.getQueues();

  // Handles name-based search across the queue list.
  late final GenericSearchController<DoctorQueueStatus> queueSearch;

  @override
  void initState() {
    super.initState();
    queueSearch = GenericSearchController<DoctorQueueStatus>(
      items: queues,
      filterLogic: (q, query) => q.name.toLowerCase().contains(query),
    );
    // Rebuild whenever the search query or its results change.
    queueSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    queueSearch.dispose();
    super.dispose();
  }

  // Search results narrowed further by the selected department filter.
  List<DoctorQueueStatus> get _visibleQueues {
    return queueSearch.filteredItems.where((q) {
      return selectedDepartmentFilter == "All Departments" ||
          q.department == selectedDepartmentFilter;
    }).toList();
  }

  void _handleComplete(String doctorName) {
    setState(() {
      _controller.completePatient(doctorName);
    });
  }

  void _handleCallNext(String doctorName) {
    setState(() {
      _controller.callNextPatient(doctorName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final departmentOptions = [
      "All Departments",
      ...AppdataStore().departments.map((d) => d.name),
    ];

    // Keep the search controller's source list in sync with the latest
    // queue data on every rebuild, since _controller.getQueues() can
    // change between builds (e.g. after complete/call-next actions).
    queueSearch.updateItems(queues);

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
                          Text("Queue Management", style: AppTypography.title),
                          const Spacer(),
                          const LiveDateTimeWidget(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Manage all doctors' live queues",
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 15),

                    // Search bar + department filter dropdown — mobile pe stacked
                    _buildToolbar(
                      isMobile: isMobile,
                      departmentOptions: departmentOptions,
                    ),
                    const SizedBox(height: 24),

                    // Doctor queue cards, or an empty-state message if none match
                    if (_visibleQueues.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            "No doctors match the selected filters",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_visibleQueues.length, (index) {
                        final queue = _visibleQueues[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _DoctorQueueCard(
                            queue: queue,
                            isMobile: isMobile,
                            onComplete: () => _handleComplete(queue.name),
                            onCallNext: () => _handleCallNext(queue.name),
                            // Refresh state after returning from the detail page,
                            // in case the queue changed there.
                            onReturn: () => setState(() {}),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildToolbar({
    required bool isMobile,
    required List<String> departmentOptions,
  }) {
    final searchBar = DashboardSearchBar(
      hintText: "Search doctor...",
      onChanged: (query) => queueSearch.search(query),
    );

    if (isMobile) {
     
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 12),
          _buildDropdown(
            value: selectedDepartmentFilter,
            items: departmentOptions,
            onChanged: (value) => setState(() => selectedDepartmentFilter = value!),
            fillWidth: true,
          ),
        ],
      );
    }

   
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
      ],
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

// A single doctor's queue row: identity, live stats (current/waiting/
// completed), and action buttons. Tapping the card opens the doctor's
// full queue detail page.
class _DoctorQueueCard extends StatefulWidget {
  final DoctorQueueStatus queue;
  final bool isMobile; // NEW
  final VoidCallback onComplete;
  final VoidCallback onCallNext;
  final VoidCallback onReturn;

  const _DoctorQueueCard({
    required this.queue,
    required this.isMobile,
    required this.onComplete,
    required this.onCallNext,
    required this.onReturn,
  });

  @override
  State<_DoctorQueueCard> createState() => _DoctorQueueCardState();
}

class _DoctorQueueCardState extends State<_DoctorQueueCard> {
  // Looks up the full doctor profile matching this queue entry by name.
  // Returns null if no matching doctor is found in the store.
  DoctorModel? get doctor {
    try {
      return AppdataStore().doctors.firstWhere((d) => d.name == widget.queue.name);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Doctor active/on-duty status is not tracked yet — always treated as active.
    const bool isActive = true;
    final bool hasCurrentPatient = widget.queue.currentToken != null;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorQueueDetailPage(
              doctorName: widget.queue.name,
              department: widget.queue.department,
            ),
          ),
        );
        // Notify the parent list so it can refresh after the detail page closes.
        widget.onReturn();
      },
      // Reusing the shared RoundedCard here instead of a hand-rolled Container
      // keeps this card's styling consistent with the rest of the app.
      child: RoundedCard(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: widget.isMobile ? _buildMobileLayout(hasCurrentPatient, isActive) : _buildDesktopLayout(hasCurrentPatient, isActive),
      ),
    );
  }

  // Original layout — unchanged, used on laptop/web/tablet.
  Widget _buildDesktopLayout(bool hasCurrentPatient, bool isActive) {
    return Row(
      children: [
        // Doctor identity
        DoctorAvatar(doctor: doctor!),
        const SizedBox(width: 14),
        SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.queue.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                widget.queue.specialization,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        // Live stats: current token, patients waiting, completed today
        _buildStatBlock("CURRENT", widget.queue.currentToken ?? "--"),
        const SizedBox(width: 32),
        _buildStatBlock("WAITING", "${widget.queue.waitingCount}"),
        const SizedBox(width: 32),
        _buildStatBlock("COMPLETED\nTODAY", "${widget.queue.completedToday}"),

        const Spacer(),

        // Marks the current patient as done; only enabled when someone
        // is currently being served.
        _buildOutlinedButton(
          label: "Complete",
          enabled: hasCurrentPatient,
          onTap: widget.onComplete,
        ),
        const SizedBox(width: 10),

        // Calls the next waiting patient; only enabled when the doctor
        // is active, free (no current patient), and someone is waiting.
        _buildFilledButton(
          label: "Call Next",
          enabled: isActive && !hasCurrentPatient && widget.queue.waitingCount > 0,
          onTap: widget.onCallNext,
        ),
        const SizedBox(width: 8),

        Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ],
    );
  }

  // Mobile layout — identity row on top, stats in their own row,
  // buttons full-width side by side below. Nothing here is fixed-width.
  Widget _buildMobileLayout(bool hasCurrentPatient, bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DoctorAvatar(doctor: doctor!),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.queue.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.queue.specialization,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatBlock("CURRENT", widget.queue.currentToken ?? "--")),
            Expanded(child: _buildStatBlock("WAITING", "${widget.queue.waitingCount}")),
            Expanded(child: _buildStatBlock("COMPLETED\nTODAY", "${widget.queue.completedToday}")),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOutlinedButton(
                label: "Complete",
                enabled: hasCurrentPatient,
                onTap: widget.onComplete,
                fullWidth: true, // NEW
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilledButton(
                label: "Call Next",
                enabled: isActive && !hasCurrentPatient && widget.queue.waitingCount > 0,
                onTap: widget.onCallNext,
                fullWidth: true, // NEW
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Small labeled stat display (e.g. "WAITING" -> "4").
  Widget _buildStatBlock(String label, String value) {
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // "Complete" button — green when enabled, greyed out and non-interactive
  // when disabled.
  Widget _buildOutlinedButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool fullWidth = false, // NEW
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: fullWidth ? double.infinity : null, // NEW
        alignment: fullWidth ? Alignment.center : null, // NEW
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF2E7D32) : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(10),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }

  // "Call Next" button — purple when enabled, greyed out and
  // non-interactive when disabled.
  Widget _buildFilledButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool fullWidth = false, // NEW
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: fullWidth ? double.infinity : null, // NEW
        alignment: fullWidth ? Alignment.center : null, // NEW
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryPurple : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(10),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }
}