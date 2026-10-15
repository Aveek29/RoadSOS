import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  RoadSoS Design Tokens — Material 3
// ─────────────────────────────────────────────

class RoadSoSColors {
  // Core backgrounds (Dark)
  static const bgDeepDark      = Color(0xFF0B1020);
  static const bgCardDark      = Color(0xFF151A2D);
  static const bgElevatedDark  = Color(0xFF1F263E);
  static const bgSheetDark     = Color(0xFF2A3352);

  // Core backgrounds (Light)
  static const bgDeepLight     = Color(0xFFF4F6F9);
  static const bgCardLight     = Color(0xFFFFFFFF);
  static const bgElevatedLight = Color(0xFFE9EDF4);
  static const bgSheetLight    = Color(0xFFDCE3F0);

  // Semantic Alerts (Public-Safety)
  static const critical        = Color(0xFFFF3B30); // Critical Accident Red
  static const warning         = Color(0xFFF59E0B); // Warning/Calibrating Amber
  static const success         = Color(0xFF22C55E); // Active/Connected Info Green
  static const rescueTeal      = Color(0xFF22C55E); // Helper/Success Green
  static const volunteerPurple = Color(0xFF8B5CF6); // Volunteer Mode Purple

  // Dim / Container States
  static const redDim          = Color(0xFF381414);
  static const amberDim        = Color(0xFF3B2806);
  static const tealDim         = Color(0xFF0A331A);
  static const purpleDim       = Color(0xFF26103E);

  // Deprecated direct accesses fallback mappings
  static const accentRed       = critical;
  static const accentAmber     = warning;
  static const accentTeal      = rescueTeal;
  static const accentPurple    = volunteerPurple;
  static const bgDeep          = bgDeepDark;
  static const bgCard          = bgCardDark;
  static const bgElevated      = bgElevatedDark;

  // Text Colors (Dark)
  static const textPrimaryDark   = Color(0xFFEDF2FF);
  static const textSecondaryDark = Color(0xFF7B8DB0);
  static const textMutedDark     = Color(0xFF3D5080);

  // Text Colors (Light)
  static const textPrimaryLight   = Color(0xFF0C1524);
  static const textSecondaryLight = Color(0xFF5A6A85);
  static const textMutedLight     = Color(0xFF8B9BB4);

  // Fallbacks for direct usage in old screens
  static const textPrimary       = textPrimaryDark;
  static const textSecondary     = textSecondaryDark;
  static const textMuted         = textMutedDark;

  // Borders
  static const borderDark        = Color(0xFF222B45);
  static const borderLight       = Color(0xFFD5DFEE);
  static const border            = borderDark;
}

class RoadSoSTheme {
  // Common TextTheme Helper
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor, Color mutedColor) {
    return TextTheme(
      // Display: Giant countdown numerals
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w900,
        color: primaryColor,
        letterSpacing: -1.5,
      ),
      // Headings: Screen titles and state indicators
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        color: primaryColor,
        fontSize: 28,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        color: primaryColor,
        fontSize: 22,
        letterSpacing: -0.3,
      ),
      // Subheadings: Telemetry titles
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: primaryColor,
        fontSize: 18,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: secondaryColor,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        color: mutedColor,
        fontSize: 11,
        letterSpacing: 1.0,
      ),
      // Body Text: Instructions and descriptions
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: primaryColor,
        fontSize: 15,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        fontSize: 13,
        height: 1.4,
      ),
      // Captions & Metadata
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: mutedColor,
        fontSize: 11,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  // Dark Theme Definition
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: RoadSoSColors.critical,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        surface:          RoadSoSColors.bgCardDark,
        onSurface:        RoadSoSColors.textPrimaryDark,
        primary:          RoadSoSColors.critical,
        onPrimary:        Colors.white,
        secondary:        RoadSoSColors.rescueTeal,
        onSecondary:      Colors.white,
        tertiary:         RoadSoSColors.warning,
        error:            RoadSoSColors.critical,
        surfaceContainerHighest: RoadSoSColors.bgElevatedDark,
      ),
      scaffoldBackgroundColor: RoadSoSColors.bgDeepDark,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: RoadSoSColors.bgCardDark,
        foregroundColor: RoadSoSColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: RoadSoSColors.textPrimaryDark,
          letterSpacing: 0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RoadSoSColors.bgCardDark,
        indicatorColor: RoadSoSColors.redDim,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: RoadSoSColors.critical, size: 24);
          }
          return const IconThemeData(color: RoadSoSColors.textMutedDark, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? RoadSoSColors.critical : RoadSoSColors.textMutedDark,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: RoadSoSColors.bgElevatedDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: RoadSoSColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: RoadSoSColors.borderDark,
      dividerTheme: const DividerThemeData(
        color: RoadSoSColors.borderDark,
        thickness: 1,
        space: 0,
      ),
      textTheme: _buildTextTheme(
        RoadSoSColors.textPrimaryDark,
        RoadSoSColors.textSecondaryDark,
        RoadSoSColors.textMutedDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RoadSoSColors.bgElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.critical),
        ),
        hintStyle: const TextStyle(color: RoadSoSColors.textMutedDark),
        labelStyle: const TextStyle(color: RoadSoSColors.textSecondaryDark),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: RoadSoSColors.bgElevatedDark,
        contentTextStyle: TextStyle(color: RoadSoSColors.textPrimaryDark),
      ),
    );
  }

  // Light Theme Definition
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: RoadSoSColors.critical,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        surface:          RoadSoSColors.bgCardLight,
        onSurface:        RoadSoSColors.textPrimaryLight,
        primary:          RoadSoSColors.critical,
        onPrimary:        Colors.white,
        secondary:        RoadSoSColors.rescueTeal,
        onSecondary:      Colors.white,
        tertiary:         RoadSoSColors.warning,
        error:            RoadSoSColors.critical,
        surfaceContainerHighest: RoadSoSColors.bgElevatedLight,
      ),
      scaffoldBackgroundColor: RoadSoSColors.bgDeepLight,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: RoadSoSColors.bgCardLight,
        foregroundColor: RoadSoSColors.textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: RoadSoSColors.textPrimaryLight,
          letterSpacing: 0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RoadSoSColors.bgCardLight,
        indicatorColor: RoadSoSColors.critical.withOpacity(0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: RoadSoSColors.critical, size: 24);
          }
          return const IconThemeData(color: RoadSoSColors.textMutedLight, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? RoadSoSColors.critical : RoadSoSColors.textMutedLight,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: RoadSoSColors.bgCardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RoadSoSColors.borderLight),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: RoadSoSColors.borderLight,
      dividerTheme: const DividerThemeData(
        color: RoadSoSColors.borderLight,
        thickness: 1,
        space: 0,
      ),
      textTheme: _buildTextTheme(
        RoadSoSColors.textPrimaryLight,
        RoadSoSColors.textSecondaryLight,
        RoadSoSColors.textMutedLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RoadSoSColors.bgElevatedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RoadSoSColors.critical),
        ),
        hintStyle: const TextStyle(color: RoadSoSColors.textMutedLight),
        labelStyle: const TextStyle(color: RoadSoSColors.textSecondaryLight),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: RoadSoSColors.bgCardLight,
        contentTextStyle: TextStyle(color: RoadSoSColors.textPrimaryLight),
      ),
    );
  }
}
