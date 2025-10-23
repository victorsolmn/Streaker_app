import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Theme configuration wrapper to make it easy to use colors throughout the app
class ThemeConfig {
  // Primary Brand Colors
  static const Color primaryColor = AppTheme.primaryAccent;  // #FF6B1A - Orange
  static const Color accentColor = AppTheme.accentFlameOrange;  // #FF7733 - Flame Orange

  // Background Colors
  static const Color backgroundColor = AppTheme.backgroundLight;  // White
  static const Color cardBackground = AppTheme.cardBackgroundLight;  // #F8F9FA

  // Text Colors
  static const Color textPrimary = AppTheme.textPrimary;  // #111111
  static const Color textSecondary = AppTheme.textSecondary;  // #4F4F4F

  // Status Colors
  static const Color successColor = AppTheme.successGreen;  // #00D68F
  static const Color warningColor = AppTheme.warningYellow;  // #FFAA00
  static const Color errorColor = AppTheme.errorRed;  // #FF3838

  // Gradient
  static const LinearGradient primaryGradient = AppTheme.primaryGradient;
  static const LinearGradient flameGradient = AppTheme.flameOrangeGradient;
}
