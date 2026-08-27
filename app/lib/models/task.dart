import 'geofence.dart';
import 'risk_zone.dart';

/// Where a task is in the officer's workflow. `unassigned` is a new
/// pre-assigned state (only reachable via automatic assignment finding no
/// available officer — see services/auto_assignment_service.dart);
/// otherwise: notified (Field Officer has been notified but hasn't
/// responded yet) -> assigned (the officer accepted — see
/// [InspectionTask.acceptedAt]) -> (enRoute once they start navigating) ->
/// (onSite once the geofence check passes) -> completed (inspection
/// submitted). `cancelled` is a separate terminal state (e.g. task
/// withdrawn by an analyst) not reachable from this app yet.
enum InspectionTaskStatus { unassigned, notified, assigned, enRoute, onSite, completed, cancelled }

extension InspectionTaskStatusX on InspectionTaskStatus {
  String get firestoreValue => switch (this) {
        InspectionTaskStatus.unassigned => 'unassigned',
        InspectionTaskStatus.notified => 'notified',
        InspectionTaskStatus.assigned => 'assigned',
        InspectionTaskStatus.enRoute => 'en_route',
        InspectionTaskStatus.onSite => 'on_site',
        InspectionTaskStatus.completed => 'completed',
        InspectionTaskStatus.cancelled => 'cancelled',
      };

  /// User-facing label. `assigned` reads as "Accepted" — see the enum doc
  /// comment — everywhere this label is shown (task lists, filters,
  /// status chips), not just on the Field Officer side.
  String get label => switch (this) {
        InspectionTaskStatus.unassigned => 'Unassigned',
        InspectionTaskStatus.notified => 'Notified',
        InspectionTaskStatus.assigned => 'Accepted',
        InspectionTaskStatus.enRoute => 'En Route',
        InspectionTaskStatus.onSite => 'On Site',
        InspectionTaskStatus.completed => 'Completed',
        InspectionTaskStatus.cancelled => 'Cancelled',
      };

  static InspectionTaskStatus fromFirestoreValue(String value) => switch (value) {
        'unassigned' => InspectionTaskStatus.unassigned,
        'notified' => InspectionTaskStatus.notified,
        'en_route' => InspectionTaskStatus.enRoute,
        'on_site' => InspectionTaskStatus.onSite,
        'completed' => InspectionTaskStatus.completed,
        'cancelled' => InspectionTaskStatus.cancelled,
        _ => InspectionTaskStatus.assigned,
      };
}

/// Who/what created the task. `automatic` tasks have no human `assignedBy`
/// — see services/auto_assignment_service.dart, which today only runs from
/// the Analyst dashboard's "Simulate AI Detection" demo button, standing in
/// for a future real risk-engine trigger.
enum AssignmentType { automatic, manual }

extension AssignmentTypeX on AssignmentType {
  String get firestoreValue => switch (this) {
        AssignmentType.automatic => 'automatic',
        AssignmentType.manual => 'manual',
      };

  String get label => switch (this) {
        AssignmentType.automatic => 'Automatic',
        AssignmentType.manual => 'Manual',
      };

  static AssignmentType fromFirestoreValue(String value) => switch (value) {
        'manual' => AssignmentType.manual,
        _ => AssignmentType.automatic,
      };
}

/// Whether a task's geofence is still meaningful to check against.
/// Flipped to [inactive] once the linked inspection is submitted — the
/// geofence data itself is kept (not deleted) for audit/review, it just
/// stops being something a Field Officer needs to be inside.
enum GeofenceStatus { active, inactive }

extension GeofenceStatusX on GeofenceStatus {
  String get firestoreValue => switch (this) {
        GeofenceStatus.active => 'active',
        GeofenceStatus.inactive => 'inactive',
      };

  static GeofenceStatus fromFirestoreValue(String value) => switch (value) {
        'inactive' => GeofenceStatus.inactive,
        _ => GeofenceStatus.active,
      };
}

/// A field inspection assignment. Not every task originates from a citizen
/// report — [linkedReportId] is null for tasks the risk model itself
/// flagged (see reason text), and set when a citizen/field report drove
/// the assignment, in which case completing the inspection updates that
/// report's status (see services/inspection_repository.dart).
class InspectionTask {
  final String id;

  /// Null when [status] is [InspectionTaskStatus.unassigned] — automatic
  /// assignment falls back to this instead of failing when no Field
  /// Officer is available (see auto_assignment_service.dart).
  final String? assignedOfficerUid;

