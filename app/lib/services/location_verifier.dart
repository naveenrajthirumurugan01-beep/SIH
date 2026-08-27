import '../models/location_verification.dart';
import '../models/task.dart';
import 'location_service.dart';

/// Location Verifier Engine (Phase 7)
/// Connects Phase 5 GPS Telemetry with Phase 6 Dynamic Geofencing.
/// Evaluates and enforces the 5 formal location verification states.
class LocationVerifier {
  static const double RequiredMaxAccuracyMeters = 30.0;

  static LocationVerificationRecord evaluate({
    required FieldGpsFix fix,
    required InspectionTask task,
    required String officerUid,
  }) {
    // State 1: GPS Unavailable (Disabled / Permission Denied / System Error)
    if (fix.status == FieldGpsStatus.disabled ||
        fix.status == FieldGpsStatus.permissionDenied ||
        fix.status == FieldGpsStatus.permissionDeniedForever ||
        fix.status == FieldGpsStatus.error) {
      return LocationVerificationRecord(
        inspectionId: task.id,
        officerUid: officerUid,
        latitude: fix.latitude,
        longitude: fix.longitude,
        gpsAccuracyMeters: fix.accuracyMeters,
        timestamp: fix.timestamp,
        state: LocationVerificationState.gpsUnavailable,
        message: fix.errorMessage ?? 'GPS signal unavailable. Enable device location services and grant permissions.',
        isVerified: false,
      );
    }

    // State 2: GPS Accuracy Too Poor (> 30.0m threshold)
    if (fix.accuracyMeters > RequiredMaxAccuracyMeters) {
      return LocationVerificationRecord(
        inspectionId: task.id,
        officerUid: officerUid,
        latitude: fix.latitude,
        longitude: fix.longitude,
        gpsAccuracyMeters: fix.accuracyMeters,
        timestamp: fix.timestamp,
        state: LocationVerificationState.accuracyTooPoor,
        message: 'GPS accuracy too poor (±${fix.accuracyMeters.toStringAsFixed(1)}m > ${RequiredMaxAccuracyMeters.toStringAsFixed(0)}m). Move to open sky for a reliable fix.',
        isVerified: false,
      );
    }

    // Evaluate dynamic geofence boundary attached to Inspection ID
    final boundary = task.boundary;
    final isInside = boundary.containsPoint(fix.latitude, fix.longitude);
    final distanceToBoundary = boundary.distanceMetersTo(fix.latitude, fix.longitude);

    // State 3: Outside Inspection Zone
    if (!isInside) {
      return LocationVerificationRecord(
        inspectionId: task.id,
        officerUid: officerUid,
        latitude: fix.latitude,
        longitude: fix.longitude,
        gpsAccuracyMeters: fix.accuracyMeters,
        timestamp: fix.timestamp,
        state: LocationVerificationState.outsideInspectionZone,
        message: 'Outside Inspection Zone. Officer is ${distanceToBoundary.toStringAsFixed(1)}m away from target boundary (${boundary.boundaryDescription}).',
        isVerified: false,
      );
    }

    // State 4 & 5: Inside Inspection Zone & FULLY VERIFIED
    return LocationVerificationRecord(
      inspectionId: task.id,
      officerUid: officerUid,
      latitude: fix.latitude,
      longitude: fix.longitude,
      gpsAccuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
      state: LocationVerificationState.locationVerified,
      message: 'LOCATION VERIFIED: Officer is physically inside inspection zone (${task.riskZoneId}) with high-accuracy GPS fix (±${fix.accuracyMeters.toStringAsFixed(1)}m).',
      isVerified: true,
    );
  }
}
