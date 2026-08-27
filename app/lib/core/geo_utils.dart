import 'package:latlong2/latlong.dart';

import '../models/geofence.dart';

/// Shared distance/geofence math, used by both the Citizen "nearest zone"
/// lookups (risk_repository.dart) and the Field Officer geofence check.
const _distance = Distance();

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  return _distance.as(LengthUnit.Meter, LatLng(lat1, lng1), LatLng(lat2, lng2));
}

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  return _distance.as(LengthUnit.Kilometer, LatLng(lat1, lng1), LatLng(lat2, lng2));
}

/// True once the officer's current position is within [radiusMeters] of
/// the target location.
bool isWithinGeofence({
  required double currentLat,
  required double currentLng,
  required double targetLat,
  required double targetLng,
  required double radiusMeters,
}) {
  return distanceMeters(currentLat, currentLng, targetLat, targetLng) <= radiusMeters;
}

/// Same check against a task's [Geofence]. Only handles `circle` today —
/// a `polygon` geofence would need a point-in-polygon check here instead
/// of a radius comparison, once that type exists (see models/geofence.dart).
bool isInsideGeofence(double lat, double lng, Geofence geofence) {
  return isWithinGeofence(
    currentLat: lat,
    currentLng: lng,
    targetLat: geofence.centerLat,
    targetLng: geofence.centerLng,
    radiusMeters: geofence.radiusMeters,
  );
}
