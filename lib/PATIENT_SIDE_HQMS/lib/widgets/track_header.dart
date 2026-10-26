import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'app_back_button.dart';
import 'live_badge.dart';

class TrackHeader extends StatelessWidget {
  final VoidCallback onBack;
  const TrackHeader({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppBackButton(onTap: onBack),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Track Queue',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        const LiveBadge(),
      ],
    );
  }
}