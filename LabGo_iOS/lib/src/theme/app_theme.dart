import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primaryColor = Color(0xFF8378F4);
  static const Color primaryLight = Color(0xFF9D94F7);
  static const Color primaryDark = Color(0xFF6B5FE0);

  static const Color secondaryColor = Color(0xFFF4A900);
  static const Color secondaryLight = Color(0xFFF7BA3D);
  static const Color secondaryDark = Color(0xFFD49100);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryColor],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryLight, secondaryColor],
  );

  // Text Theme with Cairo Font
  static TextTheme _getTextTheme(TextTheme base) {
    return TextTheme(
      // Display Styles
      displayLarge: GoogleFonts.cairo(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: gray900,
      ),
      displayMedium: GoogleFonts.cairo(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: gray900,
      ),
      displaySmall: GoogleFonts.cairo(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: gray900,
      ),

      // Headline Styles
      headlineLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),

      // Title Styles
      titleLarge: GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: gray900,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: gray900,
      ),

      // Body Styles
      bodyLarge: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: gray700,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: gray700,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: gray600,
      ),

      // Label Styles
      labelLarge: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      labelMedium: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: gray700,
      ),
      labelSmall: GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: gray600,
      ),
    );
  }

  static TextTheme get _textTheme => _getTextTheme(ThemeData().textTheme);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      onPrimary: white,
      primaryContainer: primaryLight.withOpacity(0.1),
      onPrimaryContainer: primaryDark,
      secondary: secondaryColor,
      onSecondary: white,
      secondaryContainer: secondaryLight.withOpacity(0.1),
      onSecondaryContainer: secondaryDark,
      surface: white,
      onSurface: gray900,
      error: error,
      onError: white,
      outline: gray300,
      outlineVariant: gray200,
      background: gray50,
      onBackground: gray900,
    ),

    scaffoldBackgroundColor: gray50,
    textTheme: _textTheme,
    fontFamily: GoogleFonts.cairo().fontFamily,

    // App Bar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: white,
      foregroundColor: gray900,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      iconTheme: IconThemeData(
        color: gray900,
        size: 24,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gray200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 2),
      ),
      labelStyle: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: gray600,
      ),
      hintStyle: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: gray400,
      ),
      prefixIconColor: gray400,
      suffixIconColor: gray400,
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: primaryColor,
        foregroundColor: white,
        textStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        minimumSize: const Size(double.infinity, 56),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor, width: 2),
        textStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(double.infinity, 56),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        foregroundColor: primaryColor,
        textStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: primaryColor,
      foregroundColor: white,
      iconSize: 24,
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 8,
      backgroundColor: white,
      selectedItemColor: primaryColor,
      unselectedItemColor: gray400,
      selectedLabelStyle: GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: gray200,
      thickness: 1,
      space: 1,
    ),

    // Icon Theme
    iconTheme: IconThemeData(
      color: gray600,
      size: 24,
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: gray100,
      selectedColor: primaryColor.withOpacity(0.1),
      labelStyle: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: gray700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // Dialog Theme
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: white,
      elevation: 8,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: gray900,
      ),
      contentTextStyle: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: gray700,
      ),
    ),

    // Snack Bar Theme
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: gray900,
      contentTextStyle: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: white,
      ),
      elevation: 8,
    ),
  );
}
