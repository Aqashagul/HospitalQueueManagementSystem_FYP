
class Department {
  final String id;
  final String name;
  final String iconPath;

  Department({
    required this.id,
    required this.name,
    required this.iconPath,
  });
}

/// Temporary sample data
final List<Department> sampleDepartments = [
  Department(id: 'd1', name: 'Cardiology', iconPath: 'assets/images/PATIENT_SIDE images/icons/cardiology.png'),
  Department(id: 'd3', name: 'Neurology', iconPath: 'assets/images/PATIENT_SIDE images/icons/neurology.png'),
  Department(id: 'd5', name: 'Orthopedic', iconPath: 'assets/images/PATIENT_SIDE images/icons/orthopedics.png'),
  Department(id: 'd2', name: 'Dermatology', iconPath: 'assets/images/PATIENT_SIDE images/icons/dermatology.png'),
  Department(id: 'd8', name: 'Eye Care', iconPath: 'assets/images/PATIENT_SIDE images/icons/ophthalmology.png'),
  Department(id: 'd7', name: 'Dental', iconPath: 'assets/images/PATIENT_SIDE images/icons/dentistry.png'),
  Department(id: 'd6', name: 'Pediatrics', iconPath: 'assets/images/PATIENT_SIDE images/icons/pediatrics.png'),
  Department(id: 'd4', name: 'General Medicine', iconPath: 'assets/images/PATIENT_SIDE images/icons/general_medicine.png'),
];