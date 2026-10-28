import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF081426);
  static const surface = Color(0xFF05080D);
  static const panel = Color(0xFF101F34);
  static const accent = Color(0xFF9BC5FF);
  static const text = Color(0xFFF5F7FA);
  static const muted = Color(0xFFADBDD1);
  static const positive = Color(0xFF91E1C0);
  static const negative = Color(0xFFFFA7B5);
}

ThemeData pocketTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    secondary: AppColors.positive,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.text,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 16),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
  ),
);
