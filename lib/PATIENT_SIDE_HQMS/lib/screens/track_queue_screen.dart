import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/doctor_mini_card.dart';
import '../widgets/queue_number_progress_card.dart';
import '../widgets/notify_toggle_card.dart';
import '../widgets/secondary_button.dart';
import '../widgets/leave_queue_dialog.dart';
import '../models/doctor.dart';
import '../widgets/queue_progress_card.dart';

class TrackQueueScreen extends StatefulWidget {
  final Doctor doctor;
  final int position;

  const TrackQueueScreen({
    super.key,
    required this.doctor,
    required this.position,
  });

  @override
  State<TrackQueueScreen> createState() => _TrackQueueScreenState();
}

class _TrackQueueScreenState extends State<TrackQueueScreen> {
  late int _currentPosition;
  late int _totalAheadAtStart;
  bool _notifyEnabled = true;
  Timer? _simulationTimer;
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing)
      return; 

    setState(() => _isRefreshing = true);

    
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Queue status updated'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
    _totalAheadAtStart = widget.position - 1;

   
    _simulationTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_currentPosition <= 1) {
        timer.cancel();
        return;
      }
      setState(() => _currentPosition--);
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  // ignore: unused_element
  int get _timelineStep {
    if (_currentPosition > 1) return 0; // Waiting
    return 1; // Called / your turn
  }

  Future<void> _handleLeaveQueue() async {
    final bool? confirmed = await showLeaveQueueDialog(context);
    if (confirmed == true && mounted) {
     
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nowServingToken =
        '${widget.doctor.tokenPrefix}-${(_currentPosition > 1 ? 1 : 0).toString().padLeft(3, '0')}';
    final int remainingMinutes =
        (_currentPosition - 1) * widget.doctor.averageMinutesPerPatient;
    final String estimatedWait = remainingMinutes < 60
        ? '$remainingMinutes min'
        : '${remainingMinutes ~/ 60}h ${remainingMinutes % 60}m';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                      GestureDetector(
                        onTap: _handleRefresh,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: _isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  DoctorMiniCard(doctor: widget.doctor),
                  const SizedBox(height: 22),

                  QueueNumberProgress(
                    totalInQueue:
                        widget.position, 
                    currentPosition: _currentPosition,
                  ),
                  const SizedBox(height: 22),

                  QueueProgressCard(
                    position: _currentPosition,
                    totalAheadAtStart: _totalAheadAtStart,
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
                    gradientColors: [Colors.red.shade100, Colors.red.shade200],
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
