import 'package:flutter/material.dart';

/// Paleta Fintech Profesional inspirada en los estándares de accesibilidad (WCAG AAA)
/// de Tailwind UI Slate/Teal y apps financieras líderes (Stripe, Revolut).
class AppTheme {
  // --- Colores Base Modo Claro ---
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50 (Evita blanco puro cegador)
  static const Color lightSurface = Color(0xFFFFFFFF); // Blanco puro para tarjetas
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500

  // --- Colores Base Modo Oscuro ---
  static const Color darkBg = Color(0xFF090D16); // Midnight Navy (Evita OLED black absoluto)
  static const Color darkSurface = Color(0xFF131B2E); // Elevated Navy Slate
  static const Color darkSurfaceAlt = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Slate 100
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  // --- Tokens Semánticos Financieros ---
  // Marca / Acento Principal (Teal / Mint)
  static const Color primaryTeal = Color(0xFF0D9488); // Teal 600
  static const Color primaryTealDark = Color(0xFF14B8A6); // Teal 500 (más brillante en dark)

  // Ingresos / Superávit (Emerald)
  static const Color incomeLight = Color(0xFF059669); // Emerald 600
  static const Color incomeDark = Color(0xFF10B981); // Emerald 500
  static const Color incomeBgLight = Color(0xFFECFDF5);
  static const Color incomeBgDark = Color(0xFF064E3B);

  // Gastos / Déficit (Rose / Red)
  static const Color expenseLight = Color(0xFFE11D48); // Rose 600
  static const Color expenseDark = Color(0xFFFB7185); // Rose 400
  static const Color expenseBgLight = Color(0xFFFFF1F2);
  static const Color expenseBgDark = Color(0xFF4C0519);

  // Negocio / Libreta de Fiado (Amber)
  static const Color fiadoLight = Color(0xFFD97706); // Amber 600
  static const Color fiadoDark = Color(0xFFF59E0B); // Amber 500
  static const Color fiadoBgLight = Color(0xFFFFFBEB); // Amber 50
  static const Color fiadoBgDark = Color(0xFF2E1E05); // Dark Amber Surface

  // Préstamos Erika (Violet / Purple)
  static const Color erikaLight = Color(0xFF7C3AED); // Violet 600
  static const Color erikaDark = Color(0xFFA78BFA); // Violet 400
  static const Color erikaBgLight = Color(0xFFF5F3FF); // Violet 50
  static const Color erikaBgDark = Color(0xFF27134A); // Dark Violet Surface

  // Otras Deudas (Indigo / Blue)
  static const Color debtLight = Color(0xFF4F46E5); // Indigo 600
  static const Color debtDark = Color(0xFF818CF8); // Indigo 400
  static const Color debtBgLight = Color(0xFFEEF2FF);
  static const Color debtBgDark = Color(0xFF1E1B4B);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCCFBF1),
      onPrimaryContainer: const Color(0xFF115E59),
      secondary: const Color(0xFF475569),
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceAlt,
      onSurfaceVariant: lightTextSecondary,
      outline: lightBorder,
      outlineVariant: const Color(0xFFCBD5E1),
      error: expenseLight,
      onError: Colors.white,
      errorContainer: expenseBgLight,
      onErrorContainer: const Color(0xFF881337),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBg,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: const Color(0xFFCCFBF1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTeal);
          }
          return const TextStyle(fontSize: 12, color: lightTextSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightSurface,
        indicatorColor: const Color(0xFFCCFBF1),
        selectedIconTheme: const IconThemeData(color: primaryTeal),
        unselectedIconTheme: const IconThemeData(color: lightTextSecondary),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: primaryTeal),
        unselectedLabelTextStyle: const TextStyle(color: lightTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder, thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primaryTealDark,
      onPrimary: const Color(0xFF042F2E),
      primaryContainer: const Color(0xFF134E4A),
      onPrimaryContainer: const Color(0xFF99F6E4),
      secondary: const Color(0xFF94A3B8),
      onSecondary: const Color(0xFF0F172A),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceAlt,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: const Color(0xFF475569),
      error: expenseDark,
      onError: const Color(0xFF4C0519),
      errorContainer: expenseBgDark,
      onErrorContainer: const Color(0xFFFECDD3),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xFF134E4A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryTealDark);
          }
          return const TextStyle(fontSize: 12, color: darkTextSecondary);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xFF134E4A),
        selectedIconTheme: const IconThemeData(color: primaryTealDark),
        unselectedIconTheme: const IconThemeData(color: darkTextSecondary),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: primaryTealDark),
        unselectedLabelTextStyle: const TextStyle(color: darkTextSecondary),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
    );
  }
}
