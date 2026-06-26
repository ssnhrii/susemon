import 'package:flutter/material.dart';

class AppColors {
  // Light theme - matching design system
  static const bgLight = Color(0xFFF9F9FF);
  static const bgDark = Color(0xFFF0F7FF); // fallback compat
  static const bgCard = Color(0xFFFFFFFF);
  static const bgCardAlt = Color(0xFFF2F3FD);
  static const cardBorder = Color(0xFFC2C6D6);

  // Primary brand (design system blue)
  static const primary = Color(0xFF0058BE);
  static const primaryContainer = Color(0xFF2170E4);
  static const primaryDim = Color(0xFFADC6FF);
  static const onPrimary = Color(0xFFFFFFFF);

  // Surface shades
  static const surface = Color(0xFFF9F9FF);
  static const surfaceContainerLow = Color(0xFFF2F3FD);
  static const surfaceContainer = Color(0xFFECEDF7);
  static const surfaceContainerHigh = Color(0xFFE6E7F2);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const inverseSource = Color(0xFF2E3038);

  // Status
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFBA1A1A);
  static const aman = Color(0xFF4CAF50);
  static const waspada = Color(0xFFF59E0B);
  static const berbahaya = Color(0xFFBA1A1A);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Text
  static const textPrimary = Color(0xFF191B23);
  static const textSecondary = Color(0xFF424754);
  static const textDim = Color(0xFF727785);
  static const onSurface = Color(0xFF191B23);
  static const onSurfaceVariant = Color(0xFF424754);
  static const outline = Color(0xFF727785);
  static const outlineVariant = Color(0xFFC2C6D6);

  // Gradient background (mesh)
  static const meshGradientColors = [
    Color(0xFFEBF8FF),
    Color(0xFFE0F0FF),
    Color(0xFFE8F4FC),
    Color(0xFFF3FAFC),
  ];

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BERBAHAYA':
      case 'CRITICAL':
      case 'HIGH':
        return danger;
      case 'WASPADA':
      case 'WARNING':
      case 'MEDIUM':
        return warning;
      case 'AMAN':
      case 'NORMAL':
      case 'LOW':
        return success;
      default:
        return textDim;
    }
  }

  // Glass card decoration
  static BoxDecoration glassCard({double radius = 16, Color? borderColor}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
