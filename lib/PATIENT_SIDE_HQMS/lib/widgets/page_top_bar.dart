import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'notification_bell.dart';

/// Same top spacing and height for every main tab screen.
/// Use it as the FIRST child, directly inside SafeArea + horizontal padding 20.
class PageTopBar extends StatelessWidget {
  final String title;
  final bool showBell;

  const PageTopBar({super.key, required this.title, this.showBell = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46, // same as the bell, so the title never shifts
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (showBell) const NotificationBell(),
        ],
      ),
    );
  }
}