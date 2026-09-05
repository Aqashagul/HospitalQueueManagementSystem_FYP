import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AboutDoctorCard extends StatelessWidget {
  final String about;
  const AboutDoctorCard({super.key, required this.about});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              const Text(
                'About Doctor',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(about, style: TextStyle(fontSize: 13.5, color: AppColors.textGrey, height: 1.6)),
        ],
      ),
    );
  }
}