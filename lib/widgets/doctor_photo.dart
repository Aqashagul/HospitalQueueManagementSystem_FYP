import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/models/doctor.dart';
import 'package:queue_management_system/core/app_color.dart';

class DoctorPhoto extends StatelessWidget {
  final Doctor doctor;
  final double? width;
  final double? height;
  final BoxFit fit;

  const DoctorPhoto({
    super.key,
    required this.doctor,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  // Initials without the "Dr." prefix, e.g. "Dr.Sana Khan" -> "SK".
  String get _initials {
    final cleaned = doctor.name.replaceFirst(
      RegExp(r'^\s*dr\.?\s*', caseSensitive: false),
      '',
    );
    final words = cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Widget _initialsBox() {
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = doctor.photoBytes;

    // 1. Picture uploaded by the admin.
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        // Keeps the old picture on screen while a rebuild decodes the new
        // one, so the picture does not flicker when the store updates.
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _initialsBox(),
      );
    }

    // 2. Bundled asset picture.
    if (doctor.imagePath.isNotEmpty) {
      return Image.asset(
        doctor.imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _initialsBox(),
      );
    }

    // 3. No picture at all.
    return _initialsBox();
  }
}