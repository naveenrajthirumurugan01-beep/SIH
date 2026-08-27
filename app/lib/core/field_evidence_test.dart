import '../models/field_evidence.dart';
import '../models/geofence_boundary.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';

/// Test Suite for Phase 9 Live Field Evidence Capture & Zone Verification Rules
class FieldEvidenceTestSuite {
  static Map<String, dynamic> runTests() {
    final results = <String, bool>{};

    final task = InspectionTask(
      id: 'INS-EVD-101',
      assignedOfficerUid: 'officer_charlie',
      lat: 28.7123,
      lng: 95.8142,
      riskLevel: RiskLevel.critical,
      reason: 'Rockfall hazard',
      instructions: 'Capture evidence',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      geofenceRadiusMeters: 75.0,
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7123,
        centerLng: 95.8142,
        radiusMeters: 75.0,
      ),
    );

    // Test 1: Category Mapping for all 8 required categories
    final categories = EvidenceCategory.values;
    results['Test 1 - 8 Evidence Categories Supported'] = categories.length == 8;

    // Test 2: Evidence Captured INSIDE Inspection Zone
    final insideFixLat = 28.7124;
    final insideFixLng = 95.8143;
    final insideAccuracy = 8.5;
    final isInsideBoundary = task.boundary.containsPoint(insideFixLat, insideFixLng);
    final isInsideZoneVerified = isInsideBoundary && insideAccuracy <= 30.0;

    final itemInside = FieldEvidenceItem(
      id: 'EVD-2026-101',
      inspectionId: task.id,
      officerUid: 'officer_charlie',
      category: EvidenceCategory.rockfall,
      localFilePath: '/storage/emulated/0/DCIM/evd_101.jpg',
      fileSizeBytes: 1450200,
      mediaType: 'photo',
      latitude: insideFixLat,
      longitude: insideFixLng,
      gpsAccuracyMeters: insideAccuracy,
      capturedAt: DateTime.now(),
      isZoneVerified: isInsideZoneVerified,
    );

    results['Test 2 - Evidence Inside Zone is Zone Verified'] =
        itemInside.isZoneVerified == true && itemInside.category == EvidenceCategory.rockfall;

    // Test 3: Evidence Captured OUTSIDE Inspection Zone (Core Rule Safety Check)
    final outsideFixLat = 28.7200;
    final outsideFixLng = 95.8200;
    final isOutsideBoundary = task.boundary.containsPoint(outsideFixLat, outsideFixLng);
    final isOutsideZoneVerified = isOutsideBoundary && insideAccuracy <= 30.0;

    final itemOutside = FieldEvidenceItem(
      id: 'EVD-2026-102',
      inspectionId: task.id,
      officerUid: 'officer_charlie',
      category: EvidenceCategory.roadDamage,
      localFilePath: '/storage/emulated/0/DCIM/evd_102.jpg',
      fileSizeBytes: 2100400,
      mediaType: 'photo',
      latitude: outsideFixLat,
      longitude: outsideFixLng,
      gpsAccuracyMeters: 6.0,
      capturedAt: DateTime.now(),
      isZoneVerified: isOutsideZoneVerified,
    );

    results['Test 3 - Evidence Outside Zone MUST NOT Be Zone Verified'] =
        itemOutside.isZoneVerified == false;

    // Test 4: Serialization
    final map = itemInside.toFirestore();
    final restored = FieldEvidenceItem.fromFirestore(map);
    results['Test 4 - Evidence Serialization Roundtrip'] =
        restored.id == 'EVD-2026-101' &&
        restored.inspectionId == 'INS-EVD-101' &&
        restored.category == EvidenceCategory.rockfall &&
        restored.isZoneVerified == true;

    return results;
  }
}
