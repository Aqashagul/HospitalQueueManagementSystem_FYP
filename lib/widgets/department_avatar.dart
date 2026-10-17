import 'package:flutter/material.dart';
import 'package:queue_management_system/models/department_model.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';

// >>> KEEP YOUR OTHER EXISTING IMPORTS HERE <<<
// (Department and InitialsAvatar, from the same paths your other files
//  use.)

// Shows the department's picture when the admin added one, otherwise the
// usual initials avatar.
class DepartmentAvatar extends StatelessWidget {
  final Department department;

  // Size of the picture. Change it to match your InitialsAvatar.
  final double size;

  const DepartmentAvatar({
    super.key,
    required this.department,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = department.photoBytes;

    if (bytes == null || bytes.isEmpty) {
      return InitialsAvatar(name: department.name);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            InitialsAvatar(name: department.name),
      ),
    );
  }
}