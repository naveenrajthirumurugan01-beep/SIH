/// Only `circle` exists today. Kept as a string-backed enum (rather than a
/// sealed class per shape) so adding `polygon` later is additive: a new
/// enum value + an optional `points` list that every circle geofence
/// already carries as null. Callers that only handle circles today don't
/// need to change when that lands.
enum GeofenceType { circle }

extension GeofenceTypeX on GeofenceType {
  String get firestoreValue => switch (this) {
        GeofenceType.circle => 'circle',
      };

  static GeofenceType fromFirestoreValue(String value) => switch (value) {
        _ => GeofenceType.circle,
      };
}

/// The zone a Field Officer must physically be inside before an inspection
/// unlocks. Generated once at task-creation time (see
/// core/geofence_utils.dart for the radius lookup) and stored on the task
/// itself — never re-derived from a risk zone or anywhere else, so it
/// stays stable even if the underlying zone is later edited or removed.
class Geofence {
  final GeofenceType type;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;

  /// Unused until polygon support exists. Each point is [lat, lng].
  final List<List<double>>? points;

  const Geofence({
    required this.type,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.points,
  });

  factory Geofence.circle({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) {
    return Geofence(
      type: GeofenceType.circle,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusMeters: radiusMeters,
    );
  }

  factory Geofence.fromFirestore(Map<String, dynamic> data) {
    return Geofence(
      type: GeofenceTypeX.fromFirestoreValue(data['type'] as String? ?? 'circle'),
      centerLat: (data['center_lat'] as num?)?.toDouble() ?? 0,
      centerLng: (data['center_lng'] as num?)?.toDouble() ?? 0,
      radiusMeters: (data['radius_meters'] as num?)?.toDouble() ?? 0,
      points: (data['points'] as List?)
          ?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.firestoreValue,
        'center_lat': centerLat,
        'center_lng': centerLng,
        'radius_meters': radiusMeters,
        if (points != null) 'points': points,
      };
}
