class PatientModel {
  final String token;
  final String name;
  final String department;
  final String doctor;
  final String phoneNumber;
  final String status;
  final DateTime registrationTime;

  const PatientModel({
    required this.token,
    required this.name,
    required this.department,
    required this.doctor,
    required this.phoneNumber,
    required this.status,
    required this.registrationTime,
  });
}
