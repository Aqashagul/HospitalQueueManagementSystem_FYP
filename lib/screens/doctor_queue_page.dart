import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/models/doctor_queue_model.dart';
import 'package:queue_management_system/screens/queue_admin_service.dart';
import 'package:queue_management_system/widgets/confirm_action_dialog.dart' show showConfirmActionDialog;
import 'package:queue_management_system/widgets/doctor_image.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/loading_or_offline.dart';
import 'package:queue_management_system/widgets/notify_report.dart';



class DoctorQueueDetailPage extends StatefulWidget {
  final String doctorName;
  final String department;
  final bool showBack; // false when a doctor uses this page
  // Doctor mode: the doctor dashboard has its own top bar, so the old bar is
  // hidden and one compact "Accepting patients" card is shown instead.
  final bool doctorMode;
  // Doctor mode: the availability switch, shown inside the status card.
  final Widget? topBarTrailing;

  const DoctorQueueDetailPage({
    super.key,
    required this.doctorName,
    required this.department,
    this.showBack = true,
    this.topBarTrailing,
    this.doctorMode = false,
  });

  @override
  State<DoctorQueueDetailPage> createState() => _DoctorQueueDetailPageState();
}

class _DoctorQueueDetailPageState extends State<DoctorQueueDetailPage> {
  int selectedTabIndex = 0; // 0 = Waiting, 1 = Completed
  int selectedPatientIndex = 0;
  // True once the user has explicitly tapped a patient in the list,
  // overriding the default auto-selected patient.
  bool _hasManualSelection = false;

  int _mobilePanelIndex = 0;

  // Per-button loading flags, shown as spinners while an action is in flight.
  bool _isCompleting = false;
  bool _isCallingNext = false;
  bool _isSkipping = false;
  bool _isCancelling = false;

  // Live queue data for this doctor (today) straight from Firestore.
  final QueueAdminService _service = QueueAdminService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loaded = false;
  String? _loadError;

  // Ticks every 30 seconds so the "wait" time updates live on screen.
  Timer? _ticker;

