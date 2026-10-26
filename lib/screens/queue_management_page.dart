import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/call_patient.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/models/queue_model.dart';
import 'package:queue_management_system/screens/doctor_queue_page.dart';
import 'package:queue_management_system/screens/queue_admin_service.dart';
import 'package:queue_management_system/widgets/doctor_image.dart';
import 'package:queue_management_system/widgets/loading_or_offline.dart';
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
  String _searchQuery = "";

  // Reads today's queue from Firestore and performs the admin actions.
  final QueueAdminService _service = QueueAdminService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  // Doctor whose action (Call Next / Complete) is currently running.
  String? _busyDoctorName;

  // doctor_presence: when each doctor's own app last said "I am open"
  // (written by the doctor dashboard every minute).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _presenceSub;
  Timer? _presenceTicker;
  final Map<String, DateTime> _lastSeen = {};

  @override
  void initState() {
    super.initState();
    _stream = _service.watchTodaysEntries();
    // Doctors/departments come from the store; refresh when they change.
    AppdataStore().addListener(_onStoreChanged);

    _presenceSub = FirebaseFirestore.instance
        .collection('doctor_presence')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _lastSeen.clear();
        for (final d in snap.docs) {
          final v = d.data()['lastSeen'];
          if (v is Timestamp) _lastSeen[d.id] = v.toDate();
        }
      });
    }, onError: (_) {});
    // A doctor who closed the app drops off after a few minutes.
    _presenceTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _presenceTicker?.cancel();
    AppdataStore().removeListener(_onStoreChanged);
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
  }

  // True while the doctor's own app is open (seen in the last 3 minutes).
  bool _isDoctorOnline(String doctorName) {
    final id = _doctorIdFor(doctorName);
    final seen = id == null ? null : _lastSeen[id];
    return seen != null &&
        DateTime.now().difference(seen) < const Duration(minutes: 3);
  }

  // Firestore doctor id for a doctor name (queue entries store doctorId).
  String? _doctorIdFor(String name) {
    for (final d in AppdataStore().doctors) {
      if (d.name == name) return d.id;
    }
    return null;
  }

  // Runs one admin action for a doctor. Blocks double clicks and shows a
  // snackbar if something fails (network, permission, queue changed...).
  // Returns true when the action succeeded, false otherwise.
  Future<bool> _runAction(
    String doctorName,
    Future<void> Function(String doctorId) action,
  ) async {
    if (_busyDoctorName != null) return false;

    final id = _doctorIdFor(doctorName);
    if (id == null) {
      _showSnack("Doctor not found.");
      return false;
    }

    setState(() => _busyDoctorName = doctorName);
    try {
      await action(id);
      return true;
    } catch (e) {
      _showSnack(QueueAdminService.friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => _busyDoctorName = null);
    }
  }

  // The doctor's patient who is "In Consultation" right now (fresh read of
  // today's queue), or null when nobody is.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _currentEntryOf(
    String doctorId,
  ) async {
    final snap = await _service.watchTodaysEntries().first;
    final current =
        snap.docs.where((d) {
          return d.data()['doctorId'] == doctorId &&
              QueueAdminService.normalizeStatus(
                    d.data()['status']?.toString(),
                  ) ==
                  'In Consultation';
        }).toList()..sort(
          (a, b) =>
              QueueAdminService.seqOf(a).compareTo(QueueAdminService.seqOf(b)),
        );
    return current.isEmpty ? null : current.first;
  }

  // Marks the current patient as done, then tells that patient their visit
  // is complete.
  Future<void> _handleComplete(String doctorName) async {
    // Find who is being served BEFORE completing, because after completing
    // nobody is "In Consultation" any more.
    final doctorId = _doctorIdFor(doctorName);
    String? entryId;
    if (doctorId != null) {
      try {
        entryId = (await _currentEntryOf(doctorId))?.id;
      } catch (_) {}
    }

    final ok = await _runAction(doctorName, _service.completeCurrent);
    if (ok && entryId != null) {
      final note = await notifyPatient(entryId, 'completed');
      if (note != null) _showSnack(note);
    }
  }

  // Calls the next waiting patient in, then sends them a push notification.
  Future<void> _handleCallNext(String doctorName) async {
    final ok = await _runAction(doctorName, _service.callNext);
    if (ok) await _notifyCurrentPatient(doctorName);
  }

  // After Call Next, notifies the patient who is now "In Consultation".
  Future<void> _notifyCurrentPatient(String doctorName) async {
    final doctorId = _doctorIdFor(doctorName);
    if (doctorId == null) return;

    try {
      final current = await _currentEntryOf(doctorId);
      if (current == null) return;

      final note = await notifyCalledPatient(current.id);
      if (note != null) _showSnack(note);
    } catch (_) {
      // Notification fail ho to Call Next phir bhi ho chuka hota hai
    }
  }

  // One DoctorQueueStatus per doctor, built from today's queue entries.
  // Doctors with no patients still appear (with zero counts).
  //
  // The list is ordered so the busiest doctors are on top:
  //  1. Doctors with patients waiting / in consultation, the one whose
  //     newest patient arrived most recently first.
  //  2. Doctors who saw patients today but have nobody active now.
  //  3. Doctors with no patients today, at the bottom (A to Z).
  List<DoctorQueueStatus> _buildQueues(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ranked = AppdataStore().doctors.map((doc) {
      final mine = docs.where((d) => d.data()['doctorId'] == doc.id).toList();

      String statusOf(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
          QueueAdminService.normalizeStatus(d.data()['status']?.toString());

      final inConsultation =
          mine.where((d) => statusOf(d) == 'In Consultation').toList()..sort(
            (a, b) => QueueAdminService.seqOf(
              a,
            ).compareTo(QueueAdminService.seqOf(b)),
          );

      final waitingCount = mine.where((d) => statusOf(d) == 'Waiting').length;
      final completedCount = mine
          .where((d) => statusOf(d) == 'Completed')
          .length;

      // When this doctor's newest patient arrived. joinedAt is null for a
      // moment right after a patient joins, so treat that as "now".
      DateTime? lastJoined;
      for (final d in mine) {
        final t = d.data()['joinedAt'];
        final when = t is Timestamp ? t.toDate() : DateTime.now();
        if (lastJoined == null || when.isAfter(lastJoined)) {
          lastJoined = when;
        }
      }

      final queue = DoctorQueueStatus(
        name: doc.name,
        department: doc.department,
        specialization: doc.specialization,
        currentToken: inConsultation.isEmpty
            ? null
            : inConsultation.first.data()['token']?.toString(),
        waitingCount: waitingCount,
        completedToday: completedCount,
      );

      return _RankedQueue(
        queue: queue,
        lastJoined: lastJoined,
        hasActive: waitingCount > 0 || inConsultation.isNotEmpty,
      );
    }).toList();

    // 0 = has active patients, 1 = had patients today, 2 = no patients today.
    int tier(_RankedQueue r) =>
        r.hasActive ? 0 : (r.lastJoined != null ? 1 : 2);

    ranked.sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;

      // Same tier: newest patient first.
      if (a.lastJoined != null && b.lastJoined != null) {
        final byTime = b.lastJoined!.compareTo(a.lastJoined!);
        if (byTime != 0) return byTime;
      }

      // Still tied (or both empty): A to Z, so the order never jumps around.
      return a.queue.name.toLowerCase().compareTo(b.queue.name.toLowerCase());
    });

    return ranked.map((r) => r.queue).toList();
  }

  // Applies the search text and the department filter.
  List<DoctorQueueStatus> _applyFilters(List<DoctorQueueStatus> queues) {
    final q = _searchQuery.trim().toLowerCase();
    return queues.where((queue) {
      final matchesSearch = q.isEmpty || queue.name.toLowerCase().contains(q);
      final matchesDept =
          selectedDepartmentFilter == "All Departments" ||
          queue.department == selectedDepartmentFilter;
      return matchesSearch && matchesDept;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final departmentOptions = [
      "All Departments",
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

                    // Doctor queue cards, live from Firestore
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                QueueAdminService.friendlyError(
                                  snapshot.error!,
                                ),
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }
                       

                        if (!snapshot.hasData || !AppdataStore().doctorsLoaded) {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: LoadingOrOffline(message: "Loading..."),
  );
}


                        final visible = _applyFilters(
                          _buildQueues(snapshot.data!.docs),
                        );

                                                 if (visible.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/no_q.png',
                                    width: isMobile ? 220 : 420,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Queues will appear here when doctors start receiving patients",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: visible.map((queue) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _DoctorQueueCard(
                                queue: queue,
                                isMobile: isMobile,
                                isBusy: _busyDoctorName != null,
                                doctorOnline: _isDoctorOnline(queue.name),
                                onComplete: () => _handleComplete(queue.name),
                                onCallNext: () => _handleCallNext(queue.name),
                                // Everything is live now, nothing to refresh.
                                onReturn: () {},
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
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
      onChanged: (query) => setState(() => _searchQuery = query),
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
            onChanged: (value) =>
                setState(() => selectedDepartmentFilter = value!),
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
          onChanged: (value) =>
              setState(() => selectedDepartmentFilter = value!),
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
    // If the selected department was deleted meanwhile, fall back safely.
    final safeValue = items.contains(value) ? value : items.first;

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
          value: safeValue,
          isExpanded: fillWidth,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: AppTypography.normaltext,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// A doctor's queue status plus what is needed to rank it in the list.
class _RankedQueue {
  final DoctorQueueStatus queue;
  final DateTime? lastJoined; // when the doctor's newest patient arrived today
  final bool hasActive; // has patients waiting or in consultation

  const _RankedQueue({
    required this.queue,
    required this.lastJoined,
    required this.hasActive,
  });
}

// A single doctor's queue row: identity, live stats (current/waiting/
// completed), and action buttons. Tapping the card opens the doctor's
// full queue detail page.
class _DoctorQueueCard extends StatefulWidget {
  final DoctorQueueStatus queue;
  final bool isMobile;
  final bool isBusy; // an action is running; buttons are disabled
  final bool doctorOnline; // the doctor's own app is open right now
  final VoidCallback onComplete;
  final VoidCallback onCallNext;
  final VoidCallback onReturn;

  const _DoctorQueueCard({
    required this.queue,
    required this.isMobile,
    required this.isBusy,
    this.doctorOnline = false,
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
      return AppdataStore().doctors.firstWhere(
        (d) => d.name == widget.queue.name,
      );
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
        // Notify the parent list after the detail page closes.
        widget.onReturn();
      },
      child: RoundedCard(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: widget.isMobile
            ? _buildMobileLayout(hasCurrentPatient, isActive)
            : _buildDesktopLayout(hasCurrentPatient, isActive),
      ),
    );
  }

  // Original layout — used on laptop/web/tablet.
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.queue.specialization,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (widget.doctorOnline) ...[
                const SizedBox(height: 6),
                _buildOnlineChip(),
              ],
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
          enabled: hasCurrentPatient && !widget.isBusy,
          onTap: widget.onComplete,
        ),
        const SizedBox(width: 10),

        // Calls the next waiting patient; only enabled when the doctor
        // is active, free (no current patient), and someone is waiting.
        _buildFilledButton(
          label: "Call Next",
          enabled:
              isActive &&
              !hasCurrentPatient &&
              widget.queue.waitingCount > 0 &&
              !widget.isBusy,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.queue.specialization,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (widget.doctorOnline) ...[
                    const SizedBox(height: 6),
                    _buildOnlineChip(),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatBlock(
                "CURRENT",
                widget.queue.currentToken ?? "--",
              ),
            ),
            Expanded(
              child: _buildStatBlock("WAITING", "${widget.queue.waitingCount}"),
            ),
            Expanded(
              child: _buildStatBlock(
                "COMPLETED\nTODAY",
                "${widget.queue.completedToday}",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOutlinedButton(
                label: "Complete",
                enabled: hasCurrentPatient && !widget.isBusy,
                onTap: widget.onComplete,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilledButton(
                label: "Call Next",
                enabled:
                    isActive &&
                    !hasCurrentPatient &&
                    widget.queue.waitingCount > 0 &&
                    !widget.isBusy,
                onTap: widget.onCallNext,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Shown while the doctor's own app is open (doctor_presence heartbeat).
  Widget _buildOnlineChip() {
    const green = Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD4EDDA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: green),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              'Managing own queue',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: green,
              ),
            ),
          ),
        ],
      ),
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
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
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
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: fullWidth ? double.infinity : null,
        alignment: fullWidth ? Alignment.center : null,
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
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: fullWidth ? double.infinity : null,
        alignment: fullWidth ? Alignment.center : null,
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