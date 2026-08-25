import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Small color-coded chip used anywhere a risk level needs a compact label
/// (map markers, list tiles, district summary cards).
class RiskBadge extends StatelessWidget {
  final RiskLevel level;

  const RiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        level.label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
