import 'package:flutter/material.dart';
import '../utils/app_theme.dart';


class InfoBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoBullet({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4),
          ),
        ),
      ],
    );
  }
}