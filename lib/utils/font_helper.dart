import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontHelper {
  static TextStyle montserrat({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.montserrat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'system',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      );
    }
  }

  // Pre-defined text styles for common use cases
  static TextStyle get heading1 => montserrat(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get heading2 => montserrat(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get heading3 => montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => montserrat(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => montserrat(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => montserrat(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get button => montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );
} 