import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/background_blobs.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_button.dart';
import 'department_list_screen.dart';
import 'track_queue_screen.dart';
import 'package:queue_management_system/widgets/doctor_photo.dart';
import 'package:lottie/lottie.dart';
import '../widgets/page_top_bar.dart';

const String _prefKey = 'active_entry_id';

class TrackQueueTabScreen extends StatefulWidget {
  const TrackQueueTabScreen({super.key});

  @override
  State<TrackQueueTabScreen> createState() => _TrackQueueTabScreenState();
}

class _TrackQueueTabScreenState extends State<TrackQueueTabScreen> {
  bool _loaded = false;
  String? _entryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _entryId = prefs.getString(_prefKey);
      _loaded = true;
    });
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  bool _isCompleted(String? raw) {
    final s = (raw ?? '').toLowerCase();
    return s == 'completed' || s == 'done';
  }

  bool _isInConsultation(String? raw) {
    final s = (raw ?? '').toLowerCase();
    return s == 'in consultation' || s == 'in-progress' || s == 'in progress';
  }

  // Admin DoctorModel -> patient Doctor (same bridge as the doctor list).
  Doctor? _doctorFor(String doctorId) {
    for (final d in AppdataStore().doctors) {
      if (d.id == doctorId) return _toPatientDoctor(d);
    }
    return null;
  }

  Doctor _toPatientDoctor(DoctorModel d) {
    return Doctor(
      id: d.id ?? '',
      name: d.name,
      specialization: d.specialization,
      departmentId: '',
      departmentName: d.department,
      imagePath: d.photoAssetPath ?? '',
      photoBytes: d.photoBytes,
      about: d.qualification ?? '',
      experience: d.experience ?? '',
      availability: d.workingHours ?? '',
      tokenPrefix: d.tokenPrefix ?? '',
      consultationFee: 'Rs. ${d.fee}',
      currentQueueLength: 0,
      isActive: d.status.toLowerCase() == 'available',
    );
  }

  void _openTracking(Doctor doctor, String entryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackQueueScreen(doctor: doctor, entryId: entryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 const PageTopBar(title: 'Track Queue'),
                  const SizedBox(height: 6),
                  Text(
                    'Your current queue at a glance',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 22),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final id = _entryId;
    if (id == null || id.isEmpty) return const _NoQueueView();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('queue_entries')
          .doc(id)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final doc = snap.data!;
        final data = doc.data();
        final status = data?['status']?.toString();

        // Deleted, cancelled or skipped: nothing to track any more.
        final bool usable =
            doc.exists &&
            data != null &&
            (QueueService.isActiveStatus(status) || _isCompleted(status));
        if (!usable) {
          _clear();
          return const _NoQueueView();
        }

        final String doctorId = data['doctorId']?.toString() ?? '';
        final doctor = _doctorFor(doctorId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: QueueService().watchTodaysEntries(doctorId),
          builder: (context, qSnap) {
            final docs = qSnap.data?.docs ?? [];
            final int mySeq = (data['seq'] as int?) ?? 0;
            final int ahead = docs.where((d) {
              final m = d.data();
              final s = m['seq'];
              return QueueService.isActiveStatus(m['status']?.toString()) &&
                  s is int &&
                  s < mySeq;
            }).length;

            final bool myTurn = _isInConsultation(status);
            final bool done = _isCompleted(status);
            final int avg = doctor?.averageMinutesPerPatient ?? 10;
            final int waitMin = ahead * avg;
            final String wait = (myTurn || done)
                ? '--'
                : (waitMin <= 0
                      ? 'Now'
                      : (waitMin < 60
                            ? '$waitMin min'
                            : '${waitMin ~/ 60}h ${waitMin % 60}m'));

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE QUEUE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LiveTicketCard(
                    doctor: doctor,
                    token: data['token']?.toString() ?? '--',
                    doctorName:
                        data['doctorName']?.toString() ??
                        doctor?.name ??
                        'Doctor',
                    department:
                        data['department']?.toString() ??
                        doctor?.departmentName ??
                        '',
                    patientName:
                        FirebaseAuth.instance.currentUser?.displayName ??
                        'Patient',
                    ahead: ahead,
                    wait: wait,
                    myTurn: myTurn,
                    done: done,
                    onTap: doctor == null
                        ? null
                        : () => _openTracking(doctor, id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------
class _LiveTicketCard extends StatelessWidget {
  final Doctor? doctor;
  final String token;
  final String doctorName;
  final String department;
  final String patientName;
  final int ahead;
  final String wait;
  final bool myTurn;
  final bool done;
  final VoidCallback? onTap;

  const _LiveTicketCard({
    required this.doctor,
    required this.token,
    required this.doctorName,
    required this.department,
    required this.patientName,
    required this.ahead,
    required this.wait,
    required this.myTurn,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = done
        ? AppColors.primary
        : myTurn
        ? Colors.green.shade700
        : Colors.orange.shade700;
    final String statusText = done
        ? 'Completed'
        : myTurn
        ? "Your turn"
        : (ahead == 0 ? 'You are next' : 'Waiting');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .10),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ---- Doctor row ----
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                    ),
                    child: ClipOval(
                      child: doctor != null
                          ? DoctorPhoto(doctor: doctor!, width: 48, height: 48)
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.white,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- dashed tear line ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, c) {
                  final dashes = (c.maxWidth / 10).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      dashes,
                      (_) => Container(
                        width: 5,
                        height: 1.2,
                        color: AppColors.primary.withValues(alpha: .25),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ---- Token + position ----
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR TOKEN',
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textGrey,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd,
                            ],
                          ).createShader(r),
                          child: Text(
                            token,
                            style: const TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: myTurn
                            ? const [Color(0xFF43A878), Color(0xFF1F8A5B)]
                            : const [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .3),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          done
                              ? Icons.check_rounded
                              : myTurn
                              ? Icons.notifications_active_rounded
                              : Icons.groups_2_rounded,
                          color: Colors.white,
                          size: done || myTurn ? 34 : 18,
                        ),
                        if (!done && !myTurn)
                          Text(
                            '#${ahead + 1}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- mini stats ----
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.groups_2_rounded,
                      value: '$ahead',
                      label: 'Patients ahead',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.timer_outlined,
                      value: wait,
                      label: 'Est. wait',
                    ),
                  ),
                ],
              ),
            ),

            // ---- button ----
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Track live queue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No queue yet
// ---------------------------------------------------------------------------
class _NoQueueView extends StatelessWidget {
  const _NoQueueView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: Lottie.asset(
                'assets/images/PATIENT_SIDE images/icons/images/lottiefiles/empty_queue.json',
                fit: BoxFit.contain,
                repeat: true,
                delegates: LottieDelegates(
                  values: [
                    ValueDelegate.color(
                      const ['**'],
                      callback: (frameInfo) {
                        final c = frameInfo.startValue;
                        if (c == null)
                          return AppColors.primary.withValues(alpha: .85);

                        final r = (c.r * 255).round();
                        final b = (c.b * 255).round();

                        
                        final bool isRingOrHandle = b > r + 60;

                        return isRingOrHandle
                            ? AppColors.primary.withValues(alpha: .85)
                            : c;
                      },
                    ),
                  ],
                ),
              
                errorBuilder: (_, _, _) => Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: .1),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No active queue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't joined any queue yet.\nGenerate a queue to get your token.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 200,
              child: PremiumButton(
                label: 'Generate Queue',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const DepartmentListScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
