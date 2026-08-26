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
/// the assignment, in which case completing the inspection updates that
/// report's status (see services/inspection_repository.dart).
class InspectionTask {
  final String id;
  final String assignedOfficerUid;
  final String? linkedReportId;
  final double lat;
  final double lng;
  final RiskLevel riskLevel;
  final String reason;
  final String instructions;
  final InspectionTaskStatus status;
  final DateTime createdAt;

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
    this.linkedReportId,
  });

  InspectionTask copyWith({InspectionTaskStatus? status}) {
    return InspectionTask(
      id: id,
      assignedOfficerUid: assignedOfficerUid,
      linkedReportId: linkedReportId,
      lat: lat,
      lng: lng,
      riskLevel: riskLevel,
      reason: reason,
      instructions: instructions,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  factory InspectionTask.fromFirestore(String id, Map<String, dynamic> data) {
    return InspectionTask(
      id: id,
      assignedOfficerUid: data['assigned_officer_uid'] as String? ?? '',
      linkedReportId: data['linked_report_id'] as String?,
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      riskLevel: RiskLevelX.fromFirestoreValue(data['risk_level'] as String? ?? 'low'),
      reason: data['reason'] as String? ?? '',
      instructions: data['instructions'] as String? ?? '',
      status: InspectionTaskStatusX.fromFirestoreValue(data['status'] as String? ?? 'assigned'),
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'assigned_officer_uid': assignedOfficerUid,
        'linked_report_id': linkedReportId,
        'lat': lat,
        'lng': lng,
        'risk_level': riskLevel.firestoreValue,
        'reason': reason,
        'instructions': instructions,
        'status': status.firestoreValue,
        'created_at': createdAt.toIso8601String(),
      };
}
