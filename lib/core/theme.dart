import 'package:flutter/material.dart';

class AppColors {
  static const Color navy = Color(0xFF0F172A);
  static const Color navyDeep = Color(0xFF070D1B);
  static const Color navyMid = Color(0xFF172554);
  static const Color navySoft = Color(0xFF1E293B);
  static const Color blueAccent = Color(0xFF1E3A8A);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color auroraCyan = Color(0xFF38BDF8);
  static const Color auroraIndigo = Color(0xFF6366F1);
  static const Color sky = Color(0xFF0284C7);
  static const Color gold = Color(0xFFD4AF37);
  static const Color amber = Color(0xFFF59E0B);
  static const Color emerald = Color(0xFF10B981);
  static const Color rose = Color(0xFFFB7185);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color muted = Color(0xFF64748B);
}

ThemeData buildBungteminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    secondary: AppColors.gold,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sky, width: 1.6),
      ),
    ),
  );
}
