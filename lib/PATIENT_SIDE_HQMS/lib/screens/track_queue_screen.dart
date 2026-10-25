import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/doctor_mini_card.dart';
import '../widgets/leave_queue_dialog.dart';
import '../widgets/queue_entry_missing_view.dart';
import '../widgets/queue_number_progress_card.dart';
import '../widgets/track_bottom_bar.dart';
import '../widgets/track_header.dart';
import '../widgets/track_stats_row.dart';
import '../widgets/track_status_hero_card.dart';
import '../widgets/turn_alerts_card.dart';
import 'department_list_screen.dart';

class TrackQueueScreen extends StatefulWidget {
  final Doctor doctor;

  // Firestore document id of this patient's queue entry.
  final String entryId;

  const TrackQueueScreen({
    super.key,
    required this.doctor,
    required this.entryId,
  });

  @override
  State<TrackQueueScreen> createState() => _TrackQueueScreenState();
}

class _TrackQueueScreenState extends State<TrackQueueScreen> {
  final QueueService _queueService = QueueService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _entriesStream;

  bool _notifyEnabled = true;
  bool _leaving = false;

  // Patients ahead when this screen first received data.
  int? _initialAhead;

  @override
  void initState() {
    super.initState();
    _entriesStream = _queueService.watchTodaysEntries(widget.doctor.id);
  }

  // ---------------------------------------------------------------------------
  // Logic (Firebase / queue) - UI is in widgets/
  // ---------------------------------------------------------------------------

  bool _isInConsultation(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'in consultation':
      case 'in-progress':
      case 'in progress':
        return true;
      default:
        return false;
    }
  }

  bool _isCompleted(String? raw) {
    final s = (raw ?? '').toLowerCase();
    return s == 'completed' || s == 'done';
  }

  String _formatWait(int minutes) {
    if (minutes <= 0) return 'Now';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DepartmentListScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLeaveQueue() async {
    final bool? confirmed = await showLeaveQueueDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _leaving = true);
    try {
      await _queueService.leaveQueue(widget.entryId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _leaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave the queue. Try again.')),
      );
      return;
    }

    if (!mounted) return;
    _goHome();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const BackgroundBlobs(),
            SafeArea(
              bottom: false,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _entriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load queue: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData || _leaving) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  // Find this patient's own entry.
                  QueryDocumentSnapshot<Map<String, dynamic>>? mine;
                  for (final d in docs) {
                    if (d.id == widget.entryId) mine = d;
                  }
                  if (mine == null) {
                    return QueueEntryMissingView(onHome: _goHome);
                  }

                  final myData = mine.data();
                  final int mySeq = (myData['seq'] as int?) ?? 0;
                  final String? myStatus = myData['status']?.toString();
                  final String myToken = myData['token']?.toString() ?? '--';

                  // Everyone still in the queue today for this doctor.
                  final active = docs
                      .where((d) => QueueService.isActiveStatus(
                            d.data()['status']?.toString(),
                          ))
                      .toList();

                  final int ahead = active.where((d) {
                    final s = d.data()['seq'];
                    return s is int && s < mySeq;
                  }).length;
                  _initialAhead ??= ahead;
                  final int initial = _initialAhead!;
                  final int position = ahead + 1;

                  // Token currently being served (lowest seq in consultation).
                  final serving = active
                      .where((d) =>
                          _isInConsultation(d.data()['status']?.toString()))
                      .toList()
                    ..sort((a, b) => ((a.data()['seq'] as int?) ?? 0)
                        .compareTo((b.data()['seq'] as int?) ?? 0));
                  final String nowServingToken = serving.isEmpty
                      ? '--'
                      : (serving.first.data()['token']?.toString() ?? '--');

                  final int remainingMinutes =
                      ahead * widget.doctor.averageMinutesPerPatient;

                  final bool myTurn = _isInConsultation(myStatus);
                  final bool done = _isCompleted(myStatus);

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TrackHeader(onBack: _goHome),
                              const SizedBox(height: 18),

                              // 1. Doctor card (original gradient card)
                              DoctorMiniCard(doctor: widget.doctor),
                              const SizedBox(height: 18),

                              // 2. Queue progress (your original widget)
                              QueueNumberProgress(
                                totalInQueue: initial + 1,
                                currentPosition: position,
                              ),
                              const SizedBox(height: 18),

                              // 3. Token / position card
                              TrackStatusHeroCard(
                                myTurn: myTurn,
                                done: done,
                                position: position,
                                ahead: ahead,
                              ),
                              const SizedBox(height: 16),

                              // 4. Your Token, Now Serving, Est. Wait
                              TrackStatsRow(
                                yourToken: myToken,
                                nowServing: nowServingToken,
                                estWait: (myTurn || done)
                                    ? '--'
                                    : _formatWait(remainingMinutes),
                              ),
                              const SizedBox(height: 14),

                              TurnAlertsCard(
                                value: _notifyEnabled,
                                onChanged: (v) =>
                                    setState(() => _notifyEnabled = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TrackBottomBar(
                        showLeave: !myTurn && !done,
                        onLeave: _handleLeaveQueue,
                        onHome: _goHome,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}