import 'package:flutter/material.dart';

/// App-wide color constants matching the Angular SCSS design.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0D1B40);
  static const Color backgroundDark = Color(0xFF07152F);
  static const Color backgroundLight = Color(0xFF142452);
  static const Color surface = Color(0xFF1A2D5A);
  static const Color surfaceLight = Color(0xFF213568);

  // Cell colors
  static const Color cellGreen = Color(0xFF22C55E);
  static const Color cellYellow = Color(0xFFF4B400);
  static const Color cellGrey = Color(0xFF3B4A6B);
  static const Color cellGreyDark = Color(0xFF2A3756);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF7B8DB0);

  // Accents
  static const Color gold = Color(0xFFF4B400);
  static const Color goldDark = Color(0xFF7A5C00);
  static const Color greenAccent = Color(0xFF4ADE80);
  static const Color redAccent = Color(0xFFFCA5A5);
  static const Color purpleAccent = Color(0xFFE879F9);
  static const Color yellowAccent = Color(0xFFFCD34D);

  // Difficulty colors
  static const Color diffEasy = Color(0xFF4ADE80);
  static const Color diffMedium = Color(0xFFFCD34D);
  static const Color diffHard = Color(0xFFFCA5A5);
  static const Color diffExpert = Color(0xFFE879F9);

  // Buttons
  static const Color buttonPrimary = Color(0xFF22C55E);
  static const Color buttonSecondary = Color(0xFF1A2D5A);

  // Coin badge
  static const Color coinBg = Color(0x33F4B400);
}

/// Shared text styles.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );
}

/// Standard gradient used across the app.
const appBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF07152F), Color(0xFF0D1B40), Color(0xFF142452)],
  stops: [0.0, 0.4, 1.0],
);

/// Standard border for glass-style containers.
Border glassBorder = Border.all(color: Colors.white.withValues(alpha: 0.06));
BorderRadius glassBorderRadius = BorderRadius.circular(13);
