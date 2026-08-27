import 'package:latlong2/latlong.dart';

import '../models/geofence_boundary.dart';
import '../models/task.dart';
import '../models/risk_zone.dart';

/// Test Evaluation Suite for Dynamic Geofencing Architecture (Phase 6 Verification)
class DynamicGeofenceTestSuite {
  static Map<String, dynamic> runTests() {
    final results = <String, bool>{};

    // 1. Setup Test Inspection 1: Radial 75m Boundary
    final task1 = InspectionTask(
      id: 'INS-TEST-001',
      assignedOfficerUid: 'officer_1',
      lat: 28.7123,
      lng: 95.8142,
      riskLevel: RiskLevel.high,
      reason: 'Crack inspection',
      instructions: 'Inspect crack',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      geofenceRadiusMeters: 75.0,
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7123,
        centerLng: 95.8142,
        radiusMeters: 75.0,
      ),
    );

    // Test 1a: Inside 75m Radial Boundary (Officer at ~20m)
    final insideRadial = task1.boundary.containsPoint(28.7124, 95.8143);
    results['Test 1a - Radial Inside (20m < 75m)'] = insideRadial == true;

    // Test 1b: Outside 75m Radial Boundary (Officer at ~300m)
    final outsideRadial = task1.boundary.containsPoint(28.7150, 95.8170);
    results['Test 1b - Radial Outside (300m > 75m)'] = outsideRadial == false;

    // 2. Setup Test Inspection 2: Radial 150m Boundary (Different Inspection, Different Boundary)
    final task2 = InspectionTask(
      id: 'INS-TEST-002',
      assignedOfficerUid: 'officer_1',
      lat: 28.7891,
      lng: 95.8328,
      riskLevel: RiskLevel.critical,
      reason: 'AI Risk Rising',
      instructions: 'Inspect slope',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      geofenceRadiusMeters: 150.0,
      customBoundary: GeofenceBoundary.radius(
        centerLat: 28.7891,
        centerLng: 95.8328,
        radiusMeters: 150.0,
      ),
    );

    // Test 2a: Inside 150m Radial Boundary (Officer at ~120m)
    final inside150m = task2.boundary.containsPoint(28.7900, 95.8330);
    results['Test 2a - Radial 150m Inside (120m < 150m)'] = inside150m == true;

    // 3. Setup Test Inspection 3: Polygon GIS Risk Zone Boundary
    final polygonVertices = const [
      LatLng(28.7880, 95.8310),
      LatLng(28.7900, 95.8310),
      LatLng(28.7900, 95.8350),
      LatLng(28.7880, 95.8350),
    ];

    final task3 = InspectionTask(
      id: 'INS-TEST-003',
      assignedOfficerUid: 'officer_1',
      lat: 28.7890,
      lng: 95.8330,
      riskLevel: RiskLevel.critical,
      reason: 'GIS Polygon Inspection',
      instructions: 'Inspect polygon perimeter',
      status: InspectionTaskStatus.enRoute,
      createdAt: DateTime.now(),
      customBoundary: GeofenceBoundary.polygon(vertices: polygonVertices),
    );

    // Test 3a: Inside Polygon Centroid (28.7890, 95.8330)
    final insidePolygon = task3.boundary.containsPoint(28.7890, 95.8330);
    results['Test 3a - GIS Polygon Centroid Inside'] = insidePolygon == true;

    // Test 3b: Outside Polygon Bounding Box (28.7950, 95.8400)
    final outsidePolygon = task3.boundary.containsPoint(28.7950, 95.8400);
    results['Test 3b - GIS Polygon Outside'] = outsidePolygon == false;

    // 4. Test Edge Case: Exact Center & Bounding Box Corner
    final exactCenter = task1.boundary.containsPoint(28.7123, 95.8142);
    results['Test 4 - Edge Case Exact Center Point'] = exactCenter == true;

    return results;
  }
}
