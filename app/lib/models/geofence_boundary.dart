import 'package:latlong2/latlong.dart';

import '../core/geo_utils.dart';

enum GeofenceType { radius, polygon }

/// Dynamic Geofence Boundary abstraction for Field Officer inspection tasks.
/// Supports both Radial boundaries (MVP) and Polygon GIS risk zone boundaries (Future).
abstract class GeofenceBoundary {
  GeofenceType get type;

  /// Returns true if [lat] and [lng] fall inside the dynamic inspection boundary
  bool containsPoint(double lat, double lng);

  /// Returns the distance in meters to the target center or nearest boundary edge
  double distanceMetersTo(double lat, double lng);

  /// Human-readable label describing the boundary size
  String get boundaryDescription;

  /// Factory for Radial Geofence
  factory GeofenceBoundary.radius({
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) = RadialGeofenceBoundary;

  /// Factory for Polygon GIS Geofence
  factory GeofenceBoundary.polygon({
    required List<LatLng> vertices,
  }) = PolygonGeofenceBoundary;

  Map<String, dynamic> toFirestore();

  factory GeofenceBoundary.fromFirestore(
    Map<String, dynamic>? data,
    double defaultLat,
    double defaultLng,
    double defaultRadius,
  ) {
    if (data == null) {
      return RadialGeofenceBoundary(
        centerLat: defaultLat,
        centerLng: defaultLng,
        radiusMeters: defaultRadius,
      );
    }

    final typeStr = data['type'] as String? ?? 'radius';
    if (typeStr == 'polygon' && data['vertices'] is List) {
      final rawList = data['vertices'] as List;
      final vertices = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        return LatLng(
          (map['lat'] as num).toDouble(),
          (map['lng'] as num).toDouble(),
        );
      }).toList();

      if (vertices.length >= 3) {
        return PolygonGeofenceBoundary(vertices: vertices);
      }
    }

    return RadialGeofenceBoundary(
      centerLat: (data['center_lat'] as num?)?.toDouble() ?? defaultLat,
      centerLng: (data['center_lng'] as num?)?.toDouble() ?? defaultLng,
      radiusMeters: (data['radius_meters'] as num?)?.toDouble() ?? defaultRadius,
    );
  }
}

/// Radial Geofence Implementation
class RadialGeofenceBoundary implements GeofenceBoundary {
  final double centerLat;
  final double centerLng;
  final double radiusMeters;

  const RadialGeofenceBoundary({
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
  });

  @override
  GeofenceType get type => GeofenceType.radius;

  @override
  bool containsPoint(double lat, double lng) {
    return distanceMeters(lat, lng, centerLat, centerLng) <= radiusMeters;
  }

  @override
  double distanceMetersTo(double lat, double lng) {
    return distanceMeters(lat, lng, centerLat, centerLng);
  }

  @override
  String get boundaryDescription => '${radiusMeters.toStringAsFixed(0)}m Radius Circle';

  @override
  Map<String, dynamic> toFirestore() => {
        'type': 'radius',
        'center_lat': centerLat,
        'center_lng': centerLng,
        'radius_meters': radiusMeters,
      };
}

/// Polygon GIS Risk Zone Geofence Implementation (Ray-Casting Algorithm)
class PolygonGeofenceBoundary implements GeofenceBoundary {
  final List<LatLng> vertices;

  const PolygonGeofenceBoundary({required this.vertices});

  @override
  GeofenceType get type => GeofenceType.polygon;

  /// Ray-Casting Algorithm for Point-in-Polygon evaluation
  @override
  bool containsPoint(double lat, double lng) {
    if (vertices.length < 3) return false;

    bool inside = false;
    int j = vertices.length - 1;

    for (int i = 0; i < vertices.length; i++) {
      final xi = vertices[i].longitude;
      final yi = vertices[i].latitude;
      final xj = vertices[j].longitude;
      final yj = vertices[j].latitude;

      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 0.000000001) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  @override
  double distanceMetersTo(double lat, double lng) {
    // Distance to centroid of polygon
    double sumLat = 0;
    double sumLng = 0;
    for (final v in vertices) {
      sumLat += v.latitude;
      sumLng += v.longitude;
    }
    final centroidLat = sumLat / vertices.length;
    final centroidLng = sumLng / vertices.length;

    return distanceMeters(lat, lng, centroidLat, centroidLng);
  }

  @override
  String get boundaryDescription => 'GIS ${vertices.length}-Vertex Risk Polygon';

  @override
  Map<String, dynamic> toFirestore() => {
        'type': 'polygon',
        'vertices': vertices.map((v) => {'lat': v.latitude, 'lng': v.longitude}).toList(),
      };
}

/// Dynamic Evaluation Result Container
class GeofenceEvaluationResult {
  final String inspectionId;
  final String riskZoneId;
  final bool isInsideBoundary;
  final double distanceMeters;
  final String boundaryDescription;
  final GeofenceType geofenceType;
  final DateTime evaluatedAt;

  const GeofenceEvaluationResult({
    required this.inspectionId,
    required this.riskZoneId,
    required this.isInsideBoundary,
    required this.distanceMeters,
    required this.boundaryDescription,
    required this.geofenceType,
    required this.evaluatedAt,
  });
}
