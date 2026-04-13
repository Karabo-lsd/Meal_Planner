import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4CAF50); // Fresh green
  static const Color primaryLight = Color(0xFF81C784);
  static const Color primaryDark = Color(0xFF388E3C);

  // Accent Colors
  static const Color accent = Color(0xFFFF6B6B); // Coral
  static const Color accentLight = Color(0xFFFF9999);
  static const Color accentDark = Color(0xFFCC5555);

  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);

  // Special Colors
  static const Color shadow = Color(0x1F000000); // 12% black
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color divider = Color(0xFFE0E0E0);

  // Gradient Colors
  static const List<Color> primaryGradient = [primary, primaryDark];
  static const List<Color> accentGradient = [accent, accentDark];

  // Food Category Colors
  static const Color protein = Color(0xFFFF6B6B);
  static const Color carbs = Color(0xFF4CAF50);
  static const Color fat = Color(0xFFFF9800);
  static const Color fiber = Color(0xFF9C27B0);
  static const Color sugar = Color(0xFFE91E63);
}
