import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/doctor_mini_card.dart';
import '../widgets/queue_number_progress_card.dart';
import '../widgets/notify_toggle_card.dart';
import '../widgets/secondary_button.dart';
import '../widgets/leave_queue_dialog.dart';
import '../models/doctor.dart';
import '../widgets/queue_progress_card.dart';
import 'department_list_screen.dart';
import 'qr_scan_screen.dart';


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

  // Patients ahead when this screen first received data (for the progress bar).
  int? _initialAhead;

  @override
  void initState() {
    super.initState();
    _entriesStream = _queueService.watchTodaysEntries(widget.doctor.id);
  }

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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DepartmentListScreen()),
      (route) => false, // clear the whole old history
    );
  }

  // Shown when this patient's entry no longer exists in today's queue.
  Widget _buildEntryMissing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This queue entry is no longer active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Back to Home',
              icon: Icons.home_rounded,
              gradientColors: [
                AppColors.gradientStart.withValues(alpha: .3),
                AppColors.gradientEnd.withValues(alpha: .3),
              ],
              textColor: AppColors.primary,
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const QRScanScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
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
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final docs = snapshot.data!.docs;

                // Find this patient's own entry.
                QueryDocumentSnapshot<Map<String, dynamic>>? mine;
                for (final d in docs) {
                  if (d.id == widget.entryId) mine = d;
                }
                if (mine == null) return _buildEntryMissing();

                final myData = mine.data();
                final int mySeq = (myData['seq'] as int?) ?? 0;
                final String? myStatus = myData['status']?.toString();

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
                final String estimatedWait = remainingMinutes < 60
                    ? '$remainingMinutes min'
                    : '${remainingMinutes ~/ 60}h ${remainingMinutes % 60}m';

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Track Queue',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          // The screen updates live, so there is no refresh button.
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_isInConsultation(myStatus))
                        _statusBanner(
                          "It's your turn. Please go to the doctor.",
                          Colors.green.shade700,
                        )
                      else if (_isCompleted(myStatus))
                        _statusBanner(
                          'Your consultation is completed.',
                          AppColors.primary,
                        ),

                      DoctorMiniCard(doctor: widget.doctor),
                      const SizedBox(height: 22),

                      QueueNumberProgress(
                        totalInQueue: _initialAhead! + 1,
                        currentPosition: position,
                      ),
                      const SizedBox(height: 22),

                      QueueProgressCard(
                        position: position,
                        totalAheadAtStart: _initialAhead!,
                        nowServingToken: nowServingToken,
                        estimatedWaitTime: estimatedWait,
                      ),
                      const SizedBox(height: 18),

                      NotifyToggleCard(
                        isEnabled: _notifyEnabled,
                        onChanged: (value) =>
                            setState(() => _notifyEnabled = value),
                      ),
                      const SizedBox(height: 28),

                      SecondaryButton(
                        label: 'Leave Queue',
                        icon: Icons.logout_rounded,
                        gradientColors: [
                          Colors.red.shade100,
                          Colors.red.shade200,
                        ],
                        textColor: Colors.red.shade700,
                        onPressed: _handleLeaveQueue,
                      ),
                      const SizedBox(height: 12),

                      SecondaryButton(
                        label: 'Back to Home',
                        icon: Icons.home_rounded,
                        gradientColors: [
                          AppColors.gradientStart.withValues(alpha: .3),
                          AppColors.gradientEnd.withValues(alpha: .3),
                        ],
                        textColor: AppColors.primary,
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const QRScanScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}