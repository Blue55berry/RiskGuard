/// App-wide typography definitions
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Base font family using Inter
  static String get fontFamily => GoogleFonts.inter().fontFamily!;

  // Heading Styles
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
  );

  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle get displaySmall =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600);

  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );

  static TextStyle get headlineMedium =>
      GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600);

  static TextStyle get headlineSmall =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);

  // Body Styles
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Label Styles
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // Risk Score Typography
  static TextStyle get riskScoreLarge => GoogleFonts.inter(
    fontSize: 64,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
  );

  static TextStyle get riskScoreMedium => GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );

  static TextStyle get riskLabel => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
}
