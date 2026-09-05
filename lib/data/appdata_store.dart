import 'package:flutter/material.dart';
import 'package:queue_management_system/models/department_model.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/models/doctor_queue_model.dart';
import 'package:queue_management_system/models/patient_model.dart';
import 'package:queue_management_system/models/queue_model.dart';

class AppdataStore extends ChangeNotifier {
  //Singleton class
  AppdataStore._internal();
  static final AppdataStore _instance = AppdataStore._internal();
  factory AppdataStore() => _instance; //returns the existing

  //Department List
  final List<Department> departments = [
    Department(
      name: "Cardiology",
      head: "Dr.Sana",
      assignedDoctors: 3,
      status: "Active",
      createdDate: "July, 29, 2026",
    ),

    Department(
      name: "General Medicine",
      head: "Dr.Ayaz",
      assignedDoctors: 6,
      status: "Active",
      createdDate: "Aug, 1, 2026",
    ),

    Department(
      name: "Dermatology",
      head: "Dr.Imran",
      assignedDoctors: 3,
      status: "Active",
      createdDate: "Aug, 1, 2026",
    ),
  ];

  void addDepartment(Department dept) {
    departments.add(dept);
  }

  void removeDepartment(Department dept) {
    departments.remove(dept);
  }

  final List<DoctorModel> doctors = [
    DoctorModel(
      name: "Dr.Sana",
      specialization: "Cardiologist",
      department: "Cardiology",
      patientsCount: 3,
      status: "Available",
      photoAssetPath: "assets/images/Dr_sana.jpg",
      experience: "12 Years",
      workingHours: "9:00 AM - 5:00 PM",
      qualification: "MBBS, FCPS (Cardiology)",
      tokenPrefix: "A",
      fee: 2500
    ),

DoctorModel(
      name: "Dr.Amna Siddiqui",
      specialization: "Internal Medicine",
      department: "General Medicine",
      patientsCount: 7,
      status: "Available",
      photoAssetPath: "assets/images/Dr_amna.jpg",
      experience: "6 Years",
      workingHours: "10:00 AM - 6:00 PM",
      qualification: "MBBS, MD",
      tokenPrefix: "F",
        fee: 1500
    ),

    DoctorModel(
      name: "Dr.Sarah",
      specialization: "Cardiac Surgeon",
      department: "Cardiology",
      patientsCount: 2,
      status: "Available",
      photoAssetPath: "assets/images/Dr_sarah.jpg",
      experience: "10 Years",
      workingHours: "10:00 AM - 6:00 PM",
      qualification: "MBBS, FRCS",
      tokenPrefix: "D",
        fee: 2000
    ),
    DoctorModel(
      name: "Dr.Hamza",
      specialization: "Cardiologist",
      department: "Cardiology",
      patientsCount: 1,
      status: "Available",
      photoAssetPath: "assets/images/Dr_hamza.jpg",
      experience: "8 Years",
      workingHours: "8:00 AM - 4:00 PM",
      qualification: "MBBS, FCPS",
      tokenPrefix: "C",
        fee: 1000
    ),
   
    DoctorModel(
      name: "Dr.Hashim",
      specialization: "General Physician",
      department: "General Medicine",
      patientsCount: 3,
      status: "Available",
      photoAssetPath: "assets/images/Dr_hashim.jpg",
      experience: "10 Years",
      workingHours: "9:00 AM - 5:00 PM",
      qualification: "MBBS, FCPS",
      tokenPrefix: "B",
        fee: 2000
    ),
    DoctorModel(
      name: "Dr.hoorain",
      specialization: "Medicine",
      department: "General Medicine", 
      patientsCount: 5,
      status: "Available",
      photoAssetPath: "assets/images/Dr_hoorain.jpg",
      experience: "15 Years",
      workingHours: "8:00 AM - 4:00 PM",
      qualification: "MBBS, MD",
      tokenPrefix: "E",
        fee: 1200
    ),

    DoctorModel(
      name: "Dr.Areeba",
      specialization: "Cosmetics",
      department: "Dermatology", // FIXED
      patientsCount: 0,
      status: "Available",
      photoAssetPath: "assets/images/Dr_areba.jpg",
      experience: "4 Years",
      workingHours: "1:00 PM - 9:00 PM",
      qualification: "MBBS, MD (Derma)",
      tokenPrefix: "J",
        fee: 1300
    ),
    
    DoctorModel(
      name: "Dr.Fatima Noor",
      specialization: "Family Medicine",
      department: "General Medicine",
      patientsCount: 1,
      status: "Available",
      photoAssetPath: "assets/images/Dr_fatima.jpg",
      experience: "8 Years",
      workingHours: "10:00 AM - 5:00 PM",
      qualification: "MBBS, DCH",
      tokenPrefix: "G",
        fee: 500
    ),
    DoctorModel(
      name: "Dr.Usman Tariq",
      specialization: "General Physician",
      department: "General Medicine",
      patientsCount: 0,
      status: "Available",
      photoAssetPath: "assets/images/Dr_usman.jpg",
      experience: "9 Years",
      workingHours: "11:00 AM - 7:00 PM",
      qualification: "MBBS, FCPS",
      tokenPrefix: "H",
        fee: 500
    ),
    DoctorModel(
      name: "Dr.Zainab Hussain",
      specialization: "Dermatologist",
      department: "Dermatology", // FIXED (pehle "Dermatologist")
      patientsCount: 3,
      status: "Available",
      photoAssetPath: "assets/images/Dr_zainab.jpg",
      experience: "5 Years",
      workingHours: "12:00 PM - 8:00 PM",
      qualification: "MBBS, DDVL",
      tokenPrefix: "I",
        fee: 700
    ),
   
    DoctorModel(
      name: "Dr.Imran",
      specialization: "Dermatologist",
      department: "Dermatology", // FIXED
      patientsCount: 0,
      status: "Available",
      photoAssetPath: "assets/images/Dr_imran.jpg",
      experience: "10 Years",
      workingHours: "9:00 AM - 5:00 PM",
      qualification: "MBBS, DDVL",
      tokenPrefix: "K",
        fee: 1000
    ),
     DoctorModel(
      name: "Dr.Rubina",
      specialization: "General Physician",
      department: "General Medicine",
      patientsCount: 0,
      status: "Unavailable",
      photoAssetPath: "assets/images/Dr_rubab.jpg",
      experience: "6 Years",
      workingHours: "11:00 AM - 7:00 PM",
      qualification: "MBBS",
      tokenPrefix: "R",
        fee: 800
    ),
  ];

