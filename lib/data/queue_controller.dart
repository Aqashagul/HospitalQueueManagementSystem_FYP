import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/patient_model.dart'; 
import 'package:queue_management_system/models/queue_model.dart';

class QueueController {
 
  List<DoctorQueueStatus> getQueues() {
    final patients = AppdataStore().patient;
    final doctorsWithPatients = patients.map((p) => p.doctor).toSet();

    return AppdataStore()
        .doctors
        .where((doc) => doctorsWithPatients.contains(doc.name))
        .map((doc) => _buildQueueStatus(doc.name, doc.department, doc.specialization))
        .toList();
  }


  DoctorQueueStatus _buildQueueStatus(
      String doctorName, String department, String specialization) {
    final docPatients = AppdataStore().patient.where((p) => p.doctor == doctorName);

    final waitingCount = docPatients.where((p) => p.status == "Waiting").length;
    final completedCount = docPatients.where((p) => p.status == "Completed").length;

    String? currentToken;
    final inConsultation = docPatients.where((p) => p.status == "In Consultation");
    if (inConsultation.isNotEmpty) {
      currentToken = inConsultation.first.token;
    }

    return DoctorQueueStatus(
      name: doctorName,
      department: department,
      specialization: specialization,
      currentToken: currentToken,
      waitingCount: waitingCount,
      completedToday: completedCount,
    );
  }

  void completePatient(String doctorName) {
    final patients = AppdataStore().patient;
    final index =
        patients.indexWhere((p) => p.doctor == doctorName && p.status == "In Consultation");
    if (index == -1) return;

    patients[index] = _withStatus(patients[index], "Completed");
  }

  void callNextPatient(String doctorName) {
    final patients = AppdataStore().patient;

    final alreadyServing =
        patients.any((p) => p.doctor == doctorName && p.status == "In Consultation");
    if (alreadyServing) return;

    final index = patients.indexWhere((p) => p.doctor == doctorName && p.status == "Waiting");
    if (index == -1) return;

    patients[index] = _withStatus(patients[index], "In Consultation");
  }

  PatientModel _withStatus(PatientModel p, String newStatus) {
    return PatientModel(
      token: p.token,
      name: p.name,
      department: p.department,
      doctor: p.doctor,
      phoneNumber: p.phoneNumber,
      status: newStatus,
       registrationTime: p.registrationTime, 
    );
  }
}