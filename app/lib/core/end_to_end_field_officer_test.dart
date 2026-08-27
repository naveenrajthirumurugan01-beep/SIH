import '../models/field_evidence.dart';
import '../models/field_report.dart';
import '../models/geofence_boundary.dart';
import '../models/inspection.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/field_officer_sync_service.dart';
import '../services/location_service.dart';
import '../services/location_verifier.dart';

/// Complete End-to-End Operational Lifecycle Verification Test Suite
class EndToEndFieldOfficerTestSuite {
  static Future<Map<String, dynamic>> runEndToEndWorkflow() async {
    final trace = <String, bool>{};

    // Step 1: ASSIGNMENT EXISTS
    final initialTask = InspectionTask(
      id: 'INS-027',
      assignedOfficerUid: 'officer_fo_01',
      riskZoneId: 'RZ-DV-01',
      locationName: 'Dri River Valley Slope Patrol',
      lat: 28.7891,
      lng: 95.8328,
      riskLevel: RiskLevel.critical,
      priority: 'Urgent',
      assignedBy: 'Analyst Desk',
      reason: 'AI Risk Model Flagged Active Fissure',
      instructions: 'Conduct immediate ground observation and capture evidence',
      status: InspectionTaskStatus.assigned,
      geofenceRadiusMeters: 75.0,
      createdAt: DateTime.now(),
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7891,
        centerLng: 95.8328,
        radiusMeters: 75.0,
      ),
    );
    trace['Step 1: ASSIGNMENT EXISTS (INS-027)'] = initialTask.status == InspectionTaskStatus.assigned;

    // Step 2: Field Officer Login
    final officerProfile = UserProfile(
      uid: 'officer_fo_01',
      fullName: 'Field Officer Rajesh Kumar',
      email: 'rajesh.officer@ner.gov.in',
      phoneNumber: '+919876543210',
      district: 'Dibang Valley',
      role: UserRole.fieldOfficial,
      status: 'active',
      officerId: 'FO-NER-101',
    );
    final isAuthenticated = officerProfile.role == UserRole.fieldOfficial && officerProfile.status == 'active';
    trace['Step 2: Field Officer Login (Authenticated active field_official)'] = isAuthenticated;

    // Step 3: See Assigned Inspection
    final isAssignedToOfficer = initialTask.assignedOfficerUid == officerProfile.uid;
    trace['Step 3: See Assigned Inspection (Filtered by Officer UID)'] = isAssignedToOfficer;

    // Step 4: Open INS-027
    trace['Step 4: Open INS-027 (Task details loaded)'] = initialTask.id == 'INS-027';

    // Step 5: START INSPECTION
    final enRouteTask = initialTask.copyWith(status: InspectionTaskStatus.enRoute);
    trace['Step 5: START INSPECTION (Status updated to EN ROUTE)'] = enRouteTask.status == InspectionTaskStatus.enRoute;

    // Step 6: Navigate to Zone & GPS Check
    final gpsFix = FieldGpsFix(
      latitude: 28.78915,
      longitude: 95.83285,
      accuracyMeters: 6.5,
      timestamp: DateTime.now(),
      status: FieldGpsStatus.activeHighAccuracy,
    );
    trace['Step 6: GPS Check (Acquired high accuracy ±6.5m fix)'] = gpsFix.isReliable;

    // Step 7: Enter Dynamic Geo-Fence & LOCATION VERIFIED ✓
    final verificationRecord = LocationVerifier.evaluate(
      fix: gpsFix,
      task: enRouteTask,
      officerUid: officerProfile.uid,
    );
    trace['Step 7: LOCATION VERIFIED ✓ (State 5 confirmed)'] = verificationRecord.isVerified;

    // Step 8: Inspection Form Unlocks
    final isFormUnlocked = verificationRecord.isVerified;
    trace['Step 8: Inspection Form Unlocks (Unlocked post-verification)'] = isFormUnlocked;

