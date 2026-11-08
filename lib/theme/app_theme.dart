import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors. A quiet warm-white canvas so the saturated food photos carry the colour, and one tomato-red action colour.
  // Contrast (WCAG): white on primary 5.0:1, text on canvas 16:1, secondary text on canvas 5.6:1.
  static const Color primaryColor = Color(0xFFC8401C); // tomato: buttons, links, active states
  static const Color primaryDark = Color(0xFFA33316);
  static const Color primaryLight = Color(0xFFF4CDBF); // light tint of the action colour

  static const Color accentColor = Color(0xFFF2A33A); // amber: deals and stars
  static const Color scaffoldBackground = Color(0xFFFAF7F2); // warm white canvas
  static const Color cardBackground = Colors.white;

  static const Color textBrown = Color(0xFF1F1A17); // headings (kept under its old name)
  static const Color chipOrange = Color(0xFFC8401C); // badges and highlights: the same tomato, so there is one accent
  static const Color freshGreen = Color(0xFF2E7D32); // vegetarian and success
  static const Color textDark = Color(0xFF1F1A17);
  static const Color textLight = Color(0xFF6B625B);
  static const Color textLightest = Color(0xFF70675F);

  static const Color dividerColor = Color(0xFFE7DFD3);
  static const Color disabledColor = Color(0xFFE7DFD3);
  static const Color border = Color(0xFFE7DFD3); // card and input outlines

  // Gradients: kept for the few icon tiles that use them, but nearly flat
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFC8401C),
      Color(0xFFD9542B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [
      Color(0xFFD9542B),
      Color(0xFFC8401C),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: cardBackground,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      
      // Typography
      textTheme: GoogleFonts.nunitoSansTextTheme().copyWith(
        displayLarge: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        displayMedium: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        displaySmall: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        headlineLarge: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          fontSize: 26,
          color: textDark,
        ),
        headlineSmall: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w800,
          fontSize: 24,
          color: textDark,
        ),
        titleLarge: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textDark,
        ),
        titleMedium: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textDark,
        ),
        titleSmall: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textLight,
        ),
        bodySmall: GoogleFonts.nunitoSans(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: textLightest,
        ),
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(), // Pill-shaped
          textStyle: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0, // Enforce flat look with custom soft shadow
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      
      // Page Transitions Theme
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
        },
      ),
      
      // Input Fields (TextFormField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: GoogleFonts.nunitoSans(color: textDark, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.nunitoSans(color: textLightest, fontSize: 14),
        prefixIconColor: textLight,
        suffixIconColor: textLight,
      ),
    );
  }
}

class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}
