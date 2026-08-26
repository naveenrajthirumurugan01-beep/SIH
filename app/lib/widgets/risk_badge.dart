import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/risk_zone.dart';

/// Color-coded risk badge. Citizens only ever see the plain-language level
/// (Low/Moderate/High/Critical) — never a raw score.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final bool big;

  const RiskBadge({super.key, required this.level, this.big = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForRisk(level);

    if (!big) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(
          level.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text(
            'CURRENT RISK LEVEL',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            level.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
