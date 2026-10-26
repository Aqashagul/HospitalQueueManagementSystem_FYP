import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../widgets/background_blobs.dart';
import '../widgets/premium_button.dart';
import '../widgets/step_progress_indicator.dart';
import 'department_list_screen.dart';

class VerificationSuccessScreen extends StatefulWidget {
  final String userName;
  const VerificationSuccessScreen({super.key, required this.userName});

  @override
  State<VerificationSuccessScreen> createState() =>
      _VerificationSuccessScreenState();
}

class _VerificationSuccessScreenState extends State<VerificationSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter; // one-time entrance
  late final AnimationController _pulse; // repeating rings

  late final Animation<double> _badgeScale;
  late final Animation<double> _checkDraw;
  late final Animation<double> _titleIn;
  late final Animation<double> _cardIn;
  late final Animation<double> _buttonIn;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    Animation<double> step(double a, double b, Curve c) => CurvedAnimation(
      parent: _enter,
      curve: Interval(a, b, curve: c),
    );

    _badgeScale = step(0.00, 0.40, Curves.easeOutBack);
    _checkDraw = step(0.30, 0.60, Curves.easeOut);
    _titleIn = step(0.50, 0.75, Curves.easeOut);
    _cardIn = step(0.62, 0.87, Curves.easeOut);
    _buttonIn = step(0.75, 1.00, Curves.easeOut);

    _enter.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // Fade + slide up
  Widget _reveal(Animation<double> a, Widget child) {
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
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
          scale: 1 + t * 0.7,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: (1 - t) * 0.35),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const BackgroundBlobs(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const StepProgressIndicator(currentStep: 3),
                    const Spacer(),

                    // ---- Badge with rings + drawn check ----
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _pulseRing(0.0),
                          _pulseRing(0.5),
                          ScaleTransition(
                            scale: _badgeScale,
                            child: Container(
                              width: 120,
                              height: 120,
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
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _checkDraw,
                                builder: (_, _) => CustomPaint(
                                  painter: _CheckPainter(_checkDraw.value),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Title + message ----
                    _reveal(
                      _titleIn,
                      Column(
                        children: [
                          const Text(
                            'Verification Successful',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 14.5,
                                color: AppColors.textGrey,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: 'Welcome, '),
                                TextSpan(
                                  text: widget.userName,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '!\nYour phone number has been verified.',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ---- Verified number card ----
                    if (phone.isNotEmpty)
                      _reveal(
                        _cardIn,
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: .06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.phone_android_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mobile number',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const Spacer(flex: 2),

                    _reveal(
                      _buttonIn,
                      PremiumButton(
                        label: 'Continue to Departments',
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const DepartmentListScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
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


class _CheckPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  _CheckPainter(this.progress);

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
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}