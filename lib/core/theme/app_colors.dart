import 'package:flutter/material.dart';

/// Cheffy app color palette
/// Based on the fresh green cooking theme
class AppColors {
  AppColors._();

  // Primary Green Palette
  static const Color primary = Color(0xFF0D9A62);
  static const Color primaryLight = Color(0xFF2EBD81);
  static const Color primaryDark = Color(0xFF087A4E);

  // Background Colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGradientStart = Color(0xFFFFFFFF);
  static const Color backgroundGradientEnd = Color(0xFFFFFFFF);

  /// Standard fresh gradient for all screens
  static const LinearGradient freshGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );

  /// BoxDecoration with the standard fresh gradient
  static BoxDecoration get freshGradientDecoration => const BoxDecoration(
        gradient: freshGradient,
      );

  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color inputBackground = Color(0xFFF0F0F0);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Button Colors
  static const Color buttonApple = Color(0xFF000000);
  static const Color buttonGoogle = Color(0xFFFFFFFF);
  static const Color buttonEmail = Color(0xFF7CB342);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  // Icon Colors
  static const Color iconPrimary = Color(0xFF7CB342);
  static const Color iconSecondary = Color(0xFF757575);
}
