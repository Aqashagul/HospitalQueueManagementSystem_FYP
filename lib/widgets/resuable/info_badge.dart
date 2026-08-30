import 'package:flutter/material.dart';

class InfoBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final double iconSize;

  const InfoBadge({
    super.key,
    required this.text,
    this.icon,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0x26FFFFFF),
    this.fontSize = 11,
    this.iconSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: textColor,
              size: iconSize,
            ),
            const SizedBox(width: 4),
          ],

          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}