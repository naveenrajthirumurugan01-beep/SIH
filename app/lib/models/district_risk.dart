import '../core/constants/app_constants.dart';

class DistrictRisk {
  final String district;
  final String state;
  final RiskLevel riskLevel;
  final double riskScore;
  final double lat;
  final double lng;
  final double? rainfall24hMm;
  final double? slopeAvgDegrees;
  final DateTime updatedAt;

  const DistrictRisk({
    required this.district,
    required this.state,
    required this.riskLevel,
    required this.riskScore,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    this.rainfall24hMm,
    this.slopeAvgDegrees,
  });

  factory DistrictRisk.fromJson(Map<String, dynamic> json) {
    return DistrictRisk(
      district: json['district'] as String,
      state: json['state'] as String? ?? '',
      riskLevel: RiskLevelX.fromString(json['risk_level'] as String),
      riskScore: (json['risk_score'] as num).toDouble(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      rainfall24hMm: (json['rainfall_mm_24h'] as num?)?.toDouble(),
      slopeAvgDegrees: (json['slope_avg_degrees'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
