import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const primary = Color(0xFFF97316);
  static const primaryDark = Color(0xFFEA580C);
  static const primaryLight = Color(0xFFFFEDD5);

  // Backgrounds
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;

  // Text
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);

  // Borders
  static const border = Color(0xFFE2E8F0);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Sidebar
  static const sidebar = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      centerTitle: true,
    ),
    fontFamily: 'Segoe UI',
  );
}