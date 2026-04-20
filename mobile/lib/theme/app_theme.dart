import 'package:flutter/material.dart';

class AppTheme {
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

  // Colors
  static const primaryColor = Color(0xFF64B5F6);
  static const secondaryColor = Color(0xFF1F6E8A);
  static const accentColor = Color(0xFF2C5364);
  
  static const successColor = Color(0xFF4CAF50);
  static const warningColor = Color(0xFFE67E22);
  static const dangerColor = Color(0xFFE53E3E);
  
  static const cardColor = Color(0x14FFFFFF); // 8% white opacity
  static const cardBorderColor = Color(0x26FFFFFF); // 15% white opacity
  
  // Text colors
  static final textPrimary = Colors.white;
  static final textSecondary = Colors.white.withOpacity(0.7);
  static final textTertiary = Colors.white.withOpacity(0.5);
  
  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: cardBorderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
  
  // Gradient button decoration
  static BoxDecoration gradientButtonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: const LinearGradient(
      colors: [Color(0xFF1F6E8A), Color(0xFF2C5364)],
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1F6E8A).withOpacity(0.4),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
