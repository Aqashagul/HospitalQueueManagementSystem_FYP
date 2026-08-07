import 'package:flutter/material.dart';

class VerticalDividerWidget extends StatelessWidget {
  const VerticalDividerWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 24, // Divider jitni space lega
      thickness: 2, // Line ki thickness
      color: Colors.grey,
      indent: 10, // Upar se gap
      endIndent: 10, // Neeche se gap
    );
  }
}
