import 'package:flutter/material.dart';

class HebrewTheme {
  // Hebrew Font Family (using system fonts for now)
  static const String? hebrewFontFamily = null; // 'HebrewFont';
  
  // Color Palette
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color primaryColorDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFB00020);
  static const Color textColor = Color(0xFF000000);
  static const Color secondaryTextColor = Color(0xFF757575);
  
  // Text Styles for Hebrew RTL
  static const TextStyle hebrewTitleStyle = TextStyle(
    fontFamily: hebrewFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textColor,
  );
  
  static const TextStyle hebrewSubtitleStyle = TextStyle(
    fontFamily: hebrewFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textColor,
  );
  
  static const TextStyle hebrewBodyStyle = TextStyle(
    fontFamily: hebrewFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textColor,
  );
  
  static const TextStyle hebrewLabelStyle = TextStyle(
    fontFamily: hebrewFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
  );
  
  static const TextStyle hebrewHintStyle = TextStyle(
    fontFamily: hebrewFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: secondaryTextColor,
  );
  
  // Input Field Decoration for Hebrew RTL
  static InputDecoration hebrewInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      labelStyle: hebrewLabelStyle,
      hintStyle: hebrewHintStyle,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
        borderSide: BorderSide(color: primaryColor, width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignLabelWithHint: true,
    );
  }
  
  // Main Theme Data with RTL Support
  static ThemeData get hebrewThemeData {
    return ThemeData(
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryColorDark,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textColor,
        onError: Colors.white,
      ),
      
      // Font Family
      fontFamily: hebrewFontFamily,
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: hebrewTitleStyle,
        displayMedium: hebrewSubtitleStyle,
        bodyLarge: hebrewBodyStyle,
        bodyMedium: hebrewBodyStyle,
        labelLarge: hebrewLabelStyle,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: hebrewFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: hebrewLabelStyle,
        hintStyle: hebrewHintStyle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: hebrewFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // Use Material 3
      useMaterial3: true,
    );
  }
  
  // RTL Text Direction Helper
  static TextDirection get textDirection => TextDirection.rtl;
  
  // Spacing Constants
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Border Radius
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
}