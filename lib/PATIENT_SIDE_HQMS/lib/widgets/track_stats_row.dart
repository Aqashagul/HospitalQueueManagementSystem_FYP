import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'app_card_decoration.dart';

/// Row of 3 tiles: Your Token, Now Serving, Est. Wait.
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.confirmation_number_rounded,
            value: yourToken,
            label: 'Your Token',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.record_voice_over_rounded,
            value: nowServing,
            label: 'Now Serving',
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.timer_outlined,
            value: estWait,
            label: 'Est. Wait',
            color: Colors.orange.shade700,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: appCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 9),
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