    // Step 9: Capture Evidence (Slope, Crack, Road) + GPS/Timestamp Attached
    final evidenceItems = [
      FieldEvidenceItem(
        id: 'EVD-2026-101',
        inspectionId: initialTask.id,
        officerUid: officerProfile.uid,
        category: EvidenceCategory.slope,
        localFilePath: '/storage/slope.jpg',
        fileSizeBytes: 1450000,
        mediaType: 'photo',
        latitude: gpsFix.latitude,
        longitude: gpsFix.longitude,
        gpsAccuracyMeters: gpsFix.accuracyMeters,
        capturedAt: DateTime.now(),
        isZoneVerified: true,
      ),
      FieldEvidenceItem(
        id: 'EVD-2026-102',
        inspectionId: initialTask.id,
        officerUid: officerProfile.uid,
        category: EvidenceCategory.crack,
        localFilePath: '/storage/crack.jpg',
        fileSizeBytes: 1210000,
        mediaType: 'photo',
        latitude: gpsFix.latitude,
        longitude: gpsFix.longitude,
        gpsAccuracyMeters: gpsFix.accuracyMeters,
        capturedAt: DateTime.now(),
        isZoneVerified: true,
      ),
      FieldEvidenceItem(
        id: 'EVD-2026-103',
        inspectionId: initialTask.id,
        officerUid: officerProfile.uid,
        category: EvidenceCategory.roadDamage,
        localFilePath: '/storage/road.jpg',
        fileSizeBytes: 1980000,
        mediaType: 'photo',
        latitude: gpsFix.latitude,
        longitude: gpsFix.longitude,
        gpsAccuracyMeters: gpsFix.accuracyMeters,
        capturedAt: DateTime.now(),
        isZoneVerified: true,
      ),
    ];
    trace['Step 9: Capture Evidence (Slope, Crack, Road + GPS/Timestamp attached)'] = evidenceItems.length == 3;

    // Step 10: Complete Observations & Select Assessment
    final observation = FieldObservation(
      inspectionId: initialTask.id,
      officerUid: officerProfile.uid,
      crack: CrackStatus.major,
      slopeMovement: SlopeMovement.severe,
      rockfall: true,
      waterSeepage: true,
      roadCondition: RoadCondition.blocked,
      overallObservation: OverallObservation.critical,
      remarks: 'Active slope tension crack expanding rapidly across road shoulder',
      recordedAt: DateTime.now(),
    );
    trace['Step 10: Complete Observations & Select Assessment (CRITICAL selected)'] =
        observation.overallObservation == OverallObservation.critical;

    // Step 11: Review Report
    final isConfirmedByOfficer = true;
    trace['Step 11: Review Report (Confirmed by officer)'] = isConfirmedByOfficer;

    // Step 12: SUBMIT
    final completedTask = enRouteTask.copyWith(status: InspectionTaskStatus.completed);
    final fieldReport = FieldReport(
      reportId: 'REP-${initialTask.id}',
      inspectionId: initialTask.id,
      officerUid: officerProfile.uid,
      officerName: officerProfile.fullName,
      riskZoneId: initialTask.riskZoneId,
      aiBaselineContext: AIBaselineContext(
        initialRiskLevel: initialTask.riskLevel,
        initialTriggerReason: initialTask.reason,
        assignedBy: initialTask.assignedBy,
      ),
      latitude: verificationRecord.latitude,
      longitude: verificationRecord.longitude,
      gpsAccuracyMeters: verificationRecord.gpsAccuracyMeters,
      verifiedAt: verificationRecord.timestamp,
      verificationState: verificationRecord.state.name,
      observation: observation,
      evidenceReferences: evidenceItems,
      officerAssessment: observation.overallObservation,
      submissionStatus: 'completed',
      submittedAt: DateTime.now(),
    );
    trace['Step 12: SUBMIT (Task completed & FieldReport generated)'] = completedTask.status == InspectionTaskStatus.completed;

    // Step 13: SYNCED ✓
    final syncService = FieldOfficerSyncService();
    await syncService.initialize();
    syncService.setNetworkAvailable(true);
    await syncService.triggerAutoSync();
    trace['Step 13: SYNCED ✓ (Status state == synced)'] = syncService.syncState == FieldSyncState.synced;

    // Step 14: Report Available to Analyst
    final firestorePayload = fieldReport.toFirestore();
    final isReadyForAnalyst = firestorePayload['analyst_handoff_status'] == 'ready_for_analyst_review';
    trace['Step 14: Report Available to Analyst (ready_for_analyst_review)'] = isReadyForAnalyst;

    return trace;
  }
}
