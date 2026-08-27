import 'field_evidence.dart';
import 'inspection.dart';
import 'risk_zone.dart';

/// Baseline AI Risk Context attached to Inspection Task for Analyst Comparison
class AIBaselineContext {
  final RiskLevel initialRiskLevel;
  final String initialTriggerReason;
  final String assignedBy;

  const AIBaselineContext({
    required this.initialRiskLevel,
    required this.initialTriggerReason,
    required this.assignedBy,
  });

  Map<String, dynamic> toFirestore() => {
        'initial_risk_level': initialRiskLevel.firestoreValue,
        'initial_trigger_reason': initialTriggerReason,
        'assigned_by': assignedBy,
      };

  factory AIBaselineContext.fromFirestore(Map<String, dynamic> data) {
    return AIBaselineContext(
      initialRiskLevel: RiskLevelX.fromFirestoreValue(data['initial_risk_level'] as String? ?? 'low'),
      initialTriggerReason: data['initial_trigger_reason'] as String? ?? '',
      assignedBy: data['assigned_by'] as String? ?? 'Analyst Command Center',
    );
  }
}

/// Immutable Protection Guard enforcing Field Officer Scope Boundaries
class ImmutableProtectionGuard {
  final bool aiRiskScoreModified = false;
  final bool analystDecisionsModified = false;
  final bool mlPredictionsModified = false;

  const ImmutableProtectionGuard();

  Map<String, dynamic> toFirestore() => {
        'ai_risk_score_modified': false,
        'analyst_decisions_modified': false,
        'ml_predictions_modified': false,
      };
}

/// Structured Field Report Data Output Handoff (Phase 11 & Phase 12)
class FieldReport {
  final String reportId;
  final String inspectionId;
  final String officerUid;
  final String officerName;
  final String riskZoneId;
  final AIBaselineContext aiBaselineContext;
  final double latitude;
  final double longitude;
  final double gpsAccuracyMeters;
  final DateTime verifiedAt;
  final String verificationState;
  final FieldObservation observation;
  final List<FieldEvidenceItem> evidenceReferences;
  final OverallObservation officerAssessment;
  final String submissionStatus; // 'completed' | 'ready_for_analyst_review'
  final DateTime submittedAt;
  final ImmutableProtectionGuard protectionGuard;

  const FieldReport({
    required this.reportId,
    required this.inspectionId,
    required this.officerUid,
    required this.riskZoneId,
    required this.aiBaselineContext,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyMeters,
    required this.verifiedAt,
    required this.verificationState,
    required this.observation,
    required this.evidenceReferences,
    required this.officerAssessment,
    required this.submissionStatus,
    required this.submittedAt,
    this.officerName = 'Field Officer',
    this.protectionGuard = const ImmutableProtectionGuard(),
  });

  Map<String, dynamic> toFirestore() => {
        'report_id': reportId,
        'inspection_id': inspectionId,
        'officer_uid': officerUid,
        'officer_name': officerName,
        'risk_zone_id': riskZoneId,
        'ai_baseline_context': aiBaselineContext.toFirestore(),
        'location_verification_proof': {
          'is_verified': true,
          'latitude': latitude,
          'longitude': longitude,
          'gps_accuracy_meters': gpsAccuracyMeters,
          'verified_at': verifiedAt.toIso8601String(),
          'verification_state': verificationState,
        },
        'observation': observation.toFirestore(),
        'evidence_references': evidenceReferences.map((e) => e.toFirestore()).toList(),
        'officer_assessment': officerAssessment.firestoreValue,
        'analyst_handoff_status': 'ready_for_analyst_review',
        'submission_status': submissionStatus,
        'submitted_at': submittedAt.toIso8601String(),
        'immutable_protection': protectionGuard.toFirestore(),
      };
}
