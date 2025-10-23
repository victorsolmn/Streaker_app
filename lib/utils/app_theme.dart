import 'package:flutter/material.dart';

class AppTheme {
  // Brand Identity Colors - Consistent across both themes
  static const Color primaryAccent = Color(0xFFFF6B1A);  // Primary accent color
  static const Color primaryHover = Color(0xFFFF8C42);   // Primary hover state
  
  // Theme-specific Secondary Colors
  static const Color secondaryDark = Color(0xFF4A90E2);   // Secondary for dark theme
  static const Color secondaryLight = Color(0xFF2D7EF5);  // Secondary for light theme
  
  // Background Colors - Light theme
  static const Color backgroundLight = Color(0xFFFFFFFF);  // Pure white background
  static const Color cardBackgroundLight = Color(0xFFF8F9FA);  // Light card/surface
  static const Color backgroundWhite = Colors.white;  // Keep for compatibility
  
  // Dark theme backgrounds
  static const Color darkBackground = Color(0xFF121212);  // Dark background
  static const Color darkCardBackground = Color(0xFF1C1C1E);  // Dark card/surface
  static const Color darkSurface = Color(0xFF1C1C1E);  // Same as card for consistency
  
  // Legacy dark theme (for compatibility)
  static const Color primaryBackground = Color(0xFF121212);
  static const Color secondaryBackground = Color(0xFF1C1C1E);
  
  // Text Colors - Light theme
  static const Color textPrimary = Color(0xFF111111);  // Primary text for light theme
  static const Color textSecondary = Color(0xFF4F4F4F);  // Secondary text for light theme
  static const Color textLight = Color(0xFF4F4F4F);  // Keep for compatibility
  
  // Text Colors - Dark theme
  static const Color textPrimaryDark = Color(0xFFFFFFFF);  // Primary text for dark theme
  static const Color textSecondaryDark = Color(0xFFB3B3B3);  // Secondary text for dark theme
  
  // Flame/Fire Inspired Accent Colors
  static const Color accentFlameRed = Color(0xFFFF4444);    // Bright flame red
  static const Color accentFlameYellow = Color(0xFFFFBB33); // Flame yellow/orange
  static const Color accentFlameOrange = Color(0xFFFF7733); // Mid flame orange
  static const Color accentEmber = Color(0xFFCC4400);       // Deep ember

  // Keep essential functional colors
  static const Color accentGreen = Color(0xFF00D68F);  // Success green
  static const Color accentYellow = Color(0xFFFFAA00);  // Warning yellow
  static const Color accentPink = Color(0xFFFF6B9D);  // Pink
  static const Color accentCyan = Color(0xFF00C9FF);  // Cyan
  
  // Status Colors
  static const Color successGreen = Color(0xFF00D68F);
  static const Color warningYellow = Color(0xFFFFAA00);
  static const Color errorRed = Color(0xFFFF3838);
  static const Color infoBlue = Color(0xFF0095FF);

  // Alias for compatibility
  static const Color success = Color(0xFF00D68F);
  static const Color error = Color(0xFFFF3838);
  
  // Dividers
  static const Color dividerDark = Color(0xFF2E2E2E);  // Divider for dark theme
  static const Color dividerLight = Color(0xFFE0E0E0);  // Divider for light theme
  static const Color borderColor = Color(0xFFE0E0E0);  // Keep for compatibility
  static const Color dividerColor = Color(0xFFE0E0E0);  // Keep for compatibility
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryAccent, primaryHover],
  );
  
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryAccent, primaryHover],
  );
  
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [secondaryLight, Color(0xFF4D8EF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Flame/Fire Inspired Gradients for Chat UI
  static const LinearGradient flameRedGradient = LinearGradient(
    colors: [accentFlameRed, Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient flameOrangeGradient = LinearGradient(
    colors: [accentFlameOrange, accentFlameYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emberGradient = LinearGradient(
    colors: [accentEmber, accentFlameRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF8A50), Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Keep some original gradients as alternatives
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFF2D7EF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentGreen, Color(0xFF00E5A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryAccent.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  // Helper method to get theme-aware card shadow
  static List<BoxShadow> getCardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.06),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // Helper method to get theme-aware subtle shadow
  static List<BoxShadow> getSubtleShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.4)
            : Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: backgroundLight,
      
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        secondary: secondaryLight,
        surface: cardBackgroundLight,
        background: backgroundLight,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundLight,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textLight, fontSize: 14),
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBackgroundLight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundLight,
        selectedItemColor: primaryAccent,
        unselectedItemColor: textLight,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      
      dividerTheme: const DividerThemeData(
        color: dividerLight,
        thickness: 1,
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: darkBackground,
      
      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryDark,
        surface: darkCardBackground,
        background: darkBackground,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onBackground: textPrimaryDark,
        onError: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: darkCardBackground,
        foregroundColor: textPrimaryDark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimaryDark, size: 24),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
        hintStyle: TextStyle(color: textSecondaryDark.withOpacity(0.5), fontSize: 14),
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCardBackground,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCardBackground,
        selectedItemColor: primaryAccent,
        unselectedItemColor: textSecondaryDark,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      
      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimaryDark,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondaryDark,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondaryDark,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondaryDark,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}