  // Admin screen only: when this doctor's own app last said "I am open"
  // (doctor_presence/{doctorId}.lastSeen, written by the doctor dashboard).
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _presenceSub;
  DateTime? _doctorLastSeen;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    final id = _doctorId;
    if (id == null) {
      _loaded = true; // doctor not found: nothing to listen to
      return;
    }
    if (!widget.doctorMode) {
      _presenceSub = FirebaseFirestore.instance
          .collection('doctor_presence')
          .doc(id)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final v = snap.data()?['lastSeen'];
        setState(() => _doctorLastSeen = v is Timestamp ? v.toDate() : null);
      }, onError: (_) {});
    }

    _sub = _service.watchTodaysEntriesForDoctor(id).listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _docs = snap.docs;
          _loaded = true;
          _loadError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loadError = QueueAdminService.friendlyError(e);
          _loaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }

  // Formats a DateTime as "h:mm AM/PM".
  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  // Looks up the full doctor profile for this page. Returns null if
  // no matching doctor is found in the store.
  DoctorModel? get doctor {
    try {
      return AppdataStore().doctors.firstWhere(
        (d) => d.name == widget.doctorName,
      );
    } catch (_) {
      return null;
    }
  }

  // Firestore id of this doctor (queue entries store it as doctorId).
  String? get _doctorId => doctor?.id;

  // Admin screen only: true while the doctor's own app is open (it writes
  // lastSeen every minute). The 30 second ticker above keeps this fresh.
  bool get _doctorManagesNow =>
      !widget.doctorMode &&
      _doctorLastSeen != null &&
      DateTime.now().difference(_doctorLastSeen!) < const Duration(minutes: 3);

  // Adds the "doctor manages their own queue" line to a confirm popup.
  String _withOwnerNote(String message) => _doctorManagesNow
      ? '$message\n\nThis doctor manages their own queue. Continue?'
      : message;

  Widget _buildManagedByDoctorChip() {
    const green = Color(0xFF2E7D32);
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD4EDDA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: green),
          SizedBox(width: 6),
          Text(
            'Doctor is managing this queue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: green,
            ),
          ),
        ],
      ),
    );
  }

  // Red snackbar: the action itself failed.
  void _showSnack(String message) {
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

  // Green snackbar: an action worked.
  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
  }

  // A readable message for the admin. For unexpected errors the error code
  // is added in brackets, so a problem is easy to find.
  String _errorText(Object e) {
    final friendly = QueueAdminService.friendlyError(e);
    if (e is StateError) return friendly;
    if (e is FirebaseException &&
        (e.code == 'permission-denied' ||
            e.code == 'unavailable' ||
            e.code == 'network-request-failed' ||
            e.code == 'deadline-exceeded')) {
      return friendly;
    }
    debugPrint('Admin action failed: $e');
    return '$friendly (${e is FirebaseException ? e.code : e.runtimeType})';
  }

  // Entries with the given status, ordered by seq (joining order).
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docsWithStatus(
    String status,
  ) {
    return _docs
        .where(
          (d) =>
              QueueAdminService.normalizeStatus(
                d.data()['status']?.toString(),
              ) ==
              status,
        )
        .toList()
      ..sort(
        (a, b) =>
            QueueAdminService.seqOf(a).compareTo(QueueAdminService.seqOf(b)),
      );
  }

  // Maps a Firestore queue entry into the QueuePatient view model.
  // estWaitMinutes = how long a Waiting patient has been waiting so far
  // (now - joinedAt). It is 0 for patients no longer waiting.
  QueuePatient _toQueuePatient(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final joinedAt = data['joinedAt'];
    final registrationTime =
        joinedAt is Timestamp ? joinedAt.toDate() : DateTime.now();
    final status = QueueAdminService.normalizeStatus(
      data['status']?.toString(),
    );

    int waited = 0;
    if (status == 'Waiting') {
      final diff = DateTime.now().difference(registrationTime);
      waited = diff.isNegative ? 0 : diff.inMinutes;
    }

    return QueuePatient(
      token: data['token']?.toString() ?? '--',
      patientName: data['patientName']?.toString() ?? '',
      phoneNumber: data['phone']?.toString() ?? '',
      registrationTime: registrationTime,
      doctorName: widget.doctorName,
      department: widget.department,
      status: status,
      estWaitMinutes: waited,
    );
  }

  // Firestore document id of the entry with this token (tokens are unique
  // per doctor per day).
  String? _entryIdForToken(String token) {
    for (final d in _docs) {
      if (d.data()['token']?.toString() == token) return d.id;
    }
    return null;
  }

  // All patients currently waiting for this doctor.
  List<QueuePatient> get waitingPatients =>
      _docsWithStatus('Waiting').map(_toQueuePatient).toList();

  // All patients this doctor has finished seeing.
  List<QueuePatient> get completedPatients =>
      _docsWithStatus('Completed').map(_toQueuePatient).toList();

  // The list currently shown in the right-hand panel, based on the active tab.
  List<QueuePatient> get _activeList =>
      selectedTabIndex == 0 ? waitingPatients : completedPatients;

  // The doctor's patient currently "In Consultation", if any.
  QueuePatient? get currentPatient {
    final list = _docsWithStatus('In Consultation');
    if (list.isEmpty) return null;
    return _toQueuePatient(list.first);
  }

  QueuePatient? get _selectedPatient {
    if (_hasManualSelection &&
        _activeList.isNotEmpty &&
        selectedPatientIndex < _activeList.length) {
      return _activeList[selectedPatientIndex];
    }
    if (selectedTabIndex == 0 && currentPatient != null) return currentPatient;
    if (_activeList.isNotEmpty) return _activeList[0];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          // Top bar: back button + doctor name (admin only; a doctor has the
          // top bar of the doctor dashboard instead)
          if (!widget.doctorMode)
          Container(
            height: 64,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (widget.showBack) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Text(
                    widget.doctorName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_doctorManagesNow) _buildManagedByDoctorChip(),
                if (widget.topBarTrailing != null) widget.topBarTrailing!,
              ],
            ),
          ),

          Expanded(
            child: !_loaded
                ? const LoadingOrOffline()
                : _loadError != null
                    ? Center(
                        child: Text(
                          _loadError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isMobile = constraints.maxWidth < 700;

                          if (isMobile) return _buildMobileLayout();

                          // Original three-column layout:
                          // doctor panel | patient details | queue list
                          final row = Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // A doctor does not need their own photo and
                              // name repeated here.
                              if (!widget.doctorMode) ...[
                                SizedBox(
                                  width: 260,
                                  child: _buildDoctorPanel(),
                                ),
                                Container(width: 1, color: Colors.grey.shade300),
                              ],

                              Expanded(
                                child: _buildPatientDetailsPanel(
                                  isMobile: false,
                                ),
                              ),
                              Container(width: 1, color: Colors.grey.shade300),

                              SizedBox(
                                width: 340,
                                child: _buildQueueListPanel(isMobile: false),
                              ),
                            ],
                          );
                          if (!widget.doctorMode) return row;
                          return Column(
                            children: [
                              _buildDoctorStatusCard(),
                              Expanded(child: row),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    if (widget.doctorMode) {
      return Column(
        children: [
          _buildDoctorStatusCard(),
          _buildMobileToggle(),
          Expanded(
            child: _mobilePanelIndex == 0
                ? _buildQueueListPanel(isMobile: true)
                : _buildPatientDetailsPanel(isMobile: true),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildMobileDoctorStrip(),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _buildMobileToggle(),
        Expanded(
          child: _mobilePanelIndex == 0
              ? _buildQueueListPanel(isMobile: true)
              : _buildPatientDetailsPanel(isMobile: true),
        ),
      ],
    );
  }

  // Doctor mode: one compact status card instead of the old top bar and the
  // repeated doctor name / photo / "Queue n" badge.
  Widget _buildDoctorStatusCard() {
    final bool available = doctor?.status.toLowerCase() == 'available';
    final int waiting = waitingPatients.length;
    final String waitingText =
        waiting == 1 ? '1 patient waiting' : '$waiting patients waiting';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available ? const Color(0xFF2E7D32) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  available ? 'Accepting patients' : 'Not accepting patients',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  waitingText,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (widget.topBarTrailing != null) widget.topBarTrailing!,
        ],
      ),
    );
  }

  Widget _buildMobileDoctorStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (doctor != null) DoctorAvatar(doctor: doctor!),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.department.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "Queue ${waitingPatients.length}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Two-button toggle used only on mobile to switch which single panel
  // (Queue list vs Patient details) currently occupies the screen.
  Widget _buildMobileToggle() {
    return Container(
      color: widget.doctorMode ? Colors.transparent : Colors.white,
      padding: EdgeInsets.fromLTRB(16, widget.doctorMode ? 8 : 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: _buildMobileToggleButton(label: "Queue", index: 0)),
          const SizedBox(width: 10),
          Expanded(child: _buildMobileToggleButton(label: "Details", index: 1)),
        ],
      ),
    );
  }

  Widget _buildMobileToggleButton({required String label, required int index}) {
    final bool isSelected = _mobilePanelIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _mobilePanelIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPurple
              : (widget.doctorMode ? Colors.white : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: widget.doctorMode && !isSelected
              ? Border.all(color: Colors.grey.shade200)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // LEFT PANEL (desktop only): doctor photo, name, department, and
  // waiting-queue count.
  Widget _buildDoctorPanel() {
    if (doctor == null) {
      return const Center(child: Text("Doctor not found"));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.doctorName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Text(
                widget.department.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4,
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  const Text(
                    "Queue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${waitingPatients.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          Center(
            child: DoctorAvatar(doctor: doctor!, size: 280, isCircular: false),
          ),
        ],
      ),
    );
  }

  // Empty list. Admin keeps the old one-line text; a doctor gets a proper
  // centered empty state.
  Widget _buildEmptyState() {
    if (!widget.doctorMode) {
      return Center(
        child: Text(
          "No patients here",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    final bool waitingTab = selectedTabIndex == 0;
    final bool someoneInRoom = waitingTab && currentPatient != null;

    final IconData icon =
        waitingTab ? Icons.task_alt_rounded : Icons.history_rounded;
    final String title = !waitingTab
        ? 'No completed visits yet'
        : someoneInRoom
            ? 'No one else is waiting'
            : 'No patients waiting';
    final String subtitle = !waitingTab
        ? 'Patients you finish seeing today will appear here.'
        : someoneInRoom
            ? 'Open Details to see the patient in consultation.'
            : "You're all caught up.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withValues(alpha: .08),
              ),
              child: Icon(icon, size: 36, color: AppColors.primaryPurple),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // A single "Waiting"/"Completed" tab label with an underline when active.
  Widget _buildTab(String label, int index) {
    final bool isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        selectedTabIndex = index;
        // Reset selection when switching tabs so it doesn't point at
        // an out-of-range index in the new list.
        selectedPatientIndex = 0;
        _hasManualSelection = false;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.primaryPurple
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          if (isSelected)
            Container(
              height: 2,
              width: label.length * (widget.doctorMode ? 7.0 : 6.0),
              color: AppColors.primaryPurple,
            ),
        ],
      ),
    );
  }

  // Waiting/Completed tabs plus the scrollable patient list.
  // Desktop: sits in the fixed 340px right column. Mobile: fills the
  // whole screen when the "Queue" toggle is active.
  Widget _buildQueueListPanel({required bool isMobile}) {
    final activeList = _activeList;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTab(
                widget.doctorMode
                    ? "Waiting (${waitingPatients.length})"
                    : "Waiting",
                0,
              ),
              const SizedBox(width: 20),
              _buildTab(
                widget.doctorMode
                    ? "Completed (${completedPatients.length})"
                    : "Completed",
                1,
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: activeList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: activeList.length,
                    itemBuilder: (context, index) {
                      final patient = activeList[index];
                      final isSelected =
                          _hasManualSelection && index == selectedPatientIndex;

                      return GestureDetector(
                        onTap: () => setState(() {
                          selectedPatientIndex = index;
                          _hasManualSelection = true;
                          // On mobile, jump straight to the Details panel
                          // once a patient is picked from the list.
                          if (isMobile) _mobilePanelIndex = 1;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryPurple.withValues(alpha: .08)
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "TOKEN ${patient.token}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(patient.registrationTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                patient.patientName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                patient.phoneNumber,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Selected patient's full details plus action buttons.
  // Desktop: fields laid out in 3-wide rows (original). Mobile: fields
  // stacked one per line so nothing gets squeezed into an unreadable width.
  Widget _buildPatientDetailsPanel({required bool isMobile}) {
    final patient = _selectedPatient;

    if (patient == null) {
      return Center(
        child: Text(
          "Select a patient to view details",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    final bool isCompleted = patient.status == "Completed";
    final bool isWaiting = patient.status == "Waiting";
    final bool doctorHasCurrent = currentPatient != null;

    // Skip swaps places with the patient behind, so the last waiting
    // patient cannot be skipped.
    final bool isLastWaiting = isWaiting &&
        waitingPatients.isNotEmpty &&
        waitingPatients.last.token == patient.token;

    // Call: any waiting patient, but only when nobody is with the doctor.
    final bool canCall = isWaiting && !doctorHasCurrent;
    final bool canSkip = isWaiting && !isLastWaiting;

    // Short explanations for buttons that are greyed out.
    final List<String> hints = [];
    if (!isCompleted && !isWaiting) {
      hints.add(
        "To call or skip a patient, select a waiting patient from the queue list first.",
      );
    }
    if (isWaiting && doctorHasCurrent) {
      hints.add("Complete the current patient before calling another one.");
    }
    if (isLastWaiting) {
      hints.add(
        "Skip is not available because this patient is last in the queue.",
      );
    }

    final fieldsSection = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReadOnlyField("TOKEN #", patient.token),
              const SizedBox(height: 14),
              _buildDropdownField("STATUS", patient.status),
              const SizedBox(height: 14),
              _buildReadOnlyField("FULL NAME", patient.patientName, bold: true),
              const SizedBox(height: 14),
              _buildReadOnlyField("PHONE NUMBER", patient.phoneNumber),
              const SizedBox(height: 14),
              _buildReadOnlyField(
                "REGISTRATION TIME",
                _formatTime(patient.registrationTime),
              ),
              const SizedBox(height: 14),
              _buildReadOnlyField("DOCTOR", widget.doctorName),
              const SizedBox(height: 14),
              _buildReadOnlyField("DEPARTMENT", widget.department),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildReadOnlyField("TOKEN #", patient.token),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDropdownField("STATUS", patient.status),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildReadOnlyField(
                      "FULL NAME",
                      patient.patientName,
                      bold: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildReadOnlyField(
                      "PHONE NUMBER",
                      patient.phoneNumber,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildReadOnlyField(
                      "REGISTRATION TIME",
                      _formatTime(patient.registrationTime),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildReadOnlyField("DOCTOR", widget.doctorName),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildReadOnlyField("DEPARTMENT", widget.department),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 20),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Patient Details",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 14),
              StatusPill(status: patient.status),
            ],
          ),
          const SizedBox(height: 28),

          fieldsSection,
          const SizedBox(height: 24),

          Text(
            "EST. WAIT",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${patient.estWaitMinutes} min",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 28),

          // Complete / Call Patient / Skip / Cancel — each enabled only
          // when it's a valid action given the doctor's and patient's
          // current state. Wrap already makes these safe on narrow widths.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                label: "Complete",
                bgColor: const Color(0xFF2E7D32),
                textColor: Colors.white,
                enabled: !isCompleted && doctorHasCurrent,
                isLoading: _isCompleting,
                onTap: _handleComplete,
              ),
              _ActionButton(
                label: "Call Patient",
                bgColor: AppColors.primaryPurple,
                textColor: Colors.white,
                enabled: canCall,
                isLoading: _isCallingNext,
                onTap: _handleCallPatient,
              ),
              _ActionButton(
                label: "Skip",
                bgColor: Colors.blueGrey.shade400,
                textColor: Colors.white,
                enabled: canSkip,
                isLoading: _isSkipping,
                onTap: _handleSkip,
              ),
              _ActionButton(
                label: "Cancel",
                bgColor: const Color.fromARGB(255, 255, 80, 80),
                textColor: Colors.white,
                enabled: !isCompleted,
                isLoading: _isCancelling,
                onTap: _handleCancel,
              ),
            ],
          ),

          // Explains why a button is greyed out.
          for (final hint in hints) ...[
            const SizedBox(height: 12),
            Text(
              hint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  // Read-only labeled field, used for details that can't be edited here.
  Widget _buildReadOnlyField(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color.fromARGB(255, 196, 196, 196),
              width: 0.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: const [
                "Waiting",
                "In Consultation",
                "Completed",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                // Not implemented: wire this to a service method
                // to persist a manual status change.
              },
            ),
          ),
        ),
      ],
    );
  }

  // Runs one admin action against Firestore. Shows the button spinner while
  // it runs, and a snackbar if it fails (network, permission, queue changed).
  // Returns true when the action succeeded, false otherwise.
  Future<bool> _perform({
    required void Function(bool loading) setLoading,
    required Future<void> Function(String doctorId) action,
    bool resetSelection = false,
  }) async {
    final id = _doctorId;
    if (id == null) {
      _showSnack("Doctor not found.");
      return false;
    }

    setState(() => setLoading(true));
    try {
      await action(id);
      if (mounted && resetSelection) {
        setState(() {
          selectedPatientIndex = 0;
          _hasManualSelection = false;
        });
      }
      return true;
    } catch (e) {
      _showSnack(_errorText(e));
      return false;
    } finally {
      if (mounted) setState(() => setLoading(false));
    }
  }

  // Asks for confirmation, marks the doctor's current patient as done,
  // resets the detail panel, then tells the patient their visit is complete.
  Future<void> _handleComplete() async {
    final shown = currentPatient;

    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF2E7D32),
      title: 'Complete Consultation',
      message: _withOwnerNote(
        'Mark this consultation as completed? The patient will be notified.',
      ),
      confirmLabel: 'Complete',
      token: shown?.token,
      patientName: shown?.patientName,
    );
    if (!confirmed || !mounted) return;

    // Remember who is being served BEFORE completing, because after
    // completing nobody is "In Consultation" any more.
    final current = currentPatient;
    final inConsultation = _docsWithStatus('In Consultation');
    final entryId = inConsultation.isEmpty ? null : inConsultation.first.id;

    final ok = await _perform(
      setLoading: (v) => _isCompleting = v,
      action: (id) => _service.completeCurrent(id),
      resetSelection: true,
    );

    if (ok && entryId != null && mounted) {
      await notifyAndReport(
        context,
        entryId,
        'completed',
        patientName: current?.patientName ?? '',
        token: current?.token ?? '',
        phone: current?.phoneNumber ?? '',
      );
    }
  }

  // Asks for confirmation, calls the SELECTED waiting patient in (any waiting
  // patient, not only the next one in line), then sends them a push
  // notification.
  Future<void> _handleCallPatient() async {
    final patient = _selectedPatient;
    if (patient == null || patient.status != "Waiting") return;
    final entryId = _entryIdForToken(patient.token);
    if (entryId == null) return;

    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.campaign_outlined,
      color: AppColors.primaryPurple,
      title: 'Call Patient',
      message: _withOwnerNote(
        'Call this patient in to see ${widget.doctorName}? They will be notified.',
      ),
      confirmLabel: 'Call Patient',
      token: patient.token,
      patientName: patient.patientName,
    );
    if (!confirmed || !mounted) return;

    final ok = await _perform(
      setLoading: (v) => _isCallingNext = v,
      action: (id) => _service.callSpecific(id, entryId),
      resetSelection: true,
    );
    if (!ok || !mounted) return;

    await notifyAndReport(
      context,
      entryId,
      'called',
      patientName: patient.patientName,
      token: patient.token,
      phone: patient.phoneNumber,
    );
  }

  // Asks for confirmation, moves the selected waiting patient one place down
  // the queue, keeps the highlight on that patient, confirms to the admin,
  // and notifies the patient.
  Future<void> _handleSkip() async {
    final patient = _selectedPatient;
    if (patient == null) return;
    final entryId = _entryIdForToken(patient.token);
    if (entryId == null) return;

    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.skip_next_rounded,
      color: Colors.blueGrey.shade500,
      title: 'Skip Patient',
      message: _withOwnerNote(
        'Move this patient one place down the queue? They will be notified.',
      ),
      confirmLabel: 'Skip Patient',
      token: patient.token,
      patientName: patient.patientName,
    );
    if (!confirmed || !mounted) return;

    // Row of this patient in the waiting list before skipping.
    final oldIndex = waitingPatients.indexWhere((p) => p.token == patient.token);

    final ok = await _perform(
      setLoading: (v) => _isSkipping = v,
      action: (id) => _service.skip(id, entryId),
    );
    if (!ok || !mounted) return;

    // The patient moved one row down, so move the highlight with them.
    if (oldIndex != -1) {
      setState(() {
        selectedTabIndex = 0;
        selectedPatientIndex = oldIndex + 1;
        _hasManualSelection = true;
      });
    }
    _showInfo('Token ${patient.token} moved down one place.');

    await notifyAndReport(
      context,
      entryId,
      'skipped',
      patientName: patient.patientName,
      token: patient.token,
      phone: patient.phoneNumber,
    );
  }

  // Asks for confirmation, then removes the selected patient from the queue,
  // resets the detail panel and tells the patient their token was cancelled.
  Future<void> _handleCancel() async {
    final patient = _selectedPatient;
    if (patient == null) return;
    final entryId = _entryIdForToken(patient.token);
    if (entryId == null) return;

    final confirmed = await showConfirmActionDialog(
      context,
      icon: Icons.cancel_outlined,
      color: const Color(0xFFE53935),
      title: 'Cancel Token',
      message: _withOwnerNote(
        'This patient will be removed from the queue and notified. This cannot be undone.',
      ),
      confirmLabel: 'Cancel Token',
      cancelLabel: 'Keep Token',
      token: patient.token,
      patientName: patient.patientName,
    );
    if (!confirmed || !mounted) return;

    // Remember who this patient is BEFORE deleting, because after deleting
    // the queue entry no longer exists.
    String? patientId;
    for (final d in _docs) {
      if (d.id == entryId) {
        patientId = d.data()['patientId']?.toString();
        break;
      }
    }

    final ok = await _perform(
      setLoading: (v) => _isCancelling = v,
      action: (id) => _service.cancel(entryId),
      resetSelection: true,
    );

    if (ok && patientId != null && mounted) {
      await notifyAndReport(
        context,
        entryId,
        'cancelled',
        patientId: patientId,
        patientName: patient.patientName,
        token: patient.token,
        phone: patient.phoneNumber,
      );
    }
  }
}

// Reusable action button with hover highlight, disabled state, and
// an inline loading spinner while its action is in progress.
class _ActionButton extends StatefulWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;
  final bool enabled;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Only clickable and hoverable when enabled and not already loading.
    final bool interactive = widget.enabled && !widget.isLoading;

    final Color effectiveBg = !widget.enabled
        ? Colors.grey.shade200
        : isHovered && interactive
        ? Color.lerp(widget.bgColor, Colors.black, 0.1)!
        : widget.bgColor;

    final Color effectiveText = !widget.enabled
        ? Colors.grey.shade400
        : widget.textColor;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (interactive) setState(() => isHovered = true);
      },
      onExit: (_) {
        if (interactive) setState(() => isHovered = false);
      },
      child: GestureDetector(
        onTap: interactive ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: (isHovered && interactive)
                ? [
                    BoxShadow(
                      color: widget.bgColor.withValues(alpha: .35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveText),
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: effectiveText,
                  ),
                ),
        ),
      ),
    );
  }
}