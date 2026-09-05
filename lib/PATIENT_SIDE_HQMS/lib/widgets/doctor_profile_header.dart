import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/doctor.dart';


class DoctorProfileHeader extends StatelessWidget {
  final Doctor doctor;
  const DoctorProfileHeader({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3.5),
          child: ClipOval(
            child: Container(
              color: Colors.white,
              child: Image.asset(
                doctor.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person_rounded, color: AppColors.primary, size: 50),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          doctor.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          doctor.specialization,
          style: TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (doctor.isActive ? Colors.green : Colors.red).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: doctor.isActive ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                doctor.isActive ? 'Available Now' : 'Unavailable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: doctor.isActive ? Colors.green.shade800 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}