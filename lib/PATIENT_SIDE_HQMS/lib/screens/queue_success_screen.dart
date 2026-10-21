import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';
import 'package:queue_management_system/widgets/doctor_photo.dart';
import '../models/doctor.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import 'department_list_screen.dart';
import 'track_queue_screen.dart';
import '../widgets/app_back_button.dart';

class QueueSuccessScreen extends StatefulWidget {
  final Doctor doctor;

  // The real result from QueueService.joinQueue (token saved in Firestore).
  final JoinedQueueResult result;

  const QueueSuccessScreen({
    super.key,
    required this.doctor,
    required this.result,
  });

  @override
  State<QueueSuccessScreen> createState() => _QueueSuccessScreenState();
}

class _QueueSuccessScreenState extends State<QueueSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;

  late final Animation<double> _badgeScale;
  late final Animation<double> _checkDraw;
  late final Animation<double> _titleIn;
  late final Animation<double> _ticketIn;
  late final Animation<double> _tipIn;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    Animation<double> step(double a, double b, Curve c) =>
        CurvedAnimation(parent: _enter, curve: Interval(a, b, curve: c));

    _badgeScale = step(0.00, 0.35, Curves.easeOutBack);
    _checkDraw = step(0.25, 0.55, Curves.easeOut);
    _titleIn = step(0.40, 0.65, Curves.easeOut);
    _ticketIn = step(0.52, 0.82, Curves.easeOut);
    _tipIn = step(0.70, 1.00, Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 450), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // Formats minutes like "25 min" or "1h 10m".
  String _formatWait(int minutes) {
    if (minutes <= 0) return 'Now';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _reveal(Animation<double> a, Widget child) {
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  Widget _pulseRing(double offset) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final t = (_pulse.value + offset) % 1.0;
        return Transform.scale(
          scale: 1 + t * 0.6,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: (1 - t) * 0.3),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DepartmentListScreen()),
      (route) => false,
    );
  }

  void _goTrack() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TrackQueueScreen(
          doctor: widget.doctor,
          entryId: widget.result.entryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final doctor = widget.doctor;
    final int waitMinutes =
        result.patientsAhead * doctor.averageMinutesPerPatient;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
    if (!didPop) _goHome();
  },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const BackgroundBlobs(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
  child: Row(
    children: [AppBackButton(onTap: _goHome)],
  ),
),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                      child: Column(
                        children: [
                          // ---- Animated badge ----
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _pulseRing(0.0),
                                _pulseRing(0.5),
                                ScaleTransition(
                                  scale: _badgeScale,
                                  child: Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.gradientStart,
                                          AppColors.gradientEnd,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: .35),
                                          blurRadius: 26,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _checkDraw,
                                      builder: (_, _) => CustomPaint(
                                        painter: _TickPainter(_checkDraw.value),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ---- Title ----
                          _reveal(
                            _titleIn,
                            Column(
                              children: [
                                const Text(
                                  'Queue Joined Successfully!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textGrey,
                                      height: 1.5,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Your token is ready for\n',
                                      ),
                                      TextSpan(
                                        text: result.doctorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      TextSpan(text: ' (${result.department})'),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),

                          // ---- Ticket ----
                          _reveal(
                            _ticketIn,
                            _TicketCard(
                              doctor: doctor,
                              token: result.token,
                              doctorName: result.doctorName,
                              department: result.department,
                              patientsAhead: result.patientsAhead,
                              wait: _formatWait(waitMinutes),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ---- Tip ----
                          _reveal(
                            _tipIn,
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: .15),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active_rounded,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Stay Updated!',
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'We will notify you when your turn is near. '
                                          'Please arrive at least 5 minutes before your '
                                          'estimated consultation time.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.45,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---- Fixed bottom bar ----
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
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
                        PremiumButton(label: 'Track Queue', onPressed: _goTrack),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _goHome,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textGrey,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Back to Home'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TicketCard extends StatelessWidget {
  final Doctor doctor;
  final String token;
  final String doctorName;
  final String department;
  final int patientsAhead;
  final String wait;

  const _TicketCard({
    required this.doctor,
    required this.token,
    required this.doctorName,
    required this.department,
    required this.patientsAhead,
    required this.wait,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // ---- Gradient top ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: .85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'YOUR TOKEN NUMBER',
                        style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: token));
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Token copied'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          token,
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: DoctorPhoto(
                              doctor: doctor,
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- Dashed tear line ----
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final dashes = (c.maxWidth / 10).floor();
                  return SizedBox(
                    height: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        dashes,
                        (_) => Container(
                          width: 5,
                          height: 1,
                          color: AppColors.cardBorder,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ---- White stats ----
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _TicketStat(
                        icon: Icons.groups_2_rounded,
                        value: '$patientsAhead',
                        label: 'Patients Ahead',
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: AppColors.cardBorder,
                      thickness: 1,
                    ),
                    Expanded(
                      child: _TicketStat(
                        icon: Icons.timer_outlined,
                        value: wait,
                        label: 'Est. Wait',
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: AppColors.cardBorder,
                      thickness: 1,
                    ),
                    Expanded(
                      child: _TicketStat(
                        icon: Icons.local_hospital_rounded,
                        value: department,
                        label: 'Department',
                      ),
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

class _TicketStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _TicketStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

// Draws the tick progressively.
class _TickPainter extends CustomPainter {
  final double progress;
  _TickPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.29, h * 0.53)
      ..lineTo(w * 0.44, h * 0.67)
      ..lineTo(w * 0.72, h * 0.37);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}