  final String? linkedReportId;
  final double lat;
  final double lng;
  final RiskLevel riskLevel;
  final String reason;
  final String instructions;
  final InspectionTaskStatus status;
  final DateTime createdAt;

  /// Generated at task-creation time (see core/geofence_utils.dart) — never
  /// looked up from a risk zone or anywhere else afterwards, so it stays
  /// stable even if the originating zone changes later.
  final Geofence geofence;
  final AssignmentType assignmentType;

  /// The analyst's uid for a manual assignment; null for automatic.
  final String? assignedBy;
  final GeofenceStatus geofenceStatus;

  /// When this task was last (re)assigned to its current
  /// [assignedOfficerUid] — set by TaskRepository.assignTask, distinct
  /// from [createdAt] so a reassignment doesn't lose the task's original
  /// creation time. Null for tasks assigned before this field existed.
  final DateTime? assignedAt;

  /// Analyst-set target completion date for the current assignment — see
  /// TaskRepository.assignTask. Null when not set.
  final DateTime? dueDate;

  /// When the Field Officer accepted this task — set by
  /// TaskRepository.acceptTask, which is what moves [status] from
  /// [InspectionTaskStatus.notified] to [InspectionTaskStatus.assigned].
  /// Null while still notified/unassigned, or for tasks created before
  /// this field existed.
  final DateTime? acceptedAt;

  const InspectionTask({
    required this.id,
    required this.lat,
    required this.lng,
    required this.riskLevel,
    required this.reason,
    required this.instructions,
    required this.status,
    required this.createdAt,
    required this.geofence,
    required this.assignmentType,
    this.assignedOfficerUid,
    this.linkedReportId,
    this.assignedBy,
    this.geofenceStatus = GeofenceStatus.active,
    this.assignedAt,
    this.dueDate,
    this.acceptedAt,
  });

  InspectionTask copyWith({
    InspectionTaskStatus? status,
    String? assignedOfficerUid,
    GeofenceStatus? geofenceStatus,
    String? assignedBy,
    DateTime? assignedAt,
    DateTime? dueDate,
    DateTime? acceptedAt,
  }) {
    return InspectionTask(
      id: id,
      assignedOfficerUid: assignedOfficerUid ?? this.assignedOfficerUid,
      linkedReportId: linkedReportId,
      lat: lat,
      lng: lng,
      riskLevel: riskLevel,
      reason: reason,
      instructions: instructions,
      status: status ?? this.status,
      createdAt: createdAt,
      geofence: geofence,
      assignmentType: assignmentType,
      assignedBy: assignedBy ?? this.assignedBy,
      geofenceStatus: geofenceStatus ?? this.geofenceStatus,
      assignedAt: assignedAt ?? this.assignedAt,
      dueDate: dueDate ?? this.dueDate,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  factory InspectionTask.fromFirestore(String id, Map<String, dynamic> data) {
    return InspectionTask(
      id: id,
      assignedOfficerUid: data['assigned_officer_uid'] as String?,
      linkedReportId: data['linked_report_id'] as String?,
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      riskLevel: RiskLevelX.fromFirestoreValue(data['risk_level'] as String? ?? 'low'),
      reason: data['reason'] as String? ?? '',
      instructions: data['instructions'] as String? ?? '',
      status: InspectionTaskStatusX.fromFirestoreValue(data['status'] as String? ?? 'assigned'),
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      geofence: Geofence.fromFirestore(
        (data['geofence'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      assignmentType:
          AssignmentTypeX.fromFirestoreValue(data['assignment_type'] as String? ?? 'automatic'),
      assignedBy: data['assigned_by'] as String?,
      geofenceStatus:
          GeofenceStatusX.fromFirestoreValue(data['geofence_status'] as String? ?? 'active'),
      assignedAt: DateTime.tryParse(data['assigned_at'] as String? ?? ''),
      dueDate: DateTime.tryParse(data['due_date'] as String? ?? ''),
      acceptedAt: DateTime.tryParse(data['accepted_at'] as String? ?? ''),
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
        'geofence': geofence.toFirestore(),
        'assignment_type': assignmentType.firestoreValue,
        'assigned_by': assignedBy,
        'geofence_status': geofenceStatus.firestoreValue,
        'assigned_at': assignedAt?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
      };
}
