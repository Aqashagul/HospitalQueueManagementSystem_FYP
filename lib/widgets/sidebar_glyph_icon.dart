import 'package:flutter/material.dart';

class SidebarGlyphIcon extends StatelessWidget {
  final Color color;
  final double size;

  const SidebarGlyphIcon({
    super.key,
    required this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: color,
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: size * 0.32,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: color,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}