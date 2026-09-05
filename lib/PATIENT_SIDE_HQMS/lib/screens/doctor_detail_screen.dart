import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import '../widgets/doctor_profile_header.dart';
import '../widgets/gradient_stat_card.dart';
import '../widgets/available_timing_card.dart';
import '../widgets/about_doctor_card.dart';
import '../widgets/join_queue_dialog.dart';
import '../models/doctor.dart';
import 'queue_success_screen.dart';

class DoctorDetailScreen extends StatelessWidget {
  final Doctor doctor;
  const DoctorDetailScreen({super.key, required this.doctor});

  Future<void> _handleJoinQueue(BuildContext context) async {
    final bool? confirmed = await showJoinQueueDialog(context, doctor);

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QueueSuccessScreen(doctor: doctor)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Center(child: DoctorProfileHeader(doctor: doctor)),
                  const SizedBox(height: 28),

                  // Gradient highlight row - Patients Ahead, Est. Wait, Fee
                  Row(
                    children: [
                      Expanded(
                        child: GradientStatCard(
                          icon: Icons.groups_2_rounded,
                          label: 'Patients Ahead',
                          value: '${doctor.currentQueueLength}',
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color.fromARGB(255,106,183,183,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,121,170,173,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,199,141,230,).withValues(alpha: 0.80),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientStatCard(
                          icon: Icons.timer_outlined,
                          label: 'Est. Wait Time',
                          value: doctor.estimatedWaitTime,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color.fromARGB(255,200,183,211,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,138,97,169,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,27,113,193,).withValues(alpha: 0.80),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientStatCard(
                          icon: Icons.payments_outlined,
                          label: 'Consultation Fee',
                          value: doctor.consultationFee,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color.fromARGB(255,106,183,183,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,121,170,173,).withValues(alpha: 0.80),
                              const Color.fromARGB(255,199,141,230,).withValues(alpha: 0.80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Available timing - horizontal card
                  AvailableTimingCard(timing: doctor.availability),
                  const SizedBox(height: 20),

                  AboutDoctorCard(about: doctor.about),
                  const SizedBox(height: 32),

                  Opacity(
                    opacity: doctor.isActive ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !doctor.isActive,
                      child: PremiumButton(
                        label: doctor.isActive
                            ? 'Join Queue'
                            : 'Currently Unavailable',
                        onPressed: () => _handleJoinQueue(context),
                      ),
                    ),
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
