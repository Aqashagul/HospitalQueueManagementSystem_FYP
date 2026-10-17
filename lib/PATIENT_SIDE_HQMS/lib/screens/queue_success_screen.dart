import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/animated_success_icon.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/notice_card.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/premium_token_card.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import 'track_queue_screen.dart';


class QueueSuccessScreen extends StatelessWidget {
  final Doctor doctor;

  // The real result from QueueService.joinQueue (token saved in Firestore).
  final JoinedQueueResult result;

  const QueueSuccessScreen({
    super.key,
    required this.doctor,
    required this.result,
  });

  // Formats minutes like "25 min" or "1h 10m".
  String _formatWait(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final int waitMinutes =
        result.patientsAhead * doctor.averageMinutesPerPatient;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const AnimatedSuccessIcon(),
                  const SizedBox(height: 24),

                  const Text(
                    'Queue Joined Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have successfully joined the queue for\n'
                    '${result.doctorName} (${result.department}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  PremiumTokenCard(
                    tokenNumber: result.token,
                    doctorName: result.doctorName,
                    patientsAhead: result.patientsAhead,
                    estimatedWaitTime: _formatWait(waitMinutes),
                  ),
                  const SizedBox(height: 20),

                  const NoticeCard(
                    icon: Icons.notifications_active_rounded,
                    title: 'Stay Updated!',
                    message:
                        'You will receive a notification when your turn is near. '
                        'Please arrive at least 5 minutes before your estimated '
                        'consultation time.',
                  ),
                  const SizedBox(height: 32),

                  PremiumButton(
                    label: 'Track Queue',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => TrackQueueScreen(
                            doctor: doctor,
                            entryId: result.entryId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
