import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// White rounded card look, shared by the track queue widgets.
BoxDecoration appCardDecoration({double radius = 22}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );