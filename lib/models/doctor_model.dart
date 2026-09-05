
import 'dart:typed_data';

class DoctorModel {
  final String name;
  final String specialization;
  final String department;
  final int patientsCount;
  final String status;
  final Uint8List? photoBytes;
  final String? photoAssetPath;
  final String? experience;     
  final String? workingHours;     
  final String? qualification;    
  final String? tokenPrefix;     
   final int fee; 

  const DoctorModel({
    required this.name,
    required this.specialization,
    required this.department,
    required this.patientsCount,
    required this.status,
    this.photoBytes,
    this.photoAssetPath,
    this.experience,       
    this.workingHours,     
    this.qualification,    
    this.tokenPrefix,   
    required this.fee,   
  });
}
