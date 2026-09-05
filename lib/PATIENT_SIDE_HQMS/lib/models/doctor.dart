class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String departmentId;
  final String departmentName;
  final String imagePath;
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
  });


// Estimated wait time - queue length x average time per patient
  String get estimatedWaitTime {
    final int minutes = currentQueueLength * averageMinutesPerPatient;
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
  }
}



/// Temporary sample data 
final List<Doctor> sampleDoctors = [
  Doctor(
    id: 'doc1',
    name: 'Dr. Amna',
    specialization: 'Cardiologist',
    departmentId: 'd1',
    departmentName: 'Cardiology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_amna.jpg',
    about: 'MBBS, FCPS (Cardiology) with 12 years of experience in treating heart-related conditions.',
    experience: '12 years',
    availability: 'Mon - Fri, 9:00 AM - 2:00 PM',
    tokenPrefix: 'A',
    consultationFee: 'Rs. 2,000',
    averageMinutesPerPatient: 12,
    currentQueueLength: 4,
    isActive: true,
  ),
  Doctor(
    id: 'doc2',
    name: 'Dr. Humza',
    specialization: 'Cardiologist',
    departmentId: 'd1',
    departmentName: 'Cardiology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_hamza.jpg',
    about: 'MBBS, MD, specializing in preventive cardiology and heart health checkups.',
    experience: '6 years',
    availability: 'Mon - Sat, 11:00 AM - 4:00 PM',
    tokenPrefix: 'A',
    consultationFee: 'Rs. 2,500',
    averageMinutesPerPatient: 8,
    currentQueueLength: 2,
    isActive: false,
  ),
  Doctor(
    id: 'doc3',
    name: 'Dr. Hoorain',
    specialization: 'Dermatologist',
    departmentId: 'd2',
    departmentName: 'Dermatologist',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_hoorain.jpg',
    about: 'MBBS, DDV, expert in skin allergies and cosmetic dermatology.',
    experience: '6 years',
    availability: 'Tue - Sun, 10:00 AM - 3:00 PM',
    tokenPrefix: 'B',
    consultationFee: 'Rs. 2,800',
    averageMinutesPerPatient: 10,
    currentQueueLength: 6,
    isActive: true,
  ),
  Doctor(
    id: 'doc4',
    name: 'Dr. Fatima',
    specialization: 'Cardiologist',
    departmentId: 'd1',
    departmentName: 'Cardiology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_fatima.jpg',
    about: 'MBBS, FCPS (Cardiology) with 12 years of experience in treating heart-related conditions.',
    experience: '12 years',
    availability: 'Mon - Fri, 9:00 AM - 2:00 PM',
    tokenPrefix: 'A',
    consultationFee: 'Rs. 2,000',
    averageMinutesPerPatient: 4,
    currentQueueLength: 4,
    isActive: true,
  ),
  Doctor(
    id: 'doc5',
    name: 'Dr. Imran',
    specialization: 'Cardiologist',
    departmentId: 'd1',
    departmentName: 'Cardiology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_imran.jpg',
    about: 'MBBS, FCPS (Cardiology) with 12 years of experience in treating heart-related conditions.',
    experience: '9 years',
    availability: 'Mon - Fri, 9:00 AM - 2:00 PM',
    tokenPrefix: 'A',
    consultationFee: 'Rs. 2,500',
    averageMinutesPerPatient: 5,
    currentQueueLength: 4,
    isActive: true,
  ),
  Doctor(
    id: 'doc6',
    name: 'Dr. Ayesha Khan',
    specialization: 'Neurologist',
    departmentId: 'd3',
    departmentName: 'Neurology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_ayesha.jpg',
    about: 'MBBS, FCPS (Neurology) with 10 years of experience in diagnosing and treating neurological disorders, migraines, and epilepsy.',
    experience: '10 years',
    availability: 'Mon - Fri, 9:00 AM - 2:00 PM',
    tokenPrefix: 'C',
    consultationFee: 'Rs. 3,000',
    averageMinutesPerPatient: 3,
    currentQueueLength: 3,
    isActive: true,
  ),
  Doctor(
    id: 'doc7',
    name: 'Dr. Hashim Ahmed',
    specialization: 'Consultant Neurologist',
    departmentId: 'd3',
    departmentName: 'Neurology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_hashim.jpg',
    about: 'MBBS, MD (Neurology), specializing in stroke management, epilepsy, and disorders of the nervous system.',
    experience: '8 years',
    availability: 'Mon - Sat, 11:00 AM - 4:00 PM',
    tokenPrefix: 'C',
    consultationFee: 'Rs. 3,500',
    averageMinutesPerPatient: 7,
    currentQueueLength: 5,
    isActive: true,
  ),
  Doctor(
    id: 'doc8',
    name: 'Dr. Mahnoor Ali',
    specialization: 'Neurologist',
    departmentId: 'd3',
    departmentName: 'Neurology',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_sana.jpg',
    about: 'MBBS, FCPS (Neurology) with expertise in treating headaches, nerve disorders, Parkinson\u2019s disease, and other neurological conditions.',
    experience: '7 years',
    availability: 'Tue - Sun, 10:00 AM - 3:00 PM',
    tokenPrefix: 'C',
    consultationFee: 'Rs. 3,200',
    averageMinutesPerPatient: 6,
    currentQueueLength: 0,
    isActive: false,
  ),
  Doctor(
    id: 'doc9',
    name: 'Dr. Hassan Raza',
    specialization: 'Orthopedic Surgeon',
    departmentId: 'd5',
    departmentName: 'Orthopedics',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_hassan.jpg',
    about: 'MBBS, FCPS (Orthopedic Surgery) with 11 years of experience in treating bone, joint, and muscle-related conditions, including fractures and sports injuries.',
    experience: '11 years',
    availability: 'Mon - Fri, 9:00 AM - 2:00 PM',
    tokenPrefix: 'E',
    consultationFee: 'Rs. 2,800',
    averageMinutesPerPatient: 4,
    currentQueueLength: 3,
    isActive: true,
  ),
  Doctor(
    id: 'doc10',
    name: 'Dr. Sarah Ahmed',
    specialization: 'Orthopedic Specialist',
    departmentId: 'd5',
    departmentName: 'Orthopedics',
    imagePath: 'assets/images/PATIENT_SIDE images/icons/images/doctors/Dr_sarah.jpg',
    about: 'MBBS, FCPS (Orthopedics), specializing in joint pain, arthritis, spinal conditions, and rehabilitation after orthopedic injuries.',
    experience: '9 years',
    availability: 'Mon - Sat, 11:00 AM - 4:00 PM',
    tokenPrefix: 'E',
    consultationFee: 'Rs. 3,000',
    averageMinutesPerPatient: 5,
    currentQueueLength: 6,
    isActive: true,
  ),
];