import 'package:flutter/material.dart';

// Decorative background circles
class BackgroundBlobs extends StatelessWidget {
  const BackgroundBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffC8B2FF).withValues(alpha: .45),
            ),
          ),
        ),
        Positioned(
          top: 150,
          left: -120,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffE8DDFF).withValues(alpha: .80),
            ),
          ),
        ),
      ],
    );
  }
}