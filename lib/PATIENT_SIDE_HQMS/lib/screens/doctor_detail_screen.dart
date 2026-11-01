import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import 'package:queue_management_system/data/appdata_store.dart';
import 'package:queue_management_system/models/doctor_model.dart';
import 'package:queue_management_system/widgets/doctor_photo.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import '../widgets/gradient_stat_card.dart';
import '../widgets/available_timing_card.dart';
import '../widgets/about_doctor_card.dart';
import '../widgets/join_queue_dialog.dart';
import '../models/doctor.dart';
import 'queue_success_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/notification_bell.dart';
import '../widgets/app_back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';



class DoctorDetailScreen extends StatefulWidget {
  final Doctor doctor;
  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  // True from the first tap on "Join Queue" until the whole flow
  // (dialog + Firestore write) is finished. Stops double taps from opening
  // two dialogs or sending two join requests.
  bool _joining = false;

  // Today's queue entries of THIS doctor, live from Firestore.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _queueStream;

  @override
  void initState() {
    super.initState();
    _queueStream = QueueService().watchTodaysEntries(widget.doctor.id);
  }

  // Patients who still hold a place (waiting or in consultation).
  int _activeCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs
        .where(
          (d) => QueueService.isActiveStatus(d.data()['status']?.toString()),
        )
        .length;
  }

  // Real average consultation time today, in minutes: the time between a
  // patient being called in and being completed. Returns null while no
  // consultation has finished yet today.
  /*int? _averageConsultMinutes(      ////FOR ESTIMATED WAIT TIME
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int totalMs = 0;
    int count = 0;
    for (final d in docs) {
      final data = d.data();
      final called = data['calledAt'];
      final completed = data['completedAt'];
      if (called is Timestamp && completed is Timestamp) {
        final diff =
            completed.toDate().difference(called.toDate()).inMilliseconds;
        if (diff >= 0) {
          totalMs += diff;
          count++;
        }
      }
    }
    if (count == 0) return null;
    final minutes = (totalMs / count / 60000).round();
    return minutes < 1 ? 1 : minutes;
  }*/

  // An average is only trusted after this many real consultations today.
  static const int _minSamples = 3;

  // Average consultation time today, in minutes, measured from real
  // consultations (called in -> completed). Returns null, so the default of
  // 10 minutes is used, until enough real consultations have finished.
  int? _averageConsultMinutes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int totalMs = 0;
    int count = 0;
    for (final d in docs) {
      final data = d.data();
      final called = data['calledAt'];
      final completed = data['completedAt'];
      if (called is Timestamp && completed is Timestamp) {
        final diff = completed
            .toDate()
            .difference(called.toDate())
            .inMilliseconds;
        // Ignore anything shorter than 1 minute (accidental clicks or quick
        // test taps), so it cannot drag the average down to nothing.
        if (diff >= 60000) {
          totalMs += diff;
          count++;
        }
      }
    }
    if (count < _minSamples) return null;
    final minutes = (totalMs / count / 60000).round();
    return minutes < 1 ? 1 : minutes;
  }

  // Rebuilds the patient-side Doctor with the latest admin data (fee,
  // timing, availability, picture...) and the live queue numbers.
  Doctor _liveDoctor({required int queueLength, int? averageMinutes}) {
    final base = widget.doctor;

    DoctorModel? m;
    for (final d in AppdataStore().doctors) {
      if (d.id == base.id) {
        m = d;
        break;
      }
    }

    return Doctor(
      id: base.id,
      name: m?.name ?? base.name,
      specialization: m?.specialization ?? base.specialization,
      departmentId: base.departmentId,
      departmentName: m?.department ?? base.departmentName,
      imagePath: m?.photoAssetPath ?? base.imagePath,
      photoBytes: m?.photoBytes ?? base.photoBytes,
      about: m?.qualification ?? base.about,
      experience: m?.experience ?? base.experience,
      availability: m?.workingHours ?? base.availability,
      tokenPrefix: m?.tokenPrefix ?? base.tokenPrefix,
      consultationFee: m != null ? 'Rs. ${m.fee}' : base.consultationFee,
      averageMinutesPerPatient: averageMinutes ?? base.averageMinutesPerPatient,
      currentQueueLength: queueLength,
      isActive: m != null
          ? m.status.toLowerCase() == 'available'
          : base.isActive,
    );
  }

  // One fresh read of today's queue, so the confirmation dialog shows the
  // position the patient will really get.
  Future<Doctor> _freshDoctor() async {
    final snap = await FirebaseFirestore.instance
        .collection('queue_entries')
        .where('doctorId', isEqualTo: widget.doctor.id)
        .where('dayKey', isEqualTo: QueueService.dayKeyOf(DateTime.now()))
        .get();
    return _liveDoctor(
      queueLength: _activeCount(snap.docs),
      averageMinutes: _averageConsultMinutes(snap.docs),
    );
  }

  // Friendly message box (easier to notice than a snackbar).
  Future<void> _showInfoDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: .1),
          ),
          child: const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 30),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5, color: AppColors.textGrey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  // True (and shows a message) when the patient already holds an active
  // token today. Read only, the real rule is still enforced in QueueService.
  Future<bool> _blockedByActiveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await FirebaseFirestore.instance
        .collection('queue_entries')
        .where('patientId', isEqualTo: user.uid)
        .where('dayKey', isEqualTo: QueueService.dayKeyOf(DateTime.now()))
        .get();

    for (final d in snap.docs) {
      final data = d.data();
      if (QueueService.isActiveStatus(data['status']?.toString())) {
        final doctor = data['doctorName']?.toString() ?? 'a doctor';
        final token = data['token']?.toString() ?? '';
        if (!mounted) return true;
        await _showInfoDialog(
          'Queue already joined',
          'You have already joined $doctor\'s queue'
          '${token.isEmpty ? '' : ' (token $token)'}.\n\n'
          'You cannot join another doctor\'s queue until that token is '
          'completed or you leave that queue.',
        );
        return true;
      }
    }
    return false;
  }

  // Asks for confirmation, then creates the real token in Firestore and
  // opens the success screen with the result.
  Future<void> _handleJoinQueue() async {
    if (_joining) return;
    setState(() => _joining = true);

    try {
       // Already holding a token with a doctor? Tell the patient and stop.
      if (await _blockedByActiveToken()) return;
      final Doctor doctor = await _freshDoctor();
      if (!mounted) return;

      final bool? confirmed = await showJoinQueueDialog(context, doctor);
      if (confirmed != true || !mounted) return;

      // Saves the token, doctor and department in Firestore.
      final result = await QueueService().joinQueue(doctor);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_entry_id', result.entryId);

      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QueueSuccessScreen(doctor: doctor, result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : 'Could not join the queue. Please try again.';
                await _showInfoDialog('Could not join', message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the admin edits the doctor (ListenableBuilder) and
    // when the queue changes (StreamBuilder).
    return ListenableBuilder(
      listenable: AppdataStore(),
      builder: (context, _) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _queueStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final doctor = _liveDoctor(
              queueLength: _activeCount(docs),
              averageMinutes: _averageConsultMinutes(docs),
            );

            return _buildScreen(doctor);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  // Photo with gradient ring, name, specialization, availability chip.
  Widget _buildDoctorHeader(Doctor doctor) {
    final Color c = doctor.isActive ? Colors.green.shade700 : Colors.grey;
    return Column(
      children: [
        Container(
          width: 130,
          height: 130,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: ClipOval(
            child: DoctorPhoto(doctor: doctor, width: 124, height: 124),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          doctor.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          doctor.specialization,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.textGrey),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                doctor.isActive ? 'Available Now' : 'Unavailable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        ),
        if (doctor.experience.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${doctor.experience} experience',
            style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
          ),
        ],
      ],
    );
  }

  Widget _buildScreen(Doctor doctor) {
    final bool canJoin = doctor.isActive && !_joining;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Column(
              children: [
                // ---- Top bar: back + bell ----
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [AppBackButton(), Spacer(), NotificationBell()],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _buildDoctorHeader(doctor)),
                        const SizedBox(height: 26),

                        // Gradient highlight row - Patients Ahead, Est. Wait, Fee
                        Row(
                          children: [
                            Expanded(
                              child: GradientStatCard(
                                icon: Icons.groups_2_rounded,
                                label: 'Patients Ahead',
                                value: '${doctor.currentQueueLength}',
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
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GradientStatCard(
                                icon: Icons.timer_outlined,
                                label: 'Est. Wait Time',
                                value: doctor.estimatedWaitTime,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color.fromARGB(
                                      255,
                                      200,
                                      183,
                                      211,
                                    ).withValues(alpha: 0.80),
                                    const Color.fromARGB(
                                      255,
                                      138,
                                      97,
                                      169,
                                    ).withValues(alpha: 0.80),
                                    const Color.fromARGB(
                                      255,
                                      27,
                                      113,
                                      193,
                                    ).withValues(alpha: 0.80),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GradientStatCard(
                                icon: Icons.payments_outlined,
                                label: 'Consultation Fee',
                                value: doctor.consultationFee,
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
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Available timing - only shown when the admin has
                        // entered working hours for this doctor.
                        if (doctor.availability.isNotEmpty) ...[
                          AvailableTimingCard(timing: doctor.availability),
                          const SizedBox(height: 20),
                        ],

                        // About - only shown when the admin has entered a
                        // qualification (that text is what fills this card).
                        if (doctor.about.isNotEmpty) ...[
                          AboutDoctorCard(about: doctor.about),
                          const SizedBox(height: 32),
                        ] else
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ---- Join button, fixed at the bottom ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                  child: Opacity(
                    opacity: canJoin ? 1.0 : 0.5,
                    child: IgnorePointer(
                      ignoring: !canJoin,
                      child: PremiumButton(
                        label: !doctor.isActive
                            ? 'Currently Unavailable'
                            : (_joining ? 'Please wait...' : 'Join Queue'),
                        onPressed: _handleJoinQueue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
