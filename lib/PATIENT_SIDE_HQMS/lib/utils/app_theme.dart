import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFA25AE6);
  static const Color gradientStart = Color(0xFFBCA8E8);
  static const Color gradientEnd = Color(0xFFA25AE6);
  static const Color background = Color(0xffF8F5FF);
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textGrey = Color(0xFF8A8A8A);
  static const Color cardBorder = Color(0xFFE3E8F0);
    static const Color error = Color(0xFFE74C3C); 
  static const Color success = Color(0xFF2ECC71);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      useMaterial3: true,
    );
  }

  // Reusable gradient for buttons
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}