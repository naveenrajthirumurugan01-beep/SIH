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
      };
}
