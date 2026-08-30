
class DoctorQueueStatus {
  final String name;
  final String department;
  final String specialization;
  final String? currentToken; // null/"--" means no patient
  final int waitingCount;
  final int completedToday;
 

  const DoctorQueueStatus({
    required this.name,
    required this.department,
    required this.specialization,
    this.currentToken,
    required this.waitingCount,
    required this.completedToday,
   
  });
}