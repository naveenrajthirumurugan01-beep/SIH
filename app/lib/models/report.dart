import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

/// Citizen/field-official moderation pipeline. `rejected` is a terminal
/// state reached from `underReview` or `fieldVerification`, kept separate
/// from the main forward-moving stepper (see widgets/status_stepper.dart).
enum ReportStatus { submitted, underReview, fieldVerification, verified, resolved, rejected }

extension ReportStatusX on ReportStatus {
  String get firestoreValue => switch (this) {
        ReportStatus.submitted => 'submitted',
        ReportStatus.underReview => 'under_review',
        ReportStatus.fieldVerification => 'field_verification',
        ReportStatus.verified => 'verified',
        ReportStatus.resolved => 'resolved',
        ReportStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        ReportStatus.submitted => 'Submitted',
        ReportStatus.underReview => 'Under Review',
        ReportStatus.fieldVerification => 'Field Verification',
        ReportStatus.verified => 'Verified',
        ReportStatus.resolved => 'Resolved',
        ReportStatus.rejected => 'Rejected',
      };

  static ReportStatus fromFirestoreValue(String value) => switch (value) {
        'under_review' => ReportStatus.underReview,
        'field_verification' => ReportStatus.fieldVerification,
        'verified' => ReportStatus.verified,
        'resolved' => ReportStatus.resolved,
        'rejected' => ReportStatus.rejected,
        _ => ReportStatus.submitted,
      };
}

enum HazardType {
  crack,
  landslide,
  rockfall,
  roadBlockage,
  waterSeepage,
  soilMovement,
  damagedInfrastructure,
  other,
}

extension HazardTypeX on HazardType {
  String get firestoreValue => switch (this) {
        HazardType.crack => 'crack',
        HazardType.landslide => 'landslide',
        HazardType.rockfall => 'rockfall',
        HazardType.roadBlockage => 'road_blockage',
        HazardType.waterSeepage => 'water_seepage',
        HazardType.soilMovement => 'soil_movement',
        HazardType.damagedInfrastructure => 'damaged_infrastructure',
        HazardType.other => 'other',
      };

  String get label => switch (this) {
        HazardType.crack => 'Crack',
        HazardType.landslide => 'Landslide',
        HazardType.rockfall => 'Rockfall',
        HazardType.roadBlockage => 'Road Blockage',
        HazardType.waterSeepage => 'Water Seepage',
        HazardType.soilMovement => 'Soil Movement',
        HazardType.damagedInfrastructure => 'Damaged Infrastructure',
        HazardType.other => 'Other',
      };

  static HazardType fromFirestoreValue(String value) => switch (value) {
        'landslide' => HazardType.landslide,
        'rockfall' => HazardType.rockfall,
        'road_blockage' => HazardType.roadBlockage,
        'water_seepage' => HazardType.waterSeepage,
        'soil_movement' => HazardType.soilMovement,
        'damaged_infrastructure' => HazardType.damagedInfrastructure,
        'other' => HazardType.other,
        _ => HazardType.crack,
      };
}

enum RoadStatus { clear, partiallyOpen, blocked }

extension RoadStatusX on RoadStatus {
  String get firestoreValue => switch (this) {
        RoadStatus.clear => 'clear',
        RoadStatus.partiallyOpen => 'partially_open',
        RoadStatus.blocked => 'blocked',
      };

  String get label => switch (this) {
        RoadStatus.clear => 'Clear',
        RoadStatus.partiallyOpen => 'Partially Open',
        RoadStatus.blocked => 'Blocked',
      };
}

class Report {
  final String id;
  final String reporterUid;
  final UserRole reporterRole;
  final HazardType hazardType;
  final String description;
  final double lat;
  final double lng;
  final String district;
  final List<String> mediaUrls;
  final RoadStatus? roadStatus;
  final ReportStatus status;
  final double trustWeight;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterUid,
    required this.reporterRole,
    required this.hazardType,
    required this.description,
    required this.lat,
    required this.lng,
    required this.district,
    required this.mediaUrls,
    required this.status,
    required this.trustWeight,
    required this.createdAt,
    this.roadStatus,
  });

  Report copyWith({ReportStatus? status}) {
    return Report(
      id: id,
      reporterUid: reporterUid,
      reporterRole: reporterRole,
      hazardType: hazardType,
      description: description,
      lat: lat,
      lng: lng,
      district: district,
      mediaUrls: mediaUrls,
      status: status ?? this.status,
      trustWeight: trustWeight,
      createdAt: createdAt,
      roadStatus: roadStatus,
    );
  }

  factory Report.fromFirestore(String id, Map<String, dynamic> data) {
    return Report(
      id: id,
      reporterUid: data['reporter_uid'] as String? ?? '',
      reporterRole: UserRoleX.fromFirestoreValue(data['reporter_role'] as String? ?? 'citizen'),
      hazardType: HazardTypeX.fromFirestoreValue(data['hazard_type'] as String? ?? 'other'),
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      district: data['district'] as String? ?? '',
      mediaUrls: List<String>.from(data['media_urls'] as List? ?? []),
      status: ReportStatusX.fromFirestoreValue(data['status'] as String? ?? 'submitted'),
      trustWeight: (data['trust_weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'reporter_uid': reporterUid,
        'reporter_role': reporterRole.firestoreValue,
        'hazard_type': hazardType.firestoreValue,
        'description': description,
        'lat': lat,
        'lng': lng,
        'district': district,
        'media_urls': mediaUrls,
        'road_status': roadStatus?.firestoreValue,
        'status': status.firestoreValue,
        'trust_weight': trustWeight,
        'created_at': FieldValue.serverTimestamp(),
      };
}
