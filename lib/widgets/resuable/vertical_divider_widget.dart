import 'package:flutter/material.dart';

class VerticalDividerWidget extends StatelessWidget {
  const VerticalDividerWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 24, 
      thickness: 2, 
      color: Colors.grey,
      indent: 10,
      endIndent: 10, 
    );
  }
}
