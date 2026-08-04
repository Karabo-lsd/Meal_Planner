import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: AppColors.primaryDark,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.accentLight,
      onTertiaryContainer: AppColors.accentDark,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerLight,
      onErrorContainer: AppColors.dangerDark,
      background: AppColors.background,
      onBackground: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: const Color(0xFFF0F4F1),
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
    );
    final textTheme = GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.08,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.12,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.22,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textHint,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      canvasColor: colorScheme.background,
      dividerColor: AppColors.border,
      iconTheme: const IconThemeData(color: AppColors.primaryDark),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.cardBackground,
        shadowColor: AppColors.shadow,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.84),
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        checkmarkColor: colorScheme.primary,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: AppColors.primary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: AppColors.border),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.borderLight,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return AppColors.border;
        }),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primaryLight,
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.darkTextPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.darkBackground,
      secondaryContainer: AppColors.secondaryDark,
      onSecondaryContainer: AppColors.darkTextPrimary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.darkBackground,
      tertiaryContainer: AppColors.accentDark,
      onTertiaryContainer: AppColors.darkTextPrimary,
      error: AppColors.dangerLight,
      onError: AppColors.darkBackground,
      errorContainer: AppColors.dangerDark,
      onErrorContainer: AppColors.darkTextPrimary,
      background: AppColors.darkBackground,
      onBackground: AppColors.darkTextPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkCardBackground,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderLight,
    );

    return lightTheme.copyWith(
      colorScheme: colorScheme,

      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,

      textTheme: lightTheme.textTheme.apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),

      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),

      cardTheme: lightTheme.cardTheme.copyWith(color: AppColors.darkCardBackground),

      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: AppColors.darkCardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),

      navigationBarTheme: lightTheme.navigationBarTheme.copyWith(
        backgroundColor: AppColors.darkSurface.withValues(alpha: 0.98),
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.16),
      ),
    );
  }
}
