import 'package:flutter/material.dart';

class AppColors {
  // Dark gradient background
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F2027),
      Color(0xFF203A43),
      Color(0xFF2C5364),
    ],
  );

  // Primary colors
  static const primary = Color(0xFF64B5F6);
  static const secondary = Color(0xFF1F6E8A);
  static const accent = Color(0xFF2C5364);
  
  // Status colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFE67E22);
  static const danger = Color(0xFFE53E3E);
  static const aman = Color(0xFF4CAF50);
  static const waspada = Color(0xFFE67E22);
  static const berbahaya = Color(0xFFE53E3E);
  
  // Card colors
  static const cardBg = Color(0x14FFFFFF); // 8% white
  static const cardBorder = Color(0x26FFFFFF); // 15% white
  
  // Text colors
  static const textPrimary = Colors.white;
  static final textSecondary = Colors.white.withOpacity(0.7);
  static final textTertiary = Colors.white.withOpacity(0.5);
  
  // Background colors
  static final bgOverlay = Colors.black.withOpacity(0.3);
  static final bgCard = Colors.white.withOpacity(0.08);
}
