import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Fixed bottom bar: Leave Queue (optional) + Back to Home.
class TrackBottomBar extends StatelessWidget {
  final bool showLeave;
  final VoidCallback onLeave;
  final VoidCallback onHome;
  final bool showHome;

  const TrackBottomBar({
    super.key,
    required this.showLeave,
    required this.onLeave,
    required this.onHome,
     this.showHome = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
          if (showLeave) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onLeave,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Leave Queue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: .4),
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.home_rounded, size: 20),
              label: const Text('Back to Home'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: .1),
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}