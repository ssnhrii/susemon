import 'package:flutter/material.dart';

class AppColors {
  // V380 Pro style - deep dark background
  static const bgDark     = Color(0xFF0A0E1A);
  static const bgCard     = Color(0xFF111827);
  static const bgCardAlt  = Color(0xFF1A2235);
  static const cardBorder = Color(0xFF1E2D45);

  // Accent
  static const primary    = Color(0xFF00B4FF);
  static const primaryDim = Color(0xFF0066AA);

  // Status
  static const success    = Color(0xFF00C853);
  static const warning    = Color(0xFFFFAB00);
  static const danger     = Color(0xFFFF1744);
  static const aman       = Color(0xFF00C853);
  static const waspada    = Color(0xFFFFAB00);
  static const berbahaya  = Color(0xFFFF1744);

  // Text
  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFF8899AA);
  static const textDim       = Color(0xFF445566);

  // Gradient
  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0E1A), Color(0xFF0D1525)],
  );

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
        return textSecondary;
    }
  }
}
