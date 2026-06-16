import 'package:flutter/material.dart';

/// Tema GeoGuard - Consistente con la app mobile
class AppTheme {
  // ═══════════════════════════════════════════════════════════════════
  // COLORES DE MARCA - GEOGUARD (públicos para uso en la app)
  // ═══════════════════════════════════════════════════════════════════
  static const Color primaryGreen = Color(0xFF1E8E3E);  // Verde GeoGuard (modo claro)
  static const Color primaryGreenDark = Color(0xFF4ade80);  // Verde brillante (modo oscuro)
  static const Color onPrimary = Colors.white;
  static const Color error = Color(0xFFD93025);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  
  // Superficies modo claro
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _backgroundLight = Color(0xFFF8F9FA);
  static const Color _onSurfaceLight = Color(0xFF202124);
  static const Color _onSurfaceVariantLight = Color(0xFF5F6368);
  static const Color _outlineLight = Color(0xFFDADCE0);
  
  // Superficies modo oscuro - Paleta profesional neutra
  static const Color _surfaceDark = Color(0xFF0f0f0f);           // Fondo principal
  static const Color _surfaceContainerDark = Color(0xFF171717);  // Cards/contenedores
  static const Color _onSurfaceDark = Color(0xFFfafafa);         // Texto principal
  static const Color _onSurfaceVariantDark = Color(0xFFa3a3a3);  // Texto secundario
  static const Color _outlineDark = Color(0xFF404040);           // Bordes
  static const Color _outlineVariantDark = Color(0xFF2a2a2a);    // Bordes sutiles

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: onPrimary,
      primaryContainer: Color(0xFFDCF5E3),
      onPrimaryContainer: Color(0xFF0D5425),
      secondary: primaryGreen,
      onSecondary: onPrimary,
      secondaryContainer: Color(0xFFDCF5E3),
      onSecondaryContainer: Color(0xFF0D5425),
      tertiary: primaryGreen,
      onTertiary: onPrimary,
      tertiaryContainer: Color(0xFFDCF5E3),
      onTertiaryContainer: Color(0xFF0D5425),
      error: error,
      onError: onPrimary,
      errorContainer: Color(0xFFFCE8E6),
      onErrorContainer: Color(0xFFC5221F),
      surface: _surfaceLight,
      onSurface: _onSurfaceLight,
      surfaceContainerHighest: _backgroundLight,
      onSurfaceVariant: _onSurfaceVariantLight,
      outline: _outlineLight,
      outlineVariant: Color(0xFFE8EAED),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF303134),
      onInverseSurface: Color(0xFFF1F3F4),
      inversePrimary: primaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _surfaceLight,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceLight,
        foregroundColor: _onSurfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreen, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: onPrimary,
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          shape: const StadiumBorder(),
          side: const BorderSide(color: primaryGreen),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _outlineLight),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      // Colores de marca (verde brillante en oscuro)
      primary: primaryGreenDark,
      onPrimary: Color(0xFF0f0f0f),
      primaryContainer: Color(0xFF22c55e),
      onPrimaryContainer: Color(0xFFfafafa),
      secondary: primaryGreenDark,
      onSecondary: Color(0xFF0f0f0f),
      secondaryContainer: Color(0xFF22c55e),
      onSecondaryContainer: Color(0xFFfafafa),
      tertiary: primaryGreenDark,
      onTertiary: Color(0xFF0f0f0f),
      tertiaryContainer: Color(0xFF22c55e),
      onTertiaryContainer: Color(0xFFfafafa),
      error: Color(0xFFf87171),
      onError: Color(0xFF0f0f0f),
      errorContainer: Color(0xFFef4444),
      onErrorContainer: Color(0xFFfafafa),
      // Superficies (paleta neutra profesional)
      surface: _surfaceDark,
      onSurface: _onSurfaceDark,
      surfaceContainerHighest: _surfaceContainerDark,
      onSurfaceVariant: _onSurfaceVariantDark,
      outline: _outlineDark,
      outlineVariant: _outlineVariantDark,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFfafafa),
      onInverseSurface: Color(0xFF171717),
      inversePrimary: primaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _surfaceDark,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceDark,
        foregroundColor: _onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreenDark, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreenDark,
          foregroundColor: Color(0xFF0f0f0f),
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreenDark,
          shape: const StadiumBorder(),
          side: const BorderSide(color: primaryGreenDark),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainerDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _outlineDark),
        ),
      ),
    );
  }
}
