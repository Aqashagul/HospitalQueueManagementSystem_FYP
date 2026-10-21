import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class QueueEntryMissingView extends StatelessWidget {
  final VoidCallback onHome;
  const QueueEntryMissingView({super.key, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: .1),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'This queue entry is no longer active',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your token may have been completed or removed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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
      ),
    );
  }
}