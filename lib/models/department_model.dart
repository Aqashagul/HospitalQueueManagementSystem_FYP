class Department {
  final String name;
  final String head;
  final int assignedDoctors;
  final String status; // Active | Inactive
  final String createdDate;

  const Department({
    required this.name,
    required this.head,
    required this.assignedDoctors,
    required this.status,
    required this.createdDate
  });
}
