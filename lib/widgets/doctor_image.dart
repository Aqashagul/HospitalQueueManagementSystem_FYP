import 'package:flutter/material.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';

class DoctorAvatar extends StatelessWidget {
  final DoctorModel doctor;
  final double size;
  final bool isCircular;

  const DoctorAvatar({
    super.key,
    required this.doctor,
    this.size = 49,
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: uploaded photo > asset photo > initials fallback
    ImageProvider? imageProvider;
    if (doctor.photoBytes != null) {
      imageProvider = MemoryImage(doctor.photoBytes!);
    } else if (doctor.photoAssetPath != null) {
      imageProvider = AssetImage(doctor.photoAssetPath!);
    }

    if (imageProvider != null) {
      if (isCircular) {
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: imageProvider,
        );
      }

      // Non-circular version: rounded-square image
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return InitialsAvatar(name: doctor.name);
  }
}