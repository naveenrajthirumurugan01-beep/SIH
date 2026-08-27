import 'risk_zone.dart';

/// Where an alert originated. Every alert in this build is currently
/// analyst-issued (see services/alert_repository.dart's doc comment) —
/// [aiRiskEngine]/[sensorAnomaly]/[heavyRainfall]/[citizenReport]/
/// [fieldOfficerVerification] describe what PROMPTED the analyst to issue
/// it, surfaced for context, not an automatic trigger yet.
enum AlertSource { aiRiskEngine, sensorAnomaly, heavyRainfall, citizenReport, fieldOfficerVerification, analystDecision }

extension AlertSourceX on AlertSource {
  String get firestoreValue => switch (this) {
        AlertSource.aiRiskEngine => 'ai_risk_engine',
        AlertSource.sensorAnomaly => 'sensor_anomaly',
        AlertSource.heavyRainfall => 'heavy_rainfall',
        AlertSource.citizenReport => 'citizen_report',
        AlertSource.fieldOfficerVerification => 'field_officer_verification',
        AlertSource.analystDecision => 'analyst_decision',
      };

  String get label => switch (this) {
        AlertSource.aiRiskEngine => 'AI Risk Engine',
        AlertSource.sensorAnomaly => 'Sensor Anomaly',
        AlertSource.heavyRainfall => 'Heavy Rainfall',
        AlertSource.citizenReport => 'Citizen Report',
        AlertSource.fieldOfficerVerification => 'Field Officer Verification',
        AlertSource.analystDecision => 'Analyst Decision',
      };

  static AlertSource fromFirestoreValue(String value) => switch (value) {
        'ai_risk_engine' => AlertSource.aiRiskEngine,
        'sensor_anomaly' => AlertSource.sensorAnomaly,
        'heavy_rainfall' => AlertSource.heavyRainfall,
        'citizen_report' => AlertSource.citizenReport,
        'field_officer_verification' => AlertSource.fieldOfficerVerification,
        _ => AlertSource.analystDecision,
      };
}

/// An alert's place in the Analyst's response workflow.
enum AlertStatus { open, acknowledged, assigned, escalated, resolved }

extension AlertStatusX on AlertStatus {
  String get firestoreValue => switch (this) {
        AlertStatus.open => 'open',
        AlertStatus.acknowledged => 'acknowledged',
        AlertStatus.assigned => 'assigned',
        AlertStatus.escalated => 'escalated',
        AlertStatus.resolved => 'resolved',
      };

  String get label => switch (this) {
        AlertStatus.open => 'Open',
        AlertStatus.acknowledged => 'Acknowledged',
        AlertStatus.assigned => 'Assigned',
        AlertStatus.escalated => 'Escalated',
        AlertStatus.resolved => 'Resolved',
      };

  static AlertStatus fromFirestoreValue(String value) => switch (value) {
        'acknowledged' => AlertStatus.acknowledged,
        'assigned' => AlertStatus.assigned,
        'escalated' => AlertStatus.escalated,
        'resolved' => AlertStatus.resolved,
        _ => AlertStatus.open,
      };
}

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
  final AlertStatus status;
  final AlertSource source;

  /// Short analyst-facing guidance, e.g. "Dispatch field officer within
  /// 6h" — free text, not a structured workflow.
  final String recommendedAction;

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
    this.status = AlertStatus.open,
    this.source = AlertSource.analystDecision,
    this.recommendedAction = '',
  });

  HazardAlert copyWith({AlertStatus? status}) {
    return HazardAlert(
      id: id,
      title: title,
      message: message,
      severity: severity,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      district: district,
      createdAt: createdAt,
      status: status ?? this.status,
      source: source,
      recommendedAction: recommendedAction,
    );
  }

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
      status: AlertStatusX.fromFirestoreValue(data['status'] as String? ?? 'open'),
      source: AlertSourceX.fromFirestoreValue(data['source'] as String? ?? 'analyst_decision'),
      recommendedAction: data['recommended_action'] as String? ?? '',
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
        'status': status.firestoreValue,
        'source': source.firestoreValue,
        'recommended_action': recommendedAction,
      };
}
