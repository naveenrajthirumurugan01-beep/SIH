// Citizen-facing theme constants — deep forest green as seen in the reference design.
// All citizen screens import this instead of AppTheme to keep a consistent palette.
import 'package:flutter/material.dart';

import '../models/risk_zone.dart';

class CitizenTheme {
  CitizenTheme._();

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const primary = Color(0xFF1A5C38);       // dark forest green
  static const primaryLight = Color(0xFF2E7D52);
  static const surface = Colors.white;
  static const background = Color(0xFFF5F7F5);

  // ── Risk colours (Low→Critical) ────────────────────────────────────────────
  static const low      = Color(0xFF4CAF50); // green
  static const moderate = Color(0xFFFFA726); // amber
  static const high     = Color(0xFFEF6C00); // deep orange
  static const veryHigh = Color(0xFFD32F2F); // red

  static Color forLevel(RiskLevel level) => switch (level) {
        RiskLevel.low      => low,
        RiskLevel.moderate => moderate,
        RiskLevel.high     => high,
        RiskLevel.critical => veryHigh,
      };

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primary.withAlpha(30),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}
