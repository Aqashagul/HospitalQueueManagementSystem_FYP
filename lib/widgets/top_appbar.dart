import 'package:flutter/material.dart';

class TopAppbar extends StatelessWidget {
  const TopAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF1A1A1A), // sidebar jaisa dark color, match karna
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons
                .local_hospital_outlined, // abhi placeholder, apna logo/icon lagana
            color: Colors.cyanAccent,
            size: 20,
          ),
          const SizedBox(width: 15),
          const Text(
            "Hospital Queue Management System",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
