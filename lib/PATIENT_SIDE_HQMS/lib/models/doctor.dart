import 'dart:typed_data';

class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String departmentId;
  final String departmentName;
  final String imagePath;

  // The picture the admin uploaded (comes from Firestore). Null when the
  // doctor has no uploaded picture, then imagePath is used instead.
  final Uint8List? photoBytes;
  final String about;
  final String experience;
  final String availability;
  final String tokenPrefix;
  final String consultationFee;
  final int averageMinutesPerPatient;
  final int currentQueueLength;
  final bool isActive;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.departmentId,
    required this.departmentName,
    required this.imagePath,
    required this.about,
    required this.experience,
    required this.availability,
    required this.tokenPrefix,
    required this.consultationFee,
    this.averageMinutesPerPatient = 10,
    this.currentQueueLength = 0,
    this.isActive = true,
    this.photoBytes,
  });

  // Estimated wait time - queue length x average time per patient
  String get estimatedWaitTime {
    final int minutes = currentQueueLength * averageMinutesPerPatient;
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }
}

