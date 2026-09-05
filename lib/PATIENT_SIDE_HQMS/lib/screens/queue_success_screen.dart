import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import '../widgets/animated_success_icon.dart';
import '../widgets/premium_token_card.dart';
import '../widgets/notice_card.dart';
import '../models/doctor.dart';
import 'track_queue_screen.dart';

class QueueSuccessScreen extends StatelessWidget {
  final Doctor doctor;
  const QueueSuccessScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final int position = doctor.currentQueueLength + 1;
    final String tokenNumber =
        '${doctor.tokenPrefix}-${position.toString().padLeft(3, '0')}';

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
                    'You have successfully joined the queue for\n${doctor.name}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  PremiumTokenCard(
                    tokenNumber: tokenNumber,
                    doctorName: doctor.name,
                    patientsAhead: doctor.currentQueueLength,
                    estimatedWaitTime: doctor.estimatedWaitTime,
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
                            position: position,
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
