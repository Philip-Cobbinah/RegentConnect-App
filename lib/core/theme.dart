import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegentColors {
  // Regent Connect's shared palette. The compatibility aliases below keep
  // older screens on-brand while they migrate to the semantic color names.
  static const Color primaryDark = Color(0xFF4A148C);
  static const Color primary = Color(0xFF7B1FA2);
  static const Color primaryBright = Color(0xFF7C4DFF);
  static const Color primarySoft = Color(0xFFF3E5F5);
  static const Color statusAccent = Color(0xFF2E7D32);
  static const Color lightBackground = Color(0xFFFFF9FF);
  static const Color lightSurface = Colors.white;
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkCard = Color(0xFF242747);

  static const Color blue = primary;
  static const Color green = statusAccent;
  static const Color lightBlue = primarySoft;
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color grey = Color(0xFF757575);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color violet = primaryBright;
  static const Color darkViolet = primaryDark;
  static const Color lightViolet = Color(0xFFB388FF);
  static const Color dmBackground = darkBackground;
  static const Color dmSurface = darkSurface;
  static const Color dmCard = darkCard;
}

class AppTheme {
  // Get text theme with Google Fonts
  static TextTheme _getTextTheme(Brightness brightness) {
    final baseTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    try {
      return GoogleFonts.poppinsTextTheme(baseTheme);
    } catch (e) {
      // Fallback to default if Google Fonts fails
      return baseTheme;
    }
  }

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: RegentColors.primary,
    scaffoldBackgroundColor: RegentColors.lightBackground,
    textTheme: _getTextTheme(Brightness.light),
    colorScheme: ColorScheme.fromSeed(
      seedColor: RegentColors.primary,
      brightness: Brightness.light,
      surface: RegentColors.lightSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RegentColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: RegentColors.lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RegentColors.primary, width: 2),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    dividerTheme: DividerThemeData(color: Colors.grey[300]),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.black87,
      iconColor: Colors.black54,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RegentColors.green;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RegentColors.green.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: RegentColors.primary,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RegentColors.primary,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RegentColors.primaryDark,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: RegentColors.lightViolet,
    ),
    useMaterial3: true,
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: RegentColors.primaryBright,
    scaffoldBackgroundColor: RegentColors.darkBackground,
    textTheme: _getTextTheme(Brightness.dark),
    colorScheme: ColorScheme.fromSeed(
      seedColor: RegentColors.primaryBright,
      brightness: Brightness.dark,
      surface: RegentColors.darkSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RegentColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: RegentColors.darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RegentColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF404040)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF404040)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: RegentColors.primaryBright, width: 2),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    dividerTheme: const DividerThemeData(color: Color(0xFF404040)),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white70,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RegentColors.green;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return RegentColors.green.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: RegentColors.darkCard,
      titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: Colors.white70),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RegentColors.darkCard,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: RegentColors.darkCard,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: RegentColors.primaryBright,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RegentColors.primaryBright,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RegentColors.darkCard,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: RegentColors.lightViolet,
    ),
    useMaterial3: true,
  );
}
