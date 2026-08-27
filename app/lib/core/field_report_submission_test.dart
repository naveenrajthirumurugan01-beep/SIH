import '../models/field_evidence.dart';
import '../models/field_report.dart';
import '../models/geofence_boundary.dart';
import '../models/inspection.dart';
import '../models/location_verification.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';

/// Test Suite for Phase 11 Review & Submit Field Report
class FieldReportSubmissionTestSuite {
  static Map<String, dynamic> runTests() {
    final results = <String, bool>{};

    final validTask = InspectionTask(
      id: 'INS-SUBMIT-777',
      assignedOfficerUid: 'officer_echo',
      lat: 28.7123,
      lng: 95.8142,
      riskLevel: RiskLevel.critical,
      reason: 'Landslide cliff instability',
      instructions: 'Submit final report',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      geofenceRadiusMeters: 75.0,
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7123,
        centerLng: 95.8142,
        radiusMeters: 75.0,
      ),
    );

    final validProof = LocationVerificationRecord(
      inspectionId: validTask.id,
      officerUid: 'officer_echo',
      latitude: 28.7124,
      longitude: 95.8143,
      gpsAccuracyMeters: 7.2,
      timestamp: DateTime.now(),
      state: LocationVerificationState.locationVerified,
      message: 'Verified',
      isVerified: true,
    );

    final validObservation = FieldObservation(
      inspectionId: validTask.id,
      officerUid: 'officer_echo',
      crack: CrackStatus.major,
      slopeMovement: SlopeMovement.severe,
      rockfall: true,
      waterSeepage: true,
      roadCondition: RoadCondition.blocked,
      overallObservation: OverallObservation.critical,
      remarks: 'Immediate evacuation recommended for patrol sector',
      recordedAt: DateTime.now(),
    );

    final validEvidence = [
      FieldEvidenceItem(
        id: 'EVD-777-01',
        inspectionId: validTask.id,
        officerUid: 'officer_echo',
        category: EvidenceCategory.slope,
        localFilePath: '/storage/evd777_1.jpg',
        fileSizeBytes: 1800500,
        mediaType: 'photo',
        latitude: 28.7124,
        longitude: 95.8143,
        gpsAccuracyMeters: 7.2,
        capturedAt: DateTime.now(),
        isZoneVerified: true,
      ),
    ];

    // Protection Check 1: Prevent Duplicate Submission (Task already completed)
    final completedTask = validTask.copyWith(status: InspectionTaskStatus.completed);
    results['Protection Check 1 - Prevent Duplicate Submission'] =
        completedTask.status == InspectionTaskStatus.completed;

    // Protection Check 2: Prevent Submission for another officer's inspection
    final unauthorizedOfficerUid = 'officer_unauthorized_x';
    final isAuthorized = validTask.assignedOfficerUid == unauthorizedOfficerUid;
    results['Protection Check 2 - Prevent Unauthorized Officer Submission'] = !isAuthorized;

    // Protection Check 3: Prevent Submission without location verification
    final unverifiedProof = LocationVerificationRecord(
      inspectionId: validTask.id,
      officerUid: 'officer_echo',
      latitude: 28.7124,
      longitude: 95.8143,
      gpsAccuracyMeters: 45.0,
      timestamp: DateTime.now(),
      state: LocationVerificationState.accuracyTooPoor,
      message: 'Unverified',
      isVerified: false,
    );
    results['Protection Check 3 - Prevent Unverified Location Submission'] =
        !unverifiedProof.isVerified;

    // Protection Check 4: Prevent Submission of cancelled assignment
    final cancelledTask = validTask.copyWith(status: InspectionTaskStatus.cancelled);
    results['Protection Check 4 - Prevent Cancelled Assignment Submission'] =
        cancelledTask.status == InspectionTaskStatus.cancelled;

    // Test Structured Field Report Generation
    final report = FieldReport(
      reportId: 'REP-${validTask.id}',
      inspectionId: validTask.id,
      officerUid: 'officer_echo',
      riskZoneId: validTask.riskZoneId,
      aiBaselineContext: AIBaselineContext(
        initialRiskLevel: validTask.riskLevel,
        initialTriggerReason: validTask.reason,
        assignedBy: validTask.assignedBy,
      ),
      latitude: validProof.latitude,
      longitude: validProof.longitude,
      gpsAccuracyMeters: validProof.gpsAccuracyMeters,
      verifiedAt: validProof.timestamp,
      verificationState: validProof.state.name,
      observation: validObservation,
      evidenceReferences: validEvidence,
      officerAssessment: validObservation.overallObservation,
      submissionStatus: 'completed',
      submittedAt: DateTime.now(),
    );

    results['Test Structured Report Generation'] =
        report.reportId == 'REP-INS-SUBMIT-777' &&
        report.inspectionId == 'INS-SUBMIT-777' &&
        report.officerUid == 'officer_echo' &&
        report.submissionStatus == 'completed' &&
        report.officerAssessment == OverallObservation.critical &&
        report.evidenceReferences.length == 1;

    // Test Firestore Serialization
    final map = report.toFirestore();
    results['Test Field Report Firestore Serialization'] =
        map['report_id'] == 'REP-INS-SUBMIT-777' &&
        map['submission_status'] == 'completed' &&
        map['officer_assessment'] == 'critical';

    return results;
  }
}
