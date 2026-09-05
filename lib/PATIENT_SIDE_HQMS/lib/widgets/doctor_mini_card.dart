import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/doctor.dart';

class DoctorMiniCard extends StatelessWidget {
  final Doctor doctor;
  const DoctorMiniCard({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color.fromARGB(255, 106, 183, 183).withValues(alpha: 0.80),
      const Color.fromARGB(255, 121, 170, 173).withValues(alpha: 0.80),
      const Color.fromARGB(255, 199, 141, 230).withValues(alpha: 0.80),
    ],
  ),
               boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Container(
                color: Colors.white,
                child: Image.asset(
                  doctor.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.departmentName,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          // Live doctor status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (doctor.isActive ? Colors.green : Colors.orange).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: doctor.isActive ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  doctor.isActive ? 'Available' : 'On Break',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: doctor.isActive ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}