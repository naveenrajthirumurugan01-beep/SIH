import 'package:flutter/material.dart';

import '../models/risk_zone.dart';

/// Theme + the citizen-facing risk color scale (Low/Moderate/High/Critical).
/// Kept deliberately separate from core/theme/app_theme.dart, which backs
/// the earlier multi-role scaffold and its own RiskLevel enum.
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF1B5E20);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      );

  /// Green/amber/orange/red for low/moderate/high/critical risk — the only
  /// color language shown to citizens (never raw scores).
  static Color colorForRisk(RiskLevel level) => switch (level) {
        RiskLevel.low => const Color(0xFF2E7D32),
        RiskLevel.moderate => const Color(0xFFF9A825),
        RiskLevel.high => const Color(0xFFEF6C00),
        RiskLevel.critical => const Color(0xFFC62828),
      };
}
