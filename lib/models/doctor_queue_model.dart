class QueuePatient {
  final String token;
  final String patientName;
  final String phoneNumber;
  final DateTime registrationTime;
  final String status; // "Waiting" ya "Completed"
   final String doctorName;
  final String department;
  final int estWaitMinutes;

  const QueuePatient({
    required this.token,
    required this.patientName,
    required this.phoneNumber,
    required this.registrationTime,
    required this.doctorName,
  required this.department,
    required this.status,
    required this.estWaitMinutes,
  });
}

