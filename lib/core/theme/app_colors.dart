/// App-wide color definitions for the Digital Risk Detection System
/// Uses risk-based color coding: Green (Safe), Yellow (Medium), Red (High Risk)
import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5B4BD5);
  static const Color primaryLight = Color(0xFF8B7CF6);

  // Background Colors
  static const Color backgroundDark = Color(0xFF0D0D1A);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF16213E);
  static const Color cardLight = Color(0xFFF1F3F5);

  // Risk Level Colors
  static const Color riskLow = Color(0xFF00D68F); // Green - Safe
  static const Color riskMedium = Color(0xFFFFAA00); // Amber - Caution
  static const Color riskHigh = Color(0xFFFF3D71); // Red - Danger
  static const Color riskUnknown = Color(0xFF8F9BB3); // Gray - Unknown

  // Risk Level Gradients
  static const LinearGradient riskLowGradient = LinearGradient(
    colors: [Color(0xFF00D68F), Color(0xFF00B87C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient riskMediumGradient = LinearGradient(
    colors: [Color(0xFFFFAA00), Color(0xFFFF8800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient riskHighGradient = LinearGradient(
    colors: [Color(0xFFFF3D71), Color(0xFFFF0044)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB4B4C7);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Accent Colors
  static const Color accent = Color(0xFF00D9FF);
  static const Color success = Color(0xFF00D68F);
  static const Color warning = Color(0xFFFFAA00);
  static const Color error = Color(0xFFFF3D71);
  static const Color info = Color(0xFF0095FF);

  // Overlay Colors
  static const Color overlayDark = Color(0xCC000000);
  static const Color overlayLight = Color(0x80FFFFFF);

  // Card Glassmorphism
  static const Color glassDark = Color(0x1AFFFFFF);
  static const Color glassLight = Color(0x80FFFFFF);

  // Get risk color based on score (0-100)
  static Color getRiskColor(int score) {
    if (score <= 30) return riskLow;
    if (score <= 70) return riskMedium;
    return riskHigh;
  }

  // Get risk gradient based on score
  static LinearGradient getRiskGradient(int score) {
    if (score <= 30) return riskLowGradient;
    if (score <= 70) return riskMediumGradient;
    return riskHighGradient;
  }
}
