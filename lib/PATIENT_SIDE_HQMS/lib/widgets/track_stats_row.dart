import 'package:flutter/material.dart';
import 'gradient_stat_card.dart';

/// Row of 3 gradient cards: Your Token, Now Serving, Est. Wait.
/// Same look as the 3 cards on the doctor detail screen.
class TrackStatsRow extends StatelessWidget {
  final String yourToken;
  final String nowServing;
  final String estWait;

  const TrackStatsRow({
    super.key,
    required this.yourToken,
    required this.nowServing,
    required this.estWait,
  });

  LinearGradient _grad(Color a, Color b, Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          a.withValues(alpha: 0.80),
          b.withValues(alpha: 0.80),
          c.withValues(alpha: 0.80),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GradientStatCard(
            icon: Icons.confirmation_number_rounded,
            label: 'Your Token',
            value: yourToken,
            gradient: _grad(
              const Color.fromARGB(255, 106, 183, 183),
              const Color.fromARGB(255, 121, 170, 173),
              const Color.fromARGB(255, 199, 141, 230),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientStatCard(
            icon: Icons.record_voice_over_rounded,
            label: 'Now Serving',
            value: nowServing,
            gradient: _grad(
              const Color.fromARGB(255, 200, 183, 211),
              const Color.fromARGB(255, 138, 97, 169),
              const Color.fromARGB(255, 27, 113, 193),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientStatCard(
            icon: Icons.timer_outlined,
            label: 'Est. Wait',
            value: estWait,
            gradient: _grad(
              const Color.fromARGB(255, 106, 183, 183),
              const Color.fromARGB(255, 121, 170, 173),
              const Color.fromARGB(255, 199, 141, 230),
            ),
          ),
        ),
      ],
    );
  }
}