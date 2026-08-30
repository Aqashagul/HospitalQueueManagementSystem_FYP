import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/data/appdata_store.dart';

// View model for a single row in the Current Queue table. Kept separate
// from PatientModel so this widget doesn't depend directly on the store's
// data shape.
class QueueEntry {
  final String token;
  final String patientName;
  final String doctorName;
  final String department;
  final String status;

  const QueueEntry({
    required this.token,
    required this.patientName,
    required this.doctorName,
    required this.department,
    required this.status,
  });
}

// Dashboard widget showing all patients who are still active in the
// queue (i.e. not completed or cancelled), in a simple table layout.
// Shows the 6 most recently registered by default, with a "View more"
// toggle to reveal the rest.
class CurrentQueue extends StatefulWidget {
  const CurrentQueue({super.key});

  @override
  State<CurrentQueue> createState() => _CurrentQueueState();
}

class _CurrentQueueState extends State<CurrentQueue> {
  static const int _previewCount = 6;
  bool _showAll = false;
  bool _isViewMoreHovered = false;

  // Live patients from the store, filtered to active ones only and
  // sorted so the most recently registered patient comes first.
  List<QueueEntry> get _allEntries {
    final activePatients = AppdataStore()
        .patient
        .where((p) => p.status != "Completed" && p.status != "Cancelled")
        .toList();

    activePatients.sort((a, b) => b.registrationTime.compareTo(a.registrationTime));

    return activePatients
        .map((p) => QueueEntry(
              token: p.token,
              patientName: p.name,
              doctorName: p.doctor,
              department: p.department,
              status: p.status,
            ))
        .toList();
  }

  // Flex ratios shared by the header row and every data row, so columns
  // always line up regardless of content length.
  static const Map<String, int> _columnFlex = {
    "token": 2,
    "patient": 3,
    "doctor": 3,
    "department": 3,
    "status": 2,
  };

  @override
  Widget build(BuildContext context) {
    final allEntries = _allEntries;
    final bool hasMore = allEntries.length > _previewCount;
    final entriesToShow = _showAll ? allEntries : allEntries.take(_previewCount).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recently Added Patients",
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),

          _buildHeaderRow(),
          const Divider(height: 24),

          // Built with Column.generate instead of ListView.builder since
          // this already sits inside a SingleChildScrollView on the
          // dashboard page.
          ...List.generate(entriesToShow.length, (index) {
            final entry = entriesToShow[index];
            final isLast = index == entriesToShow.length - 1;

            return Column(
              children: [
                _buildDataRow(entry),
                if (!isLast) const Divider(height: 24),
              ],
            );
          }),

          if (hasMore) ...[
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isViewMoreHovered = true),
              onExit: (_) => setState(() => _isViewMoreHovered = false),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isViewMoreHovered
                        ? Color.lerp(AppColors.primaryPurple, Colors.black, 0.1)
                        : AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isViewMoreHovered
                        ? [
                            BoxShadow(
                              color: AppColors.primaryPurple.withValues(alpha: .35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAll ? "View less" : "View more",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Column header labels, aligned to the same flex ratios as the data rows.
  Widget _buildHeaderRow() {
    TextStyle headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );

    return Row(
      children: [
        Expanded(flex: _columnFlex["token"]!, child: Text("Token", style: headerStyle)),
        Expanded(flex: _columnFlex["patient"]!, child: Text("Patient", style: headerStyle)),
        Expanded(flex: _columnFlex["doctor"]!, child: Text("Doctor", style: headerStyle)),
        Expanded(flex: _columnFlex["department"]!, child: Text("Department", style: headerStyle)),
        Expanded(flex: _columnFlex["status"]!, child: Text("Status", style: headerStyle)),
      ],
    );
  }

  // Renders one queue entry as a row matching the header's column layout.
  Widget _buildDataRow(QueueEntry entry) {
    TextStyle cellStyle = const TextStyle(fontSize: 14, color: Colors.black87);

    return Row(
      children: [
        Expanded(
          flex: _columnFlex["token"]!,
          child: Text(
            entry.token,
            style: cellStyle.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: _columnFlex["patient"]!,
          child: Text(entry.patientName, style: cellStyle),
        ),
        Expanded(
          flex: _columnFlex["doctor"]!,
          child: Text(entry.doctorName, style: cellStyle),
        ),
        Expanded(
          flex: _columnFlex["department"]!,
          child: Text(entry.department, style: cellStyle),
        ),
        Expanded(
          flex: _columnFlex["status"]!,
          child: _StatusPill(status: entry.status),
        ),
      ],
    );
  }
}

// Small colored pill showing a patient's status, with colors mapped
// per status (e.g. waiting = orange, in consultation = blue,
// completed = green, cancelled = red).
class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  Color get _bgColor {
    switch (status.toLowerCase()) {
      case "waiting":
        return const Color(0xFFFFF3CD);
      case "in consultation":
        return const Color(0xFFD6EAF8);
      case "completed":
        return const Color(0xFFD4EDDA);
      case "cancelled":
        return const Color(0xFFF8D7DA);
      default:
        return Colors.grey.shade200;
    }
  }

  Color get _textColor {
    switch (status.toLowerCase()) {
      case "waiting":
        return const Color(0xFFB8860B);
      case "in consultation":
        return const Color(0xFF3B82C4);
      case "completed":
        return const Color(0xFF2E7D32);
      case "cancelled":
        return const Color(0xFFC62828);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}