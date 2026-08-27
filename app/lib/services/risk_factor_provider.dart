import '../models/risk_zone.dart';

/// Qualitative contribution band for a single risk factor — what the
/// Analyst actually reads off the "why is this area high risk" breakdown.
enum RiskFactorLevel { low, moderate, high }

extension RiskFactorLevelX on RiskFactorLevel {
  String get label => switch (this) {
        RiskFactorLevel.low => 'LOW',
        RiskFactorLevel.moderate => 'MODERATE',
        RiskFactorLevel.high => 'HIGH',
      };

  /// 0–1, used purely for the bar's fill length — not a probability.
  double get barFraction => switch (this) {
        RiskFactorLevel.low => 0.3,
        RiskFactorLevel.moderate => 0.6,
        RiskFactorLevel.high => 1.0,
      };
}

/// One row of the "why is this area high risk" breakdown.
class RiskFactor {
  final String name;
  final RiskFactorLevel level;
  final String detail;

  const RiskFactor({required this.name, required this.level, required this.detail});
}

/// The three risk concepts the Analyst dashboard must keep visibly
/// distinct (see RiskFactorProvider's doc comment for why they're computed
/// the way they are):
///
/// - [susceptibilityScore]: long-term, terrain-only tendency (slope,
///   lithology, LULC, lineaments, historical events) — doesn't change day
///   to day.
/// - [dynamicRiskScore]: current risk given right-now conditions
///   (susceptibility blended with live rainfall/soil moisture) — this is
///   what [RiskZone.riskScore] / [RiskZone.level] represent.
/// - [eventPredictionProbability]: probability of an event inside the
///   prediction window, leaning on the dynamic score plus short-term
///   trend (soil saturation).
class RiskAssessment {
  final double susceptibilityScore;
  final double dynamicRiskScore;
  final double eventPredictionProbability;
  final double confidencePercent;
  final List<RiskFactor> factors;
  final DateTime lastUpdated;
  final String predictionStatus;

  const RiskAssessment({
    required this.susceptibilityScore,
    required this.dynamicRiskScore,
    required this.eventPredictionProbability,
    required this.confidencePercent,
    required this.factors,
    required this.lastUpdated,
    required this.predictionStatus,
  });
}

/// Computes the Analyst dashboard's risk-factor breakdown and the
/// susceptibility/dynamic-risk/event-prediction split from a [RiskZone]'s
/// stored fields.
///
/// There is no trained ML model behind this yet (see AppConfig.useMockData
/// and the project-wide TODOs around a real FastAPI risk engine) — swap in
/// an `MLModelRiskFactorProvider` implementing this same interface once one
/// exists, without touching any UI that consumes it.
abstract class RiskFactorProvider {
  RiskAssessment assess(RiskZone zone);
}

/// SYNTHETIC — replace me. Derives factor bands and the three risk scores
/// from a zone's existing stored fields using simple, documented
/// thresholds. Explicitly demo-shaped, not a scientifically validated
/// prediction — every screen that surfaces this must say so (see
/// AI/ML Risk Status card and the zone detail panel).
class DemoRiskFactorProvider implements RiskFactorProvider {
  RiskFactorLevel _band(double value, double lowMax, double highMin) {
    if (value >= highMin) return RiskFactorLevel.high;
    if (value >= lowMax) return RiskFactorLevel.moderate;
    return RiskFactorLevel.low;
  }

  /// Lithology/LULC don't have a dedicated numeric field (they're free
  /// text describing terrain, not something this prototype measures) — so
  /// their contribution band is a stable pseudo-value seeded off the
  /// zone's id, nudged toward the zone's own overall level so a LOW zone
  /// doesn't randomly get a HIGH lithology contribution. Deterministic
  /// (same zone always yields the same band) rather than re-rolled per
  /// rebuild.
  RiskFactorLevel _pseudoBand(String seed, RiskLevel zoneLevel) {
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final roll = hash % 3;
    final baseline = switch (zoneLevel) {
      RiskLevel.low => 0,
      RiskLevel.moderate => 1,
      RiskLevel.high => 1,
      RiskLevel.critical => 2,
    };
    final blended = ((roll + baseline) / 2).round().clamp(0, 2);
    return RiskFactorLevel.values[blended];
  }

