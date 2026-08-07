import 'package:flutter/material.dart';

class RoundedCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const RoundedCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}