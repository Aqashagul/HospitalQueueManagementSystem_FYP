import 'package:flutter/material.dart';

class DashboardSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const DashboardSearchBar({
    super.key,
    this.hintText = "Search anything...",
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 212, 212, 212),
          width: 1,
        ),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color.fromARGB(255, 143, 143, 143),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade500,
            size: 21,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}