import 'package:latlong2/latlong.dart';

enum RiskLevel { low, moderate, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.moderate => 'Moderate',
        RiskLevel.high => 'High',
        RiskLevel.critical => 'Very High',
      };

  String get firestoreValue => switch (this) {
        RiskLevel.low => 'low',
        RiskLevel.moderate => 'moderate',
        RiskLevel.high => 'high',
        RiskLevel.critical => 'critical',
      };

  static RiskLevel fromScore(double score) {
    if (score >= 0.75) return RiskLevel.critical;
    if (score >= 0.50) return RiskLevel.high;
    if (score >= 0.25) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  static RiskLevel fromFirestoreValue(String value) => switch (value) {
        'moderate' => RiskLevel.moderate,
        'high' => RiskLevel.high,
        'critical' => RiskLevel.critical,
        _ => RiskLevel.low,
      };
}

/// Interface / Data Model for Landslide Risk Zones.
/// Designed for future integration with ML/FastAPI backend (raster/polygons).
class RiskZone {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusKm;
  final double riskScore;
  final RiskLevel level;
  final String district;
  final DateTime updatedAt;
  final String? notes;

  // Geographic Polygon points for semi-transparent heatmap overlay
  final List<LatLng> polygonPoints;

  // Risk factor breakdowns (Slope, Rainfall, Soil Moisture, History)
  final String slopeFactor;
  final String rainfallFactor;
  final String soilMoistureFactor;
  final String historyFactor;

  const RiskZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.riskScore,
    required this.level,
    required this.district,
    required this.updatedAt,
    this.notes,
    this.polygonPoints = const [],
    this.slopeFactor = 'MODERATE',
    this.rainfallFactor = 'MODERATE',
    this.soilMoistureFactor = 'MODERATE',
    this.historyFactor = 'LOW',
  });

  factory RiskZone.fromFirestore(String id, Map<String, dynamic> data) {
    final score = (data['risk_score'] as num?)?.toDouble() ?? 0.15;
    return RiskZone(
      id: id,
      name: data['name'] as String? ?? 'Unnamed zone',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (data['radius_km'] as num?)?.toDouble() ?? 2.0,
      riskScore: score,
      level: RiskLevelX.fromScore(score),
      district: data['district'] as String? ?? 'Dibang Valley',
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now(),
      notes: data['notes'] as String?,
      slopeFactor: data['slope_factor'] as String? ?? 'MODERATE',
      rainfallFactor: data['rainfall_factor'] as String? ?? 'HIGH',
      soilMoistureFactor: data['soil_moisture_factor'] as String? ?? 'HIGH',
      historyFactor: data['history_factor'] as String? ?? 'MODERATE',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'risk_score': riskScore,
        'level': level.firestoreValue,
        'district': district,
        'updated_at': updatedAt.toIso8601String(),
        'notes': notes,
        'slope_factor': slopeFactor,
        'rainfall_factor': rainfallFactor,
        'soil_moisture_factor': soilMoistureFactor,
        'history_factor': historyFactor,
      };

  RiskZone copyWith({
    double? riskScore,
    RiskLevel? level,
    double? radiusKm,
    String? notes,
    String? rainfallFactor,
    String? soilMoistureFactor,
  }) {
    final newScore = riskScore ?? this.riskScore;
    return RiskZone(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm ?? this.radiusKm,
      riskScore: newScore,
      level: level ?? RiskLevelX.fromScore(newScore),
      district: district,
      updatedAt: updatedAt,
      notes: notes ?? this.notes,
      polygonPoints: polygonPoints,
      slopeFactor: slopeFactor,
      rainfallFactor: rainfallFactor ?? this.rainfallFactor,
      soilMoistureFactor: soilMoistureFactor ?? this.soilMoistureFactor,
      historyFactor: historyFactor,
    );
  }
}
