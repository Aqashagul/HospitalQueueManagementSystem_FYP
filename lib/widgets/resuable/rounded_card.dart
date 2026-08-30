import 'package:flutter/material.dart';



class RoundedCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const RoundedCard({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? const Color(0xFFF8F1FF))
            : null,

        gradient: gradient,

        borderRadius: BorderRadius.circular(22),

        //  Elegant thin border
        border: Border.all(
          color: const Color(0xFFEAD8F8),
          width: 1,
        ),

        //  Layered soft shadows
        boxShadow: [
          // Purple ambient glow
          BoxShadow(
            color: const Color(0xFF9B4DCA).withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 12),
          ),

          // Main elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 7),
          ),

          // Very soft contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: child,
    );
  }
}