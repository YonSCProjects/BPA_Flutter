import 'package:flutter/material.dart';

/// App color constants
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3); // Blue
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  
  // Secondary colors
  static const Color secondary = Color(0xFF4CAF50); // Green
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFF81C784);
  
  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Score gradient colors (for Hebrew scoring)
  static const List<Color> scoreGradient = [
    Color(0xFFE91E63), // Low score
    Color(0xFFFF9800), // Medium-low
    Color(0xFFFFC107), // Medium
    Color(0xFF8BC34A), // Medium-high
    Color(0xFF4CAF50), // High score
  ];
}