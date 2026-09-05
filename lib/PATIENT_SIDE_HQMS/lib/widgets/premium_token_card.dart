import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PremiumTokenCard extends StatelessWidget {
  final String tokenNumber;
  final String doctorName;
  final int patientsAhead; // Naya
  final String estimatedWaitTime; // Naya

  const PremiumTokenCard({
    super.key,
    required this.tokenNumber,
    required this.doctorName,
    required this.patientsAhead,
    required this.estimatedWaitTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.confirmation_number_rounded, color: Colors.white.withValues(alpha: .9), size: 16),
              const SizedBox(width: 6),
              Text(
                'YOUR TOKEN NUMBER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: .9),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tokenNumber,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'for $doctorName',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),

          // Dashed divider
          SizedBox(
            width: double.infinity,
            child: CustomPaint(
              painter: _DashedLinePainter(),
              size: const Size(double.infinity, 1),
            ),
          ),
          const SizedBox(height: 18),

          // People ahead + Est. wait time - side by side
          Row(
            children: [
              Expanded(
                child: _TokenStat(
                  icon: Icons.groups_2_rounded,
                  label: 'Patients Ahead',
                  value: '$patientsAhead',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: .25),
              ),
              Expanded(
                child: _TokenStat(
                  icon: Icons.timer_outlined,
                  label: 'Est. Wait Time',
                  value: estimatedWaitTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _TokenStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: .9), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .3)
      ..strokeWidth = 1.2;
    const double dashWidth = 6;
    const double dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}