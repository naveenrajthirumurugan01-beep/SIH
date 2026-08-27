import 'geofence_boundary.dart';
import 'risk_zone.dart';

enum InspectionTaskStatus { unassigned, assigned, enRoute, onSite, completed, cancelled }

enum AssignmentType { auto, manual }

enum GeofenceStatus { inside, outside, unknown }

extension InspectionTaskStatusX on InspectionTaskStatus {
  String get firestoreValue => switch (this) {
        InspectionTaskStatus.unassigned => 'unassigned',
        InspectionTaskStatus.assigned => 'assigned',
        InspectionTaskStatus.enRoute => 'en_route',
        InspectionTaskStatus.onSite => 'on_site',
        InspectionTaskStatus.completed => 'completed',
        InspectionTaskStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        InspectionTaskStatus.unassigned => 'Unassigned',
        InspectionTaskStatus.assigned => 'Assigned',
        InspectionTaskStatus.enRoute => 'En Route',
        InspectionTaskStatus.onSite => 'On Site',
        InspectionTaskStatus.completed => 'Completed',
        InspectionTaskStatus.cancelled => 'Cancelled',
      };

  static InspectionTaskStatus fromFirestoreValue(String value) => switch (value) {
        'unassigned' => InspectionTaskStatus.unassigned,
        'en_route' => InspectionTaskStatus.enRoute,
        'on_site' => InspectionTaskStatus.onSite,
        'completed' => InspectionTaskStatus.completed,
        'cancelled' => InspectionTaskStatus.cancelled,
        _ => InspectionTaskStatus.assigned,
      };
}

class InspectionTask {
  final String id;
  final String assignedOfficerUid;
  final String riskZoneId;
  final String locationName;
  final double lat;
  final double lng;
  final RiskLevel riskLevel;
  final String priority;
  final String assignedBy;
  final String reason;
  final String instructions;
  final InspectionTaskStatus status;
  final double geofenceRadiusMeters;
  final DateTime createdAt;
  final String? linkedReportId;
  final AssignmentType assignmentType;
  final GeofenceStatus geofenceStatus;
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
    this.assignmentType = AssignmentType.manual,
    this.geofenceStatus = GeofenceStatus.unknown,
    GeofenceBoundary? customBoundary,
  }) : _customBoundary = customBoundary;

  GeofenceBoundary get boundary {
    if (_customBoundary != null) return _customBoundary;
    return GeofenceBoundary.radius(
      centerLat: lat,
      centerLng: lng,
      radiusMeters: geofenceRadiusMeters,
    );
  }

  GeofenceBoundary get geofence => boundary;

  InspectionTask copyWith({
    InspectionTaskStatus? status,
    String? assignedOfficerUid,
    String? priority,
    AssignmentType? assignmentType,
    GeofenceStatus? geofenceStatus,
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
      assignmentType: assignmentType ?? this.assignmentType,
      geofenceStatus: geofenceStatus ?? this.geofenceStatus,
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
      assignmentType: data['assignment_type'] == 'auto' ? AssignmentType.auto : AssignmentType.manual,
      geofenceStatus: data['geofence_status'] == 'inside'
          ? GeofenceStatus.inside
          : (data['geofence_status'] == 'outside' ? GeofenceStatus.outside : GeofenceStatus.unknown),
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
        'assignment_type': assignmentType == AssignmentType.auto ? 'auto' : 'manual',
        'geofence_status': geofenceStatus.name,
        'geofence_boundary': boundary.toFirestore(),
      };
}
