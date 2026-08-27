enum CrackStatus { none, minor, major }

extension CrackStatusX on CrackStatus {
  String get firestoreValue => switch (this) {
        CrackStatus.none => 'none',
        CrackStatus.minor => 'minor',
        CrackStatus.major => 'major',
      };

  String get label => switch (this) {
        CrackStatus.none => 'None',
        CrackStatus.minor => 'Minor',
        CrackStatus.major => 'Major',
      };

  static CrackStatus fromFirestoreValue(String value) => switch (value) {
        'minor' => CrackStatus.minor,
        'major' => CrackStatus.major,
        _ => CrackStatus.none,
      };
}

enum SlopeMovement { none, minor, significant }

extension SlopeMovementX on SlopeMovement {
  String get firestoreValue => switch (this) {
        SlopeMovement.none => 'none',
        SlopeMovement.minor => 'minor',
        SlopeMovement.significant => 'significant',
      };

  String get label => switch (this) {
        SlopeMovement.none => 'None',
        SlopeMovement.minor => 'Minor',
        SlopeMovement.significant => 'Significant',
      };

  static SlopeMovement fromFirestoreValue(String value) => switch (value) {
        'minor' => SlopeMovement.minor,
        'significant' => SlopeMovement.significant,
        _ => SlopeMovement.none,
      };
}

enum RoadCondition { open, partiallyBlocked, blocked }

extension RoadConditionX on RoadCondition {
  String get firestoreValue => switch (this) {
        RoadCondition.open => 'open',
        RoadCondition.partiallyBlocked => 'partially_blocked',
        RoadCondition.blocked => 'blocked',
      };

  String get label => switch (this) {
        RoadCondition.open => 'Open',
        RoadCondition.partiallyBlocked => 'Partially Blocked',
        RoadCondition.blocked => 'Blocked',
      };

  static RoadCondition fromFirestoreValue(String value) => switch (value) {
        'partially_blocked' => RoadCondition.partiallyBlocked,
        'blocked' => RoadCondition.blocked,
        _ => RoadCondition.open,
      };
}

/// A completed field inspection, always tied to an [InspectionTask]. Submitting
/// one is what closes the loop back to the citizen app — see
/// services/inspection_repository.dart, which uses [indicatesHazard] to
/// decide how the linked report's status should move.
class FieldInspection {
  final String id;
  final String taskId;
  final String officerUid;
  final String officerName;
  final bool geofenceVerified;
  final double checkInLat;
  final double checkInLng;
  final DateTime checkInAt;
  final CrackStatus crackStatus;
  final SlopeMovement slopeMovement;
  final bool rockfall;
  final bool waterSeepage;
  final RoadCondition roadCondition;
  final String notes;
  final List<String> photoUrls;
  final DateTime submittedAt;

  /// GPS captured at actual submission time — distinct from [checkInLat]/
  /// [checkInLng], which are captured earlier at the geofence-check step.
  /// An officer can spend real time filling out the form in between, so
  /// these two fixes can legitimately differ.
  final double submissionLat;
  final double submissionLng;

  /// Client-side re-check of [submissionLat]/[submissionLng] against the
  /// task's geofence at submission time (see core/geo_utils.dart's
  /// isInsideGeofence). This is NOT tamper-proof — a modified client could
  /// report anything. Real enforcement needs a server-side Cloud Function
  /// re-check against trusted location data; that's future work, not part
  /// of this pass. Surfaced to analysts as a review flag, not a hard block.
  final bool locationVerifiedAtSubmission;

  const FieldInspection({
    required this.id,
    required this.taskId,
    required this.officerUid,
    required this.officerName,
    required this.geofenceVerified,
    required this.checkInLat,
    required this.checkInLng,
    required this.checkInAt,
    required this.crackStatus,
    required this.slopeMovement,
    required this.rockfall,
    required this.waterSeepage,
    required this.roadCondition,
    required this.notes,
    required this.photoUrls,
    required this.submittedAt,
    required this.submissionLat,
    required this.submissionLng,
    required this.locationVerifiedAtSubmission,
  });

  /// Whether the officer's findings confirm an active hazard. Anything
  /// beyond "no crack / no movement / no rockfall / no seepage / road
  /// open" counts — drives fieldVerification -> verified vs. -> rejected
  /// on the linked citizen report.
  bool get indicatesHazard =>
      crackStatus != CrackStatus.none ||
      slopeMovement != SlopeMovement.none ||
      rockfall ||
      waterSeepage ||
      roadCondition != RoadCondition.open;

  factory FieldInspection.fromFirestore(String id, Map<String, dynamic> data) {
    return FieldInspection(
      id: id,
      taskId: data['task_id'] as String? ?? '',
      officerUid: data['officer_uid'] as String? ?? '',
      officerName: data['officer_name'] as String? ?? '',
      geofenceVerified: data['geofence_verified'] as bool? ?? false,
      checkInLat: (data['check_in_lat'] as num?)?.toDouble() ?? 0,
      checkInLng: (data['check_in_lng'] as num?)?.toDouble() ?? 0,
      checkInAt: DateTime.tryParse(data['check_in_at'] as String? ?? '') ?? DateTime.now(),
      crackStatus: CrackStatusX.fromFirestoreValue(data['crack_status'] as String? ?? 'none'),
      slopeMovement:
          SlopeMovementX.fromFirestoreValue(data['slope_movement'] as String? ?? 'none'),
      rockfall: data['rockfall'] as bool? ?? false,
      waterSeepage: data['water_seepage'] as bool? ?? false,
      roadCondition:
          RoadConditionX.fromFirestoreValue(data['road_condition'] as String? ?? 'open'),
      notes: data['notes'] as String? ?? '',
      photoUrls: List<String>.from(data['photo_urls'] as List? ?? []),
      submittedAt: DateTime.tryParse(data['submitted_at'] as String? ?? '') ?? DateTime.now(),
      submissionLat: (data['submission_lat'] as num?)?.toDouble() ?? 0,
      submissionLng: (data['submission_lng'] as num?)?.toDouble() ?? 0,
      locationVerifiedAtSubmission: data['location_verified_at_submission'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'task_id': taskId,
        'officer_uid': officerUid,
        'officer_name': officerName,
        'geofence_verified': geofenceVerified,
        'check_in_lat': checkInLat,
        'check_in_lng': checkInLng,
        'check_in_at': checkInAt.toIso8601String(),
        'crack_status': crackStatus.firestoreValue,
        'slope_movement': slopeMovement.firestoreValue,
        'rockfall': rockfall,
        'water_seepage': waterSeepage,
        'road_condition': roadCondition.firestoreValue,
        'notes': notes,
        'photo_urls': photoUrls,
        'submitted_at': submittedAt.toIso8601String(),
        'submission_lat': submissionLat,
        'submission_lng': submissionLng,
        'location_verified_at_submission': locationVerifiedAtSubmission,
      };
}
