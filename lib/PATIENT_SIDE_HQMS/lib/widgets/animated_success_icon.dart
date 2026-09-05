import 'package:flutter/material.dart';
import '../utils/app_theme.dart';


class AnimatedSuccessIcon extends StatefulWidget {
  const AnimatedSuccessIcon({super.key});

  @override
  State<AnimatedSuccessIcon> createState() => _AnimatedSuccessIconState();
}

class _AnimatedSuccessIconState extends State<AnimatedSuccessIcon>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scaleAnimation = CurvedAnimation(parent: _entryController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
          
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double size = 100 + (_pulseAnimation.value * 40);
                final double opacity = 1 - _pulseAnimation.value;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: opacity * 0.25),
                  ),
                );
              },
            ),


            // Main solid circle with checkmark
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
               color: Colors.green,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: .35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 54),
            ),
          ],
        ),
      ),
    );
  }
}