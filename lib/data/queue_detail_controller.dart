import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/patient_model.dart'; 

class PatientDetailQueueController {
 
  void _updateStatus(String token, String newStatus) {
    final patients = AppdataStore().patient;
    final index = patients.indexWhere((p) => p.token == token);
    if (index == -1) return;

    final p = patients[index];
    patients[index] = PatientModel(
      token: p.token,
      name: p.name,
      department: p.department,
      doctor: p.doctor,
      phoneNumber: p.phoneNumber,
      status: newStatus,
      registrationTime: DateTime.now()
    );
  }

  // 1. Complete 
  void completePatient(String token) {
    _updateStatus(token, "Completed");
  }

  //  2. Call Next 
  void callNextPatient(String doctorName) {
    final patients = AppdataStore().patient;

    // Agar pehle se koi current patient hai, pehle usse finish karna zaroori hai
    final alreadyServing =
        patients.any((p) => p.doctor == doctorName && p.status == "In Consultation");
    if (alreadyServing) return;

    final index = patients.indexWhere((p) => p.doctor == doctorName && p.status == "Waiting");
    if (index == -1) return;

    final p = patients[index];
    patients[index] = PatientModel(
      token: p.token,
      name: p.name,
      department: p.department,
      doctor: p.doctor,
      phoneNumber: p.phoneNumber,
      status: "In Consultation",
      registrationTime: DateTime.now()
    );
  }

  // Doctor-level checks 
  bool hasCurrentPatient(String doctorName) {
    return AppdataStore()
        .patient
        .any((p) => p.doctor == doctorName && p.status == "In Consultation");
  }

  bool hasWaitingPatient(String doctorName) {
    return AppdataStore().patient.any((p) => p.doctor == doctorName && p.status == "Waiting");
  }

  // Skip 
  void moveDownOnePosition(String token) {
    final patients = AppdataStore().patient;
    final index = patients.indexWhere((p) => p.token == token);

    
    if (index == -1 || index == patients.length - 1) return;

    // Is patient ko aur uske turant baad wale ko swap kar diya
    final temp = patients[index];
    patients[index] = patients[index + 1];
    patients[index + 1] = temp;
  }

  //  4. Cancel 
  void cancelPatient(String token) {
    _updateStatus(token, "Cancelled");
  }

  // 5. Finish Serving 
  void finishServing(String doctorName) {
    final patients = AppdataStore().patient;
    final index =
        patients.indexWhere((p) => p.doctor == doctorName && p.status == "In Consultation");
    if (index == -1) return;

    final p = patients[index];
    patients[index] = PatientModel(
      token: p.token,
      name: p.name,
      department: p.department,
      doctor: p.doctor,
      phoneNumber: p.phoneNumber,
      status: "Completed",
      registrationTime: DateTime.now()
    );
  }
} 

