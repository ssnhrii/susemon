import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AppTheme {
  // Mesh gradient background
  static const meshBackground = Color(0xFFF0F7FF);

  // Card decoration (glassmorphism)
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Gradient button
  static BoxDecoration gradientButtonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    gradient: const LinearGradient(
      colors: [AppColors.primary, AppColors.primaryContainer],
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.3),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: meshBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
    ),
    useMaterial3: true,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textDim,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
  );
}
