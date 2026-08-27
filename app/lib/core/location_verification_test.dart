import '../models/geofence_boundary.dart';
import '../models/location_verification.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import '../services/location_service.dart';
import '../services/location_verifier.dart';

/// Test Suite for Phase 7 Location Verification (State 1 to State 5)
class LocationVerificationTestSuite {
  static Map<String, dynamic> runTests() {
    final results = <String, bool>{};

    final testTask = InspectionTask(
      id: 'INS-VERIFY-777',
      assignedOfficerUid: 'officer_alpha',
      lat: 28.7123,
      lng: 95.8142,
      riskLevel: RiskLevel.high,
      reason: 'Landslide fissure check',
      instructions: 'Verify fissure',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      geofenceRadiusMeters: 75.0,
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7123,
        centerLng: 95.8142,
        radiusMeters: 75.0,
      ),
    );

    // 1. Test State 1: GPS Unavailable (Disabled Hardware)
    final fixState1 = FieldGpsFix(
      latitude: 28.7123,
      longitude: 95.8142,
      accuracyMeters: 0,
      timestamp: DateTime.now(),
      status: FieldGpsStatus.disabled,
      errorMessage: 'GPS hardware disabled',
    );
    final record1 = LocationVerifier.evaluate(
      fix: fixState1,
      task: testTask,
      officerUid: 'officer_alpha',
    );
    results['Test State 1 - GPS Unavailable'] =
        record1.state == LocationVerificationState.gpsUnavailable && !record1.isVerified;

    // 2. Test State 2: GPS Accuracy Too Poor (45m > 30m)
    final fixState2 = FieldGpsFix(
      latitude: 28.7123,
      longitude: 95.8142,
      accuracyMeters: 45.0,
      timestamp: DateTime.now(),
      status: FieldGpsStatus.activeLowAccuracy,
    );
    final record2 = LocationVerifier.evaluate(
      fix: fixState2,
      task: testTask,
      officerUid: 'officer_alpha',
    );
    results['Test State 2 - GPS Accuracy Too Poor (45m > 30m)'] =
        record2.state == LocationVerificationState.accuracyTooPoor && !record2.isVerified;

    // 3. Test State 3: Outside Inspection Zone (Accurate fix, but 300m outside boundary)
    final fixState3 = FieldGpsFix(
      latitude: 28.7160,
      longitude: 95.8180,
      accuracyMeters: 8.0,
      timestamp: DateTime.now(),
      status: FieldGpsStatus.activeHighAccuracy,
    );
    final record3 = LocationVerifier.evaluate(
      fix: fixState3,
      task: testTask,
      officerUid: 'officer_alpha',
    );
    results['Test State 3 - Outside Inspection Zone'] =
        record3.state == LocationVerificationState.outsideInspectionZone && !record3.isVerified;

    // 4. Test State 5: LOCATION VERIFIED (High accuracy 6.5m fix inside 75m zone)
    final fixState5 = FieldGpsFix(
      latitude: 28.7124,
      longitude: 95.8143,
      accuracyMeters: 6.5,
      timestamp: DateTime.now(),
      status: FieldGpsStatus.activeHighAccuracy,
    );
    final record5 = LocationVerifier.evaluate(
      fix: fixState5,
      task: testTask,
      officerUid: 'officer_alpha',
    );
    results['Test State 5 - LOCATION VERIFIED (Criteria Met)'] =
        record5.state == LocationVerificationState.locationVerified &&
        record5.isVerified &&
        record5.inspectionId == 'INS-VERIFY-777' &&
        record5.officerUid == 'officer_alpha' &&
        record5.gpsAccuracyMeters == 6.5;

    return results;
  }
}
