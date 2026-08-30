import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';


// StatCards for Departments, Doctors, Patients 
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String value;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.upperCaseText),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Initials avatar 
class InitialsAvatar extends StatelessWidget {
  final String name;

  const InitialsAvatar({super.key, required this.name});

 
  String get _initials {
    
    final cleanedName = name
        .replaceAll(RegExp(r'^(Dr\.?|Mr\.?|Ms\.?|Mrs\.?|Prof\.?)\s*', caseSensitive: false), '')
        .trim();

    final target = cleanedName.isEmpty ? name.trim() : cleanedName;


    final words = target.split(RegExp(r'[\s.]+')).where((w) => w.isNotEmpty).toList();

    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    if (words.isNotEmpty) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return "?"; 
  }

  Color get _bgColor {
    const palette = [
      Color(0xFFE4D9F9),
      Color(0xFFD6EAF8),
      Color(0xFFFCE8D5),
      Color(0xFFFAF3D0),
      Color(0xFFD9F2E6),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  Color get _textColor {
    const palette = [
      Color(0xFF8E5FD9),
      Color(0xFF3B82C4),
      Color(0xFFD98A3D),
      Color(0xFFB8A020),
      Color(0xFF34A870),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

//Status pill — Active/Inactive, Waiting/Completed
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  Color get _bgColor {
    switch (status.toLowerCase()) {
      case "active":
      case "available": 
      case "completed":
        return const Color(0xFFD4EDDA);
      case "waiting":
        return const Color(0xFFFFF3CD);
      case "in consultation":
        return const Color(0xFFD6EAF8);
      case "inactive":
      case "cancelled":
      case "unavailable": 
        return const Color(0xFFF8D7DA);
    //  case "completed":
      //return const Color(0xFFD4EDDA);
      default:
        return Colors.grey.shade200;
    }
  }

  Color get _textColor {
    switch (status.toLowerCase()) {
      case "active":
      case "completed":
      case "available":    
        return const Color(0xFF2E7D32);
      case "waiting":
        return const Color(0xFFB8860B);
      case "in consultation":
        return const Color(0xFF3B82C4);
      case "inactive":
      case "unavailable":     
      case "cancelled":
        return const Color(0xFFC62828);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}