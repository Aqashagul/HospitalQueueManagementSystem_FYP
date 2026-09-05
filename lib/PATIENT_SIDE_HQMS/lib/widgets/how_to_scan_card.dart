import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class HowToScanCard extends StatelessWidget {
  const HowToScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientStart.withValues(alpha: .12),
            AppColors.gradientEnd.withValues(alpha: .05),
          ],
        ),
        border: Border.all(color: AppColors.gradientEnd.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'How to scan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _StepRow(
            number: '1',
            icon: Icons.center_focus_strong_rounded,
            text: 'Open camera and focus on the QR code',
          ),
          const _StepDivider(),
          const _StepRow(
            number: '2',
            icon: Icons.wb_sunny_rounded,
            text: 'Make sure the QR code is well lit and clear',
          ),
          const _StepDivider(),
          const _StepRow(
            number: '3',
            icon: Icons.smartphone_rounded,
            text: 'Hold your device steady while scanning',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;
  const _StepRow({required this.number, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Numbered circle badge
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.gradientEnd.withValues(alpha: .4), width: 1.5),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textDark, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}



class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Container(
        width: 1.5,
        height: 14,
        color: AppColors.gradientEnd.withValues(alpha: .25),
      ),
    );
  }
}