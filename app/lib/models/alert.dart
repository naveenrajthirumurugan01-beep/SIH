import 'risk_zone.dart';

/// A push/SMS-style hazard alert for the study area. Reuses [RiskLevel] for
/// `severity` so alert coloring in the UI matches risk-zone coloring
/// (see core/theme.dart's colorForRisk).
class HazardAlert {
  final String id;
  final String title;
  final String message;
  final RiskLevel severity;
  final double lat;
  final double lng;
  final double radiusKm;
  final String district;
  final DateTime createdAt;

  const HazardAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.district,
    required this.createdAt,
  });

  factory HazardAlert.fromFirestore(String id, Map<String, dynamic> data) {
    return HazardAlert(
      id: id,
      title: data['title'] as String? ?? 'Alert',
      message: data['message'] as String? ?? '',
      severity: RiskLevelX.fromFirestoreValue(data['severity'] as String? ?? 'low'),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (data['radius_km'] as num?)?.toDouble() ?? 5.0,
      district: data['district'] as String? ?? '',
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'message': message,
        'severity': severity.firestoreValue,
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'district': district,
        'created_at': createdAt.toIso8601String(),
      };
}
