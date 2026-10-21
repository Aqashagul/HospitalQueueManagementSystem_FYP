import 'package:flutter/material.dart';
import 'package:queue_management_system/widgets/doctor_photo.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import 'app_card_decoration.dart';

class TrackDoctorCard extends StatelessWidget {
  final Doctor doctor;
  const TrackDoctorCard({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
            ),
            child: ClipOval(
              child: DoctorPhoto(doctor: d, width: 52, height: 52),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d.specialization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (d.isActive ? Colors.green : Colors.grey)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              d.isActive ? 'Available' : 'Unavailable',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: d.isActive ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}