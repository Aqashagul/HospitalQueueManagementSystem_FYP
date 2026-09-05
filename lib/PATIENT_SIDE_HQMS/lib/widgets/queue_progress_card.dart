import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class QueueProgressCard extends StatelessWidget {
  final int position; 
  final int totalAheadAtStart; 
  final String nowServingToken;
  final String estimatedWaitTime;

  const QueueProgressCard({
    super.key,
    required this.position,
    required this.totalAheadAtStart,
    required this.nowServingToken,
    required this.estimatedWaitTime,
  });

  @override
  Widget build(BuildContext context) {
    final bool isYourTurn = position <= 1;
    final double progress = totalAheadAtStart == 0
        ? 1.0
        : (1 - (position - 1) / totalAheadAtStart).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isYourTurn
              ? [Colors.green.shade400, Colors.green.shade700]
              : [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: (isYourTurn ? Colors.green : AppColors.primary).withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isYourTurn) ...[
            const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 10),
            const Text(
              "It's Your Turn!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Please proceed to the doctor\'s room now',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .9)),
            ),
          ] else ...[
            Text(
              'YOUR POSITION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: .85),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '#$position',
              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: .25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _StatColumn(label: 'Now Serving', value: nowServingToken),
                ),
                Container(width: 1, height: 34, color: Colors.white.withValues(alpha: .25)),
                Expanded(
                  child: _StatColumn(label: 'Est. Wait', value: estimatedWaitTime),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: .85))),
      ],
    );
  }
}