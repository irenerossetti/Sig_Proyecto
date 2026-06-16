import 'package:flutter/material.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════
  // COLORES DE MARCA - IGUALES EN AMBOS MODOS
  // ═══════════════════════════════════════════════════════════════════
  static const Color _primaryGreen = Color(0xFF1E8E3E);  // Verde GeoGuard/Google Maps
  static const Color _onPrimary = Colors.white;
  static const Color _error = Color(0xFFD93025);         // Rojo Google
  
  // ═══════════════════════════════════════════════════════════════════
  // MODO CLARO - Fondos y superficies
  // ═══════════════════════════════════════════════════════════════════
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _backgroundLight = Color(0xFFF8F9FA);
  static const Color _onSurfaceLight = Color(0xFF202124);
  static const Color _onSurfaceVariantLight = Color(0xFF5F6368);
  static const Color _outlineLight = Color(0xFFDADCE0);
  static const Color _outlineVariantLight = Color(0xFFE8EAED);
  
  // ═══════════════════════════════════════════════════════════════════
  // MODO OSCURO - Fondos y superficies (paleta profesional neutra)
  // ═══════════════════════════════════════════════════════════════════
  static const Color _surfaceDark = Color(0xFF0f0f0f);         // Fondo principal
  static const Color _surfaceContainerDark = Color(0xFF171717); // Tarjetas
  static const Color _onSurfaceDark = Color(0xFFfafafa);
  static const Color _onSurfaceVariantDark = Color(0xFFa3a3a3);
  static const Color _outlineDark = Color(0xFF404040);          // Bordes
  static const Color _outlineVariantDark = Color(0xFF2a2a2a);   // Bordes suaves
  
  // Verde más brillante para modo oscuro
  static const Color _primaryGreenDark = Color(0xFF4ade80);

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      // Colores de marca (IGUALES en ambos modos)
      primary: _primaryGreen,
      onPrimary: _onPrimary,
      primaryContainer: Color(0xFFDCF5E3),
      onPrimaryContainer: Color(0xFF0D5425),
      secondary: _primaryGreen,
      onSecondary: _onPrimary,
      secondaryContainer: Color(0xFFDCF5E3),
      onSecondaryContainer: Color(0xFF0D5425),
      tertiary: _primaryGreen,
      onTertiary: _onPrimary,
      tertiaryContainer: Color(0xFFDCF5E3),
      onTertiaryContainer: Color(0xFF0D5425),
      error: _error,
      onError: _onPrimary,
      errorContainer: Color(0xFFFCE8E6),
      onErrorContainer: Color(0xFFC5221F),
      // Superficies (cambian según el modo)
      surface: _surfaceLight,
      onSurface: _onSurfaceLight,
      surfaceContainerHighest: _backgroundLight,
      onSurfaceVariant: _onSurfaceVariantLight,
      outline: _outlineLight,
      outlineVariant: _outlineVariantLight,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF303134),
      onInverseSurface: Color(0xFFF1F3F4),
      inversePrimary: _primaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _surfaceLight,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceLight,
        foregroundColor: _onSurfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
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
          borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: _onPrimary,
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: _surfaceLight,
        indicatorColor: Color(0xFFDCF5E3),
      ),
      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryGreen,
        foregroundColor: _onPrimary,
      ),
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      // Colores de marca (verde más brillante en oscuro)
      primary: _primaryGreenDark,
      onPrimary: Color(0xFF0f0f0f),
      primaryContainer: Color(0xFF22c55e),
      onPrimaryContainer: Color(0xFFfafafa),
      secondary: _primaryGreenDark,
      onSecondary: Color(0xFF0f0f0f),
      secondaryContainer: Color(0xFF22c55e),
      onSecondaryContainer: Color(0xFFfafafa),
      tertiary: _primaryGreenDark,
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
      inversePrimary: _primaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _surfaceDark,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceDark,
        foregroundColor: _onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
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
          borderSide: const BorderSide(color: _primaryGreenDark, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryGreenDark,
          foregroundColor: Color(0xFF0f0f0f),
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreenDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _primaryGreenDark.withValues(alpha: 0.15),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainerDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryGreenDark,
        foregroundColor: Color(0xFF0f0f0f),
      ),
      // ListTile theme para modo oscuro
      listTileTheme: ListTileThemeData(
        tileColor: _surfaceContainerDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: _outlineDark,
      ),
    );
  }
}

