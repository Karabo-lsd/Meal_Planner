import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2F8F4E);
  static const Color primaryLight = Color(0xFFBEEBCB);
  static const Color primaryDark = Color(0xFF145C33);

  // Accent Colors
  static const Color accent = Color(0xFFFF8A3D);
  static const Color accentLight = Color(0xFFFFD6B3);
  static const Color accentDark = Color(0xFFE56C1E);

  static const Color secondary = Color(0xFF77C587);
  static const Color secondaryLight = Color(0xFFDDF6E3);
  static const Color secondaryDark = Color(0xFF3E8D58);

  static const Color info = Color(0xFF4B8CF6);
  static const Color infoLight = Color(0xFFDCE9FF);
  static const Color infoDark = Color(0xFF245FD7);

  static const Color warning = Color(0xFFF2B544);
  static const Color warningLight = Color(0xFFFFE7B8);
  static const Color warningDark = Color(0xFFCB8A12);

  static const Color danger = Color(0xFFE35D5D);
  static const Color dangerLight = Color(0xFFFAD8D8);
  static const Color dangerDark = Color(0xFFC53939);

  // Background Colors
  static const Color background = Color(0xFFF6F8F5);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  static const Color darkBackground = Color(0xFF0F1511);
  static const Color darkSurface = Color(0xFF17201B);
  static const Color darkCardBackground = Color(0xFF1D2721);

  // Text Colors
  static const Color textPrimary = Color(0xFF15231A);
  static const Color textSecondary = Color(0xFF52655A);
  static const Color textHint = Color(0xFF7A8E82);

  static const Color darkTextPrimary = Color(0xFFE1ECE4);
  static const Color darkTextSecondary = Color(0xFFA7B8AE);
  static const Color darkTextHint = Color(0xFF7F9186);

  // Status Colors
  static const Color success = Color(0xFF46B36A);
  static const Color error = danger;

  // Border Colors
  static const Color border = Color(0xFFDDE7DF);
  static const Color borderLight = Color(0xFFF0F4F1);
  static const Color darkBorder = Color(0xFF27352D);
  static const Color darkBorderLight = Color(0xFF34423B);

  // Special Colors
  static const Color shadow = Color(0x14000000);
  static const Color overlay = Color(0x80000000);
  static const Color divider = Color(0xFFE5ECE7);

  // Gradient Colors
  static const List<Color> primaryGradient = [primary, primaryDark];
  static const List<Color> accentGradient = [accent, accentDark];
  static const List<Color> heroGradient = [Color(0xFF2F8F4E), Color(0xFF65B56F), Color(0xFFF5FAF5)];

  // Food Category Colors
  static const Color protein = Color(0xFF2F8F4E);
  static const Color carbs = Color(0xFF4B8CF6);
  static const Color fat = Color(0xFFFF8A3D);
  static const Color fiber = Color(0xFF77C587);
  static const Color sugar = Color(0xFFF2B544);
}