  final List<PatientModel> patient = [
    // ---- Dr.Sana (3) ----
    PatientModel(
      token: "A-001",
      name: "Sahil",
      department: "Cardiology",
      doctor: "Dr.Sana",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    PatientModel(
      token: "A-002",
      name: "Afifa",
      department: "Cardiology",
      doctor: "Dr.Sana",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 1, minutes: 30),
      ),
    ),
    PatientModel(
      token: "A-003",
      name: "Hoorain",
      department: "Cardiology",
      doctor: "Dr.Sana",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 20)),
    ),

    // ---- Dr.Sarah (2) ----
    PatientModel(
      token: "D-001",
      name: "Arooba",
      department: "Cardiology",
      doctor: "Dr.Sarah",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 4, minutes: 10),
      ),
    ),
    PatientModel(
      token: "D-002",
      name: "Ashish",
      department: "Cardiology",
      doctor: "Dr.Sarah",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(hours: 1)),
    ),

    // ---- Dr.Hamza (1) ----
    PatientModel(
      token: "C-001",
      name: "Sorab",
      department: "Cardiology",
      doctor: "Dr.Hamza",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 5, minutes: 20),
      ),
    ),

    // ---- Dr.Rubina (0) — koi patient nahi ----

    // ---- Dr.Hashim (3) ----
    PatientModel(
      token: "B-001",
      name: "Rumi",
      department: "General Medicine",
      doctor: "Dr.Hashim",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    PatientModel(
      token: "B-002",
      name: "Akansha",
      department: "General Medicine",
      doctor: "Dr.Hashim",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 44)),
    ),
    PatientModel(
      token: "B-003",
      name: "Alina",
      department: "General Medicine",
      doctor: "Dr.Hashim",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(hours: 4)),
    ),

    // ---- Dr.Hoorain (5) ----
    PatientModel(
      token: "E-001",
      name: "Zohaib",
      department: "General Medicine",
      doctor: "Dr.Hoorain",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    PatientModel(
      token: "E-002",
      name: "Mehak",
      department: "General Medicine",
      doctor: "Dr.Hoorain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    PatientModel(
      token: "E-003",
      name: "Farhan",
      department: "General Medicine",
      doctor: "Dr.Hoorain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    PatientModel(
      token: "E-004",
      name: "Sundas",
      department: "General Medicine",
      doctor: "Dr.Hoorain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 1, minutes: 10),
      ),
    ),
    PatientModel(
      token: "E-005",
      name: "Danish",
      department: "General Medicine",
      doctor: "Dr.Hoorain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(hours: 2)),
    ),

    // ---- Dr.Amna Siddiqui (7) ----
    PatientModel(
      token: "F-001",
      name: "Hina",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    PatientModel(
      token: "F-002",
      name: "bushra",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    PatientModel(
      token: "F-003",
      name: "Nimra",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 26)),
    ),
    PatientModel(
      token: "F-004",
      name: "Talha",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    PatientModel(
      token: "F-005",
      name: "Sana Batool",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    PatientModel(
      token: "F-006",
      name: "Owais",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 1, minutes: 5),
      ),
    ),
    PatientModel(
      token: "F-007",
      name: "Rida",
      department: "General Medicine",
      doctor: "Dr.Amna Siddiqui",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(
        const Duration(hours: 1, minutes: 40),
      ),
    ),

    // ---- Dr.Fatima Noor (1) ----
    PatientModel(
      token: "G-001",
      name: "Bilal Yousuf",
      department: "General Medicine",
      doctor: "Dr.Fatima Noor",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 12)),
    ),

    // ---- Dr.Usman Tariq (0) — koi patient nahi ----

    // ---- Dr.Zainab Hussain (3) ----
    PatientModel(
      token: "I-001",
      name: "Komal",
      department: "Dermatology",
      doctor: "Dr.Zainab Hussain",
      phoneNumber: "9222222222",
      status: "In Consultation",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    PatientModel(
      token: "I-002",
      name: "Rayan",
      department: "Dermatology",
      doctor: "Dr.Zainab Hussain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 22)),
    ),
    PatientModel(
      token: "I-003",
      name: "Anum",
      department: "Dermatology",
      doctor: "Dr.Zainab Hussain",
      phoneNumber: "9222222222",
      status: "Waiting",
      registrationTime: DateTime.now().subtract(const Duration(minutes: 33)),
    ),

    // ---- Dr.Areeba (0) — koi patient nahi ----
    // ---- Dr.Imran (0) — koi patient nahi ----
  ];
  void addPatients(Department dept) {
    departments.add(dept);
  }

  void removePatients(Department dept) {
    departments.remove(dept);
  }

  final List<DoctorQueueStatus> queues = const [
    DoctorQueueStatus(
      name: "Dr.Sana",
      specialization: "Cardiology",
      currentToken: "A-002",
      waitingCount: 2,
      department: "Cardiology",
      completedToday: 0,
    ),

    DoctorQueueStatus(
      name: "Dr.Sarah",
      specialization: "Cardiology",
      currentToken: "D-001",
      department: "Cardiology",
      waitingCount: 1,
      completedToday: 0,
    ),

    DoctorQueueStatus(
      name: "Dr.Hamza",
      specialization: "Cardiology",
      currentToken: "--",
      waitingCount: 1,
      department: "Cardiology",
      completedToday: 0,
    ),

    DoctorQueueStatus(
      name: "Dr.Hashim",
      specialization: "General Medicine",
      currentToken: "--",
      waitingCount: 3,
      department: "General Medicine",
      completedToday: 0,
    ),
  ];

  final List<QueuePatient> doctorQueueData = [
    // DR. SANA
    QueuePatient(
      token: "A-001",
      status: "Waiting",
      patientName: "Sahil",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 30),
      doctorName: "Dr.Sana",
      department: "Cardiology",
      estWaitMinutes: 15,
    ),

    QueuePatient(
      token: "A-002",
      status: "In Consultation",
      patientName: "Afifa",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 35),
      doctorName: "Dr.Sana",
      department: "Cardiology",
      estWaitMinutes: 0,
    ),

    QueuePatient(
      token: "A-003",
      status: "Waiting",
      patientName: "Hoorain",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 40),
      doctorName: "Dr.Sana",
      department: "Cardiology",
      estWaitMinutes: 30,
    ),

    // DR. SARAH
    QueuePatient(
      token: "D-001",
      status: "In Consultation",
      patientName: "Arooba",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 40),
      doctorName: "Dr.Sarah",
      department: "Cardiology",
      estWaitMinutes: 0,
    ),

    QueuePatient(
      token: "D-002",
      status: "Waiting",
      patientName: "Ashish",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 45),
      doctorName: "Dr.Sarah",
      department: "Cardiology",
      estWaitMinutes: 15,
    ),

    //  DR. HAMZA
    QueuePatient(
      token: "C-001",
      status: "Waiting",
      patientName: "Sorab",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 50),
      doctorName: "Dr.Hamza",
      department: "Cardiology",
      estWaitMinutes: 0,
    ),

    // DR. HASHIM
    QueuePatient(
      token: "B-001",
      status: "Waiting",
      patientName: "Rumi",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 25),
      doctorName: "Dr.Hashim",
      department: "General Medicine",
      estWaitMinutes: 15,
    ),

    QueuePatient(
      token: "B-002",
      status: "Waiting",
      patientName: "Akansha",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 35),
      doctorName: "Dr.Hashim",
      department: "General Medicine",
      estWaitMinutes: 30,
    ),

    QueuePatient(
      token: "B-003",
      status: "Waiting",
      patientName: "Alina",
      phoneNumber: "9222222222",
      registrationTime: DateTime(2026, 8, 13, 12, 45),
      doctorName: "Dr.Hashim",
      department: "General Medicine",
      estWaitMinutes: 45,
    ),
  ];

  // ===== Token generation =====

  // Tracks each doctor's assigned letter prefix. Populated lazily from
  // existing patient tokens (including seed/dummy data) the first time
  // a token is generated, so old and new tokens never collide.
  final Map<String, String> _doctorPrefixes = {};

  // Tracks the next sequence number to hand out per doctor. Only ever
  // increases, so a deleted/cancelled patient's number is never reused.
  final Map<String, int> _doctorTokenCounters = {};

  bool _tokenMapsInitialized = false;

  // Scans existing patients once to learn which prefix each doctor already
  // uses and what their highest sequence number is so far. This makes sure
  // hardcoded/dummy tokens and freshly generated ones stay consistent.
  void _initTokenMapsIfNeeded() {
    if (_tokenMapsInitialized) return;
    _tokenMapsInitialized = true;

    for (final p in patient) {
      final parts = p.token.split('-');
      if (parts.length != 2) continue;

      final prefix = parts[0];
      final sequence = int.tryParse(parts[1]) ?? 0;

      // First token seen for this doctor decides their permanent prefix.
      _doctorPrefixes.putIfAbsent(p.doctor, () => prefix);

      final currentMax = _doctorTokenCounters[p.doctor] ?? 0;
      if (sequence > currentMax) {
        _doctorTokenCounters[p.doctor] = sequence;
      }
    }
  }

  String _doctorPrefix(String doctorName) {
    _initTokenMapsIfNeeded();

    if (_doctorPrefixes.containsKey(doctorName)) {
      return _doctorPrefixes[doctorName]!;
    }

    // Brand-new doctor — find the next letter not already claimed by
    // anyone (dummy data or previously added doctors).
    final usedPrefixes = _doctorPrefixes.values.toSet();
    int index = 0;
    String candidate;
    do {
      candidate = _prefixFromIndex(index);
      index++;
    } while (usedPrefixes.contains(candidate));

    _doctorPrefixes[doctorName] = candidate;
    return candidate;
  }

  String _prefixFromIndex(int index) {
    // Base-26 letter sequence: 0->A, 25->Z, 26->AA, 27->AB, ...
    String result = "";
    int n = index;
    do {
      result = String.fromCharCode(65 + (n % 26)) + result;
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return result;
  }

  String generateTokenForDoctor(String doctorName) {
    _initTokenMapsIfNeeded();

    final prefix = _doctorPrefix(doctorName);
    final nextSequence = (_doctorTokenCounters[doctorName] ?? 0) + 1;
    _doctorTokenCounters[doctorName] = nextSequence;

    final sequence = nextSequence.toString().padLeft(3, '0');
    return "$prefix-$sequence";
  }
}
