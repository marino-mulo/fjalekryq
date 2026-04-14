import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color constants matching the web design.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0D1B40);
  static const Color backgroundDark = Color(0xFF07152F);
  static const Color backgroundLight = Color(0xFF142452);
  static const Color surface = Color(0xFF1A2D5A);
  static const Color surfaceLight = Color(0xFF213568);
  static const Color modalBg = Color(0xFF0F2251);
  static const Color modalBgDark = Color(0xFF0A1A3E);

  // Cell colors
  static const Color cellGreen = Color(0xFF22C55E);
  static const Color cellYellow = Color(0xFFF4B400);
  static const Color cellGrey = Color(0xFF3B4A6B);
  static const Color cellGreyDark = Color(0xFF2A3756);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF7B8DB0);
  static const Color cream = Color(0xFFFFF8F0);

  // Accents
  static const Color gold = Color(0xFFF4B400);
  static const Color goldDark = Color(0xFF7A5C00);
  static const Color greenAccent = Color(0xFF4ADE80);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color redAccent = Color(0xFFFCA5A5);
  static const Color purpleAccent = Color(0xFFA855F7);
  static const Color purpleDark = Color(0xFF7C3AED);
  static const Color yellowAccent = Color(0xFFFCD34D);
  static const Color pinkAccent = Color(0xFFE879F9);

  // Difficulty colors
  static const Color diffEasy = Color(0xFF4ADE80);
  static const Color diffMedium = Color(0xFFFCD34D);
  static const Color diffHard = Color(0xFFFCA5A5);
  static const Color diffExpert = Color(0xFFE879F9);

  // Buttons
  static const Color buttonPrimary = Color(0xFFA855F7); // Purple CTA
  static const Color buttonSecondary = Color(0xFF1A2D5A);

  // Coin badge
  static const Color coinBg = Color(0x33F4B400);
}

/// Font helpers using Google Fonts.
class AppFonts {
  AppFonts._();

  static TextStyle nunito({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle quicksand({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = Colors.white,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.quicksand(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

/// Shared text styles.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get title => AppFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );

  static TextStyle get subtitle => AppFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static TextStyle get body => AppFonts.quicksand(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get button => AppFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w900,
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

/// Modal gradient matching web design.
const modalGradient = LinearGradient(
  begin: Alignment(-0.5, -1),
  end: Alignment(0.5, 1),
  colors: [Color(0xFF0F2251), Color(0xFF0A1A3E)],
);

/// Standard border for glass-style containers.
Border glassBorder = Border.all(color: Colors.white.withValues(alpha: 0.12));
BorderRadius glassBorderRadius = BorderRadius.circular(13);

/// Glass button style helper.
BoxDecoration glassDecoration({
  Color? color,
  Color? borderColor,
  double borderRadius = 12,
  double borderWidth = 1.5,
  List<BoxShadow>? shadows,
}) {
  return BoxDecoration(
    color: color ?? Colors.white.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: borderColor ?? Colors.white.withValues(alpha: 0.2),
      width: borderWidth,
    ),
    boxShadow: shadows,
  );
}

/// Purple glass button decoration (primary CTA).
BoxDecoration purpleGlassDecoration({bool expanded = false}) {
  return glassDecoration(
    color: AppColors.purpleAccent.withValues(alpha: 0.22),
    borderColor: AppColors.purpleAccent.withValues(alpha: 0.5),
    borderRadius: expanded ? 18 : 12,
    shadows: [
      BoxShadow(
        color: AppColors.purpleAccent.withValues(alpha: 0.4),
        blurRadius: 16,
      ),
    ],
  );
}

/// Coin icon widget matching web SVG.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: AppFonts.nunito(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: AppColors.goldDark,
        ),
      ),
    );
  }
}
