import 'package:latlong2/latlong.dart';

/// Citizen-facing risk classification. Deliberately just four plain-language
/// bands (no raw ML scores/jargon surfaced to citizens) — see
/// core/theme.dart for the color mapping used throughout the Citizen UI.
enum RiskLevel { low, moderate, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.moderate => 'Moderate',
        RiskLevel.high => 'High',
        RiskLevel.critical => 'Critical',
      };

  String get firestoreValue => switch (this) {
        RiskLevel.low => 'low',
        RiskLevel.moderate => 'moderate',
        RiskLevel.high => 'high',
        RiskLevel.critical => 'critical',
      };

  static RiskLevel fromFirestoreValue(String value) => switch (value) {
        'moderate' => RiskLevel.moderate,
        'high' => RiskLevel.high,
        'critical' => RiskLevel.critical,
        _ => RiskLevel.low,
      };
}

/// A point-based risk zone (a village, known slide scar, or monitored slope)
/// somewhere inside the Anini/Etalin study area. Backed either by
/// MockRiskRepository (synthetic, seeded) or FirestoreRiskRepository (reads
/// the `risk_zones` collection) — see lib/services/risk_repository.dart.
///
/// The extra fields below (risk score, confidence, slope/rainfall/soil
/// moisture/lithology/LULC/lineaments, historical events, nearest road) back
/// the Analyst dashboard's zone-detail panel and "why is this high risk"
/// factor breakdown (see services/risk_factor_provider.dart). They're all
/// demo/placeholder-shaped — see AppConfig.useMockData and
/// RiskFactorProvider's doc comment — not the output of a real trained
/// model, so every one of them defaults to a clearly-zero/neutral value
/// rather than a fabricated number when a Firestore doc doesn't set it.
class RiskZone {
  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Approximate radius (km) over which this zone's risk level is
  /// considered representative, used for "nearest zone to me" lookups.
  final double radiusKm;
  final RiskLevel level;
  final String district;
  final DateTime updatedAt;
  final String? notes;

  /// Overall AI risk score in [0, 1] — demo-derived, see
  /// RiskFactorProvider's doc comment. Not a validated model output.
  final double riskScore;

  /// Model confidence in [0, 100] — demo-derived.
  final double confidencePercent;

  final double slopeMinDegrees;
  final double slopeMaxDegrees;

  /// Rainfall (mm) over the last 24h attributed to this zone — demo-derived
  /// until a real weather provider is wired up (see
  /// services/weather_provider.dart once that exists).
  final double rainfall24hMm;

  /// Soil moisture in [0, 100] — demo-derived.
  final double soilMoisturePercent;

  final int historicalEventCount;
  final double nearestRoadKm;

  /// Short descriptive text, not a validated geological survey.
  final String lithology;

  /// Land Use / Land Cover — short descriptive text.
  final String lulc;

  /// Lineament (fracture/fault line) density in [0, 1] — demo-derived.
  final double lineamentDensity;

  /// Optional polygon boundary for a future map heatmap overlay. Not yet
  /// populated from Firestore by any repository — always empty until a
  /// real polygon source exists.
  final List<LatLng> polygonPoints;

  const RiskZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.level,
    required this.district,
    required this.updatedAt,
    this.notes,
    this.riskScore = 0,
    this.confidencePercent = 0,
    this.slopeMinDegrees = 0,
    this.slopeMaxDegrees = 0,
    this.rainfall24hMm = 0,
    this.soilMoisturePercent = 0,
    this.historicalEventCount = 0,
    this.nearestRoadKm = 0,
    this.lithology = 'Unknown',
    this.lulc = 'Unknown',
    this.lineamentDensity = 0,
    this.polygonPoints = const [],
  });

  factory RiskZone.fromFirestore(String id, Map<String, dynamic> data) {
    return RiskZone(
      id: id,
      name: data['name'] as String? ?? 'Unnamed zone',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (data['radius_km'] as num?)?.toDouble() ?? 2.0,
      level: RiskLevelX.fromFirestoreValue(data['level'] as String? ?? 'low'),
      district: data['district'] as String? ?? '',
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
      notes: data['notes'] as String?,
      riskScore: (data['risk_score'] as num?)?.toDouble() ?? 0,
      confidencePercent: (data['confidence_percent'] as num?)?.toDouble() ?? 0,
      slopeMinDegrees: (data['slope_min_degrees'] as num?)?.toDouble() ?? 0,
      slopeMaxDegrees: (data['slope_max_degrees'] as num?)?.toDouble() ?? 0,
      rainfall24hMm: (data['rainfall_24h_mm'] as num?)?.toDouble() ?? 0,
      soilMoisturePercent: (data['soil_moisture_percent'] as num?)?.toDouble() ?? 0,
      historicalEventCount: (data['historical_event_count'] as num?)?.toInt() ?? 0,
      nearestRoadKm: (data['nearest_road_km'] as num?)?.toDouble() ?? 0,
      lithology: data['lithology'] as String? ?? 'Unknown',
      lulc: data['lulc'] as String? ?? 'Unknown',
      lineamentDensity: (data['lineament_density'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'level': level.firestoreValue,
        'district': district,
        'updated_at': updatedAt.toIso8601String(),
        'notes': notes,
        'risk_score': riskScore,
        'confidence_percent': confidencePercent,
        'slope_min_degrees': slopeMinDegrees,
        'slope_max_degrees': slopeMaxDegrees,
        'rainfall_24h_mm': rainfall24hMm,
        'soil_moisture_percent': soilMoisturePercent,
        'historical_event_count': historicalEventCount,
        'nearest_road_km': nearestRoadKm,
        'lithology': lithology,
        'lulc': lulc,
        'lineament_density': lineamentDensity,
      };
}
