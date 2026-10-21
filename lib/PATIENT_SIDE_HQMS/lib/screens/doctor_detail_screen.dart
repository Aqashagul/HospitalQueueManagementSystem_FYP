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
        .where((d) => QueueService.isActiveStatus(d.data()['status']?.toString()))
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
        final diff =
            completed.toDate().difference(called.toDate()).inMilliseconds;
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

  // Asks for confirmation, then creates the real token in Firestore and
  // opens the success screen with the result.
  Future<void> _handleJoinQueue() async {
    if (_joining) return;
    setState(() => _joining = true);

    try {
      final Doctor doctor = await _freshDoctor();
      if (!mounted) return;

      final bool? confirmed = await showJoinQueueDialog(context, doctor);
      if (confirmed != true || !mounted) return;

      // Saves the token, doctor and department in Firestore.
      final result = await QueueService().joinQueue(doctor);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
                // ---- Top bar ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textDark,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                      child: Text(
                        'Doctor Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),

                // ---- Scrollable content ----
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(doctor),
                        const SizedBox(height: 18),

                        // Stats
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.groups_2_rounded,
                                  value: '${doctor.currentQueueLength}',
                                  label: 'Patients Ahead',
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.timer_outlined,
                                  value: doctor.estimatedWaitTime,
                                  label: 'Est. Wait',
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.payments_outlined,
                                  value: doctor.consultationFee,
                                  label: 'Consult Fee',
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Live indicator
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live queue, updates in real time',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (doctor.availability.isNotEmpty) ...[
                          AvailableTimingCard(timing: doctor.availability),
                          const SizedBox(height: 16),
                        ],
                        if (doctor.about.isNotEmpty) ...[
                          AboutDoctorCard(about: doctor.about),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),

                // ---- Fixed bottom bar ----
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .10),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            doctor.isActive
                                ? Icons.notifications_active_outlined
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              doctor.isActive
                                  ? 'You will be notified when your turn is near'
                                  : 'This doctor is not accepting patients right now',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // White hero card: photo with gradient ring, name, chips, experience.
  Widget _buildHeroCard(Doctor doctor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              children: [
                Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .28),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: DoctorPhoto(doctor: doctor, width: 120, height: 120),
                    ),
                  ),
                ),
                // Online / offline dot
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: doctor.isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doctor.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.medical_services_rounded,
                text: doctor.specialization,
                color: AppColors.primary,
              ),
              _Chip(
                icon: doctor.isActive
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_rounded,
                text: doctor.isActive ? 'Available' : 'Unavailable',
                color: doctor.isActive ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ],
          ),
          if (doctor.experience.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  '${doctor.experience} experience',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  

}
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}