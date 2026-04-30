import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors derived from the Findly mockups.
class FindlyColors {
  const FindlyColors._();

  // Gradient stops (top → bottom on splash / brand surfaces)
  static const Color gradientTop = Color(0xFFA9F0DD); // mint / cyan
  static const Color gradientMid = Color(0xFF8FB7FA); // light blue
  static const Color gradientBottom = Color(0xFF8273F0); // lavender / violet

  // Pastel surface gradient (used inside notification screens, profile, etc.)
  static const Color surfaceTop = Color(0xFFD8F5E5);
  static const Color surfaceMid = Color(0xFFD9E4FA);
  static const Color surfaceBottom = Color(0xFFEAE2FA);

  // Brand mark accents
  static const Color brandGreen = Color(0xFF3BD68D); // the dot on the "i"
  static const Color brandPurple = Color(0xFF7B6CE8);

  // Text + neutrals
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF7B7E8C);
  static const Color textOnGradient = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color appBackground = Color(0xFFF6F8FB);

  // Status accents
  static const Color successGreen = Color(0xFF3BD68D);
  static const Color warningRed = Color(0xFFE5484D);
  static const Color pendingBlue = Color(0xFF6B8CFF);
}

/// Vertical gradient used for the splash and onboarding hero areas.
const LinearGradient brandGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    FindlyColors.gradientTop,
    FindlyColors.gradientMid,
    FindlyColors.gradientBottom,
  ],
);

/// Soft pastel gradient used as the background of in-app screens.
const LinearGradient surfaceGradient = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [
    FindlyColors.surfaceTop,
    FindlyColors.surfaceMid,
    FindlyColors.surfaceBottom,
  ],
);

ThemeData buildFindlyTheme() {
  final base = ThemeData(useMaterial3: true);
  final textTheme = GoogleFonts.heeboTextTheme(base.textTheme).apply(
    bodyColor: FindlyColors.textPrimary,
    displayColor: FindlyColors.textPrimary,
  );

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: FindlyColors.brandPurple,
      primary: FindlyColors.brandPurple,
      secondary: FindlyColors.brandGreen,
      surface: FindlyColors.cardBackground,
    ),
    scaffoldBackgroundColor: FindlyColors.appBackground,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: FindlyColors.textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.heebo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: FindlyColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: FindlyColors.cardBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black12,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E5EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E5EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FindlyColors.brandPurple, width: 1.5),
      ),
      labelStyle: GoogleFonts.heebo(color: FindlyColors.textSecondary),
      hintStyle: GoogleFonts.heebo(color: FindlyColors.textSecondary.withValues(alpha: 0.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        minimumSize: const Size.fromHeight(56),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FindlyColors.warningRed,
        textStyle: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: FindlyColors.warningRed),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        minimumSize: const Size.fromHeight(56),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
