import 'geofence_boundary.dart';
import 'risk_zone.dart';

/// Where a task is in the officer's workflow: assigned -> (enRoute once
/// they start navigating) -> (onSite once the geofence check passes) ->
/// completed (inspection submitted). `cancelled` is a separate terminal
/// state (e.g. task withdrawn by an analyst) not reachable from this app yet.
enum InspectionTaskStatus { assigned, enRoute, onSite, completed, cancelled }

extension InspectionTaskStatusX on InspectionTaskStatus {
  String get firestoreValue => switch (this) {
        InspectionTaskStatus.assigned => 'assigned',
        InspectionTaskStatus.enRoute => 'en_route',
        InspectionTaskStatus.onSite => 'on_site',
        InspectionTaskStatus.completed => 'completed',
        InspectionTaskStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        InspectionTaskStatus.assigned => 'Assigned',
        InspectionTaskStatus.enRoute => 'En Route',
        InspectionTaskStatus.onSite => 'On Site',
        InspectionTaskStatus.completed => 'Completed',
        InspectionTaskStatus.cancelled => 'Cancelled',
      };

  static InspectionTaskStatus fromFirestoreValue(String value) => switch (value) {
        'en_route' => InspectionTaskStatus.enRoute,
        'on_site' => InspectionTaskStatus.onSite,
        'completed' => InspectionTaskStatus.completed,
        'cancelled' => InspectionTaskStatus.cancelled,
        _ => InspectionTaskStatus.assigned,
      };
}

/// A field inspection assignment. Not every task originates from a citizen
/// report — [linkedReportId] is null for tasks the risk model itself
/// flagged (see reason text), and set when a citizen/field report drove
/// the assignment.
class InspectionTask {
  final String id; // Inspection Assignment ID
  final String assignedOfficerUid; // Field Officer ID / Firebase UID
  final String riskZoneId; // Risk Zone ID
  final String locationName; // Location / District Name
  final double lat; // Target Latitude
  final double lng; // Target Longitude
  final RiskLevel riskLevel; // Risk Level (critical, high, medium, low)
  final String priority; // Priority (Urgent, High, Medium, Low)
  final String assignedBy; // Analyst or Engine name
  final String reason; // Trigger reason
  final String instructions; // Operational instructions
  final InspectionTaskStatus status; // Lifecycle status
  final double geofenceRadiusMeters; // Geofence radius
  final DateTime createdAt; // Assigned timestamp
  final String? linkedReportId; // Optional linked report ID
  final GeofenceBoundary? _customBoundary;

  const InspectionTask({
    required this.id,
    required this.assignedOfficerUid,
    required this.lat,
    required this.lng,
    required this.riskLevel,
    required this.reason,
    required this.instructions,
    required this.status,
    required this.createdAt,
    this.riskZoneId = 'RZ-DV-01',
    this.locationName = 'Dibang Valley Patrol Area',
    this.priority = 'High',
    this.assignedBy = 'Analyst Desk',
    this.geofenceRadiusMeters = 100.0,
    this.linkedReportId,
    GeofenceBoundary? customBoundary,
  }) : _customBoundary = customBoundary;

  /// Dynamic Geofence Boundary attached to this Inspection ID
  GeofenceBoundary get boundary {
    if (_customBoundary != null) return _customBoundary;
    return GeofenceBoundary.radius(
      centerLat: lat,
      centerLng: lng,
      radiusMeters: geofenceRadiusMeters,
    );
  }

  InspectionTask copyWith({
    InspectionTaskStatus? status,
    String? assignedOfficerUid,
    String? priority,
    GeofenceBoundary? customBoundary,
  }) {
    return InspectionTask(
      id: id,
      assignedOfficerUid: assignedOfficerUid ?? this.assignedOfficerUid,
      riskZoneId: riskZoneId,
      locationName: locationName,
      lat: lat,
      lng: lng,
      riskLevel: riskLevel,
      priority: priority ?? this.priority,
      assignedBy: assignedBy,
      reason: reason,
      instructions: instructions,
      status: status ?? this.status,
      geofenceRadiusMeters: geofenceRadiusMeters,
      createdAt: createdAt,
      linkedReportId: linkedReportId,
      customBoundary: customBoundary ?? _customBoundary,
    );
  }

  factory InspectionTask.fromFirestore(String id, Map<String, dynamic> data) {
    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final radius = (data['geofence_radius_meters'] as num?)?.toDouble() ?? 100.0;

    final boundaryData = data['geofence_boundary'] as Map<String, dynamic>?;

    return InspectionTask(
      id: id,
      assignedOfficerUid: data['assigned_officer_uid'] as String? ?? '',
      riskZoneId: data['risk_zone_id'] as String? ?? 'RZ-DV-01',
      locationName: data['location_name'] as String? ?? 'Dibang Valley Patrol Area',
      lat: lat,
      lng: lng,
      riskLevel: RiskLevelX.fromFirestoreValue(data['risk_level'] as String? ?? 'low'),
      priority: data['priority'] as String? ?? 'High',
      assignedBy: data['assigned_by'] as String? ?? 'Analyst Command Center',
      reason: data['reason'] as String? ?? '',
      instructions: data['instructions'] as String? ?? '',
      status: InspectionTaskStatusX.fromFirestoreValue(data['status'] as String? ?? 'assigned'),
      geofenceRadiusMeters: radius,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      linkedReportId: data['linked_report_id'] as String?,
      customBoundary: GeofenceBoundary.fromFirestore(boundaryData, lat, lng, radius),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'assigned_officer_uid': assignedOfficerUid,
        'risk_zone_id': riskZoneId,
        'location_name': locationName,
        'lat': lat,
        'lng': lng,
        'risk_level': riskLevel.firestoreValue,
        'priority': priority,
        'assigned_by': assignedBy,
        'reason': reason,
        'instructions': instructions,
        'status': status.firestoreValue,
        'geofence_radius_meters': geofenceRadiusMeters,
        'created_at': createdAt.toIso8601String(),
        'linked_report_id': linkedReportId,
        'geofence_boundary': boundary.toFirestore(),
      };
}
