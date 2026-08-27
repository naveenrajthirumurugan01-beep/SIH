import 'package:flutter/material.dart';

import '../services/risk_factor_provider.dart';

/// One row of the "why is this area high risk" breakdown: a factor name, a
/// filled bar sized by [RiskFactorLevel.barFraction], the HIGH/MODERATE/LOW
/// label, and the underlying detail text (e.g. "35°–55°", "12.4 mm/24h").
class RiskFactorBarRow extends StatelessWidget {
  final RiskFactor factor;

  const RiskFactorBarRow({super.key, required this.factor});

  Color _colorFor(BuildContext context, RiskFactorLevel level) => switch (level) {
        RiskFactorLevel.low => const Color(0xFF2E7D32),
        RiskFactorLevel.moderate => const Color(0xFFF9A825),
        RiskFactorLevel.high => const Color(0xFFC62828),
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, factor.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(factor.name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: factor.level.barFraction,
                minHeight: 14,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              factor.level.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
