import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/department_model.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/widgets/loading_or_offline.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../models/doctor.dart';
import 'doctor_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_back_button.dart';
import '../widgets/notification_bell.dart';



class DoctorListScreen extends StatefulWidget {
  // The department the patient picked (live data from the admin side).
  final Department department;
  const DoctorListScreen({super.key, required this.department});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Today's queue entries of ALL doctors, live from Firestore. One
  // listener is enough: the counts per doctor are worked out below.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _queueStream;

  @override
  void initState() {
    super.initState();
    _queueStream = FirebaseFirestore.instance
        .collection('queue_entries')
        .where('dayKey', isEqualTo: QueueService.dayKeyOf(DateTime.now()))
        .snapshots();
  }

  void _onSearchChanged(String query) {
    setState(() => _query = query.trim().toLowerCase());
  }

  // Doctors of this department, live from Firestore (managed by the admin).
  List<DoctorModel> _visibleDoctors() {
    return AppdataStore().doctors
        .where((doc) => doc.department == widget.department.name)
        .where((doc) => doc.name.toLowerCase().contains(_query))
        .toList();
  }

  // People currently waiting or in consultation for this doctor today,
  // counted from the live queue entries.
  int _queueLengthFor(
    String doctorId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
  ) {
    return entries.where((d) {
      final data = d.data();
      return data['doctorId'] == doctorId &&
          QueueService.isActiveStatus(data['status']?.toString());
    }).length;
  }

  // Bridges the admin DoctorModel to the patient-side Doctor class that
  // DoctorDetailScreen still expects. Fields the admin does not have are
  // left empty instead of being invented.
  Doctor _toPatientDoctor(DoctorModel d, int queueLength) {
    return Doctor(
      id: d.id ?? '',
      name: d.name,
      specialization: d.specialization,
      departmentId: widget.department.id ?? '',
      departmentName: d.department,
      imagePath: d.photoAssetPath ?? '',
      photoBytes: d.photoBytes,
      about: d.qualification ?? '',
      experience: d.experience ?? '',
      availability: d.workingHours ?? '',
      tokenPrefix: d.tokenPrefix ?? '',
      consultationFee: 'Rs. ${d.fee}',
      currentQueueLength: queueLength,
      isActive: d.status.toLowerCase() == 'available',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // First letters of the department name, used when there is no picture.
  String get _departmentInitials {
    final words = widget.department.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final departmentPhoto = widget.department.photoBytes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                    children: const [
                      AppBackButton(),
                      Spacer(),
                      NotificationBell(),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Department name badge
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color.fromARGB(
                            255,
                            106,
                            183,
                            183,
                          ).withValues(alpha: 0.80),
                          const Color.fromARGB(
                            255,
                            121,
                            170,
                            173,
                          ).withValues(alpha: 0.80),
                          const Color.fromARGB(
                            255,
                            199,
                            141,
                            230,
                          ).withValues(alpha: 0.80),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // The department's picture when the admin added one,
                        // otherwise its initials.
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child:
                              (departmentPhoto != null &&
                                  departmentPhoto.isNotEmpty)
                              ? Image.memory(
                                  departmentPhoto,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : Text(
                                  _departmentInitials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEPARTMENT',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGrey,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.department.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right side
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'Available Doctors',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search doctor...',
                        hintStyle: TextStyle(
                          color: AppColors.textGrey.withValues(alpha: .7),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textGrey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Doctor list. It rebuilds when the live queue changes
                  // (StreamBuilder) and when the admin adds or edits a
                  // doctor (ListenableBuilder).
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _queueStream,
                      builder: (context, queueSnapshot) {
                        // Zeros while loading, real counts once data arrives.
                        final entries = queueSnapshot.data?.docs ?? [];

                        return ListenableBuilder(
                          listenable: AppdataStore(),
                          builder: (context, _) {
                            if (!AppdataStore().doctorsLoaded) {
                              return const LoadingOrOffline(
                                message: "Loading...",
                              );
                            }
                            final doctors = _visibleDoctors();

                            if (doctors.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_off_outlined,
                                      size: 48,
                                      color: AppColors.textGrey.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No doctor found',
                                      style: TextStyle(
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: doctors.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final doctor = doctors[index];
                                final queueLength = _queueLengthFor(
                                  doctor.id ?? '',
                                  entries,
                                );
                                return _DoctorCard(
                                  doctor: doctor,
                                  queueLength: queueLength,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DoctorDetailScreen(
                                          doctor: _toPatientDoctor(
                                            doctor,
                                            queueLength,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final int queueLength;
  final VoidCallback onTap;
  const _DoctorCard({
    required this.doctor,
    required this.queueLength,
    required this.onTap,
  });

  bool get _isActive => doctor.status.toLowerCase() == 'available';

  // Initials without the "Dr." prefix, e.g. "Dr.Sana Khan" -> "SK".
  String get _initials {
    final cleaned = doctor.name.replaceFirst(
      RegExp(r'^\s*dr\.?\s*', caseSensitive: false),
      '',
    );
    final words = cleaned
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  // Shown when the doctor has no picture in the admin data.
  Widget _initialsAvatar() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // The picture the admin uploaded, else the old bundled picture, else the
  // initials.
  Widget _avatarImage() {
    final bytes = doctor.photoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _initialsAvatar(),
      );
    }

    final path = doctor.photoAssetPath;
    if (path != null && path.isNotEmpty) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initialsAvatar(),
      );
    }

    return _initialsAvatar();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _isActive ? onTap : null,
      child: Opacity(
        opacity: _isActive ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isActive ? Colors.white : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isActive ? AppColors.cardBorder : const Color(0xFFE0E0E0),
            ),
            boxShadow: _isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Circular doctor image with gradient ring
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(child: _avatarImage()),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isActive ? Colors.green : Colors.red,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.specialization,
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (!_isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$queueLength in queue',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _isActive
                    ? AppColors.textGrey
                    : AppColors.textGrey.withValues(alpha: .4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