  double _levelScore(RiskFactorLevel level) => switch (level) {
        RiskFactorLevel.low => 0.2,
        RiskFactorLevel.moderate => 0.55,
        RiskFactorLevel.high => 0.9,
      };

  @override
  RiskAssessment assess(RiskZone zone) {
    final slopeBand = _band(zone.slopeMaxDegrees, 25, 45);
    final rainfallBand = _band(zone.rainfall24hMm, 5, 10);
    final soilMoistureBand = _band(zone.soilMoisturePercent, 40, 70);
    final historicalBand = _band(zone.historicalEventCount.toDouble(), 1, 3);
    final lithologyBand = _pseudoBand('${zone.id}-lithology', zone.level);
    final lulcBand = _pseudoBand('${zone.id}-lulc', zone.level);
    final lineamentBand = _band(zone.lineamentDensity, 0.3, 0.6);

    final factors = [
      RiskFactor(name: 'Slope', level: slopeBand, detail: zone.slopeMaxDegrees > 0
          ? '${zone.slopeMinDegrees.toStringAsFixed(0)}°–${zone.slopeMaxDegrees.toStringAsFixed(0)}°'
          : 'No data'),
      RiskFactor(name: 'Rainfall', level: rainfallBand, detail: '${zone.rainfall24hMm.toStringAsFixed(1)} mm/24h'),
      RiskFactor(name: 'Soil Moisture', level: soilMoistureBand, detail: '${zone.soilMoisturePercent.toStringAsFixed(0)}%'),
      RiskFactor(name: 'Lithology', level: lithologyBand, detail: zone.lithology),
      RiskFactor(name: 'LULC', level: lulcBand, detail: zone.lulc),
      RiskFactor(name: 'Lineaments', level: lineamentBand, detail: 'Density ${zone.lineamentDensity.toStringAsFixed(2)}'),
      RiskFactor(
        name: 'Historical',
        level: historicalBand,
        detail: '${zone.historicalEventCount} recorded event${zone.historicalEventCount == 1 ? '' : 's'}',
      ),
    ];

    // Susceptibility: static/terrain factors only — doesn't move with
    // today's weather.
    final susceptibility = (_levelScore(slopeBand) +
            _levelScore(lithologyBand) +
            _levelScore(lulcBand) +
            _levelScore(lineamentBand) +
            _levelScore(historicalBand)) /
        5;

    // Dynamic risk: the zone's stored/authoritative current score when
    // set, otherwise a susceptibility-plus-current-conditions blend.
    final dynamicRisk = zone.riskScore > 0
        ? zone.riskScore
        : (susceptibility * 0.6 + (_levelScore(rainfallBand) + _levelScore(soilMoistureBand)) / 2 * 0.4)
            .clamp(0.0, 1.0);

    // Event prediction: leans on the dynamic score, nudged by how
    // saturated the ground is right now.
    final eventPrediction =
        (dynamicRisk * 0.85 + (zone.soilMoisturePercent / 100) * 0.15).clamp(0.0, 1.0);

    final confidence = zone.confidencePercent > 0 ? zone.confidencePercent : 60.0;

    final predictionStatus = switch (zone.level) {
      RiskLevel.critical => 'Critical — immediate attention',
      RiskLevel.high => 'Elevated Risk',
      RiskLevel.moderate => 'Watch',
      RiskLevel.low => 'Stable',
    };

    return RiskAssessment(
      susceptibilityScore: susceptibility,
      dynamicRiskScore: dynamicRisk,
      eventPredictionProbability: eventPrediction,
      confidencePercent: confidence,
      factors: factors,
      lastUpdated: zone.updatedAt,
      predictionStatus: predictionStatus,
    );
  }
}
