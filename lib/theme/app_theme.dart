import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors. The palette follows the Meatopia site (visitmeatopia.com): warm cream paper, rust and brick reds, a golden sun.
  static const Color primaryColor = Color(0xFFC04C2E); // rust: buttons, links, icons
  static const Color primaryDark = Color(0xFF9A3D25); // brick
  static const Color primaryLight = Color(0xFFF2A07F); // light terracotta, for tints

  static const Color accentColor = Color(0xFFF6C453); // sun yellow
  static const Color scaffoldBackground = Color(0xFFFEF2DF); // cream paper
  static const Color cardBackground = Color(0xFFFFFDF6); // off-white card

  // headings are deep warm brown, chips and badges the site's orange-red
  static const Color textBrown = Color(0xFF4A2C1D);
  static const Color chipOrange = Color(0xFFE75B37);
  static const Color freshGreen = Color(0xFF8CC63E); // also marks vegetarian dishes, so it stays a clear green
  static const Color textDark = Color(0xFF2B1D14); // warm charcoal
  static const Color textLight = Color(0xFF7A6657);
  static const Color textLightest = Color(0xFFA39384);

  static const Color dividerColor = Color(0xFFEAD9BE);
  static const Color disabledColor = Color(0xFFEAD9BE);
  static const Color border = Color(0xFFE9D5B5); // card and input outlines

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFE75B37), // sunset red-orange
      Color(0xFFF29A3C), // golden orange
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [
      Color(0xFFF6A04D), // sunset glow
      Color(0xFFC84B2B), // rust
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
        displayLarge: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        displayMedium: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        displaySmall: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        headlineLarge: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
          fontSize: 28,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
          fontSize: 26,
          color: textDark,
        ),
        headlineSmall: GoogleFonts.lilitaOne(
          fontWeight: FontWeight.w400,
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
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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
