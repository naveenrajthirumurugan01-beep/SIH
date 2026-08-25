import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

enum ReportStatus { pending, approved, rejected }

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

  factory Report.fromFirestore(String id, Map<String, dynamic> data) {
    return Report(
      id: id,
      reporterUid: data['reporter_uid'] as String? ?? '',
      reporterRole: UserRoleX.fromFirestoreValue(data['reporter_role'] as String? ?? 'citizen'),
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      district: data['district'] as String? ?? '',
      mediaUrls: List<String>.from(data['media_urls'] as List? ?? []),
      status: ReportStatus.values.byName(data['status'] as String? ?? 'pending'),
      trustWeight: (data['trust_weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
