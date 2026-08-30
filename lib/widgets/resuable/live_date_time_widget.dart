import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:queue_management_system/core/app_color.dart';


class LiveDateTimeWidget extends StatefulWidget {
  final Color? textColor;
  final double fontSize;

  const LiveDateTimeWidget({
    super.key,
    this.textColor,
    this.fontSize = 13,
  });

  @override
  State<LiveDateTimeWidget> createState() => _LiveDateTimeWidgetState();
}

class _LiveDateTimeWidgetState extends State<LiveDateTimeWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
   
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];

    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? "PM" : "AM";

    return "$day $month $year   $hour12:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: widget.fontSize + 3,
          color: widget.textColor ?? AppColors.primaryPurple,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDateTime(_now),
          style: GoogleFonts.inter(                          
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            color: widget.textColor ?? Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}