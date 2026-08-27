/// Live Field Evidence Capture Model & Categories (Phase 9)
enum EvidenceCategory {
  slope,
  crack,
  rockfall,
  waterSeepage,
  roadDamage,
  drainage,
  infrastructure,
  other,
}

extension EvidenceCategoryX on EvidenceCategory {
  String get label => switch (this) {
        EvidenceCategory.slope => 'Slope',
        EvidenceCategory.crack => 'Crack',
        EvidenceCategory.rockfall => 'Rockfall',
        EvidenceCategory.waterSeepage => 'Water Seepage',
        EvidenceCategory.roadDamage => 'Road Damage',
        EvidenceCategory.drainage => 'Drainage',
        EvidenceCategory.infrastructure => 'Infrastructure',
        EvidenceCategory.other => 'Other',
      };

  String get firestoreValue => name;

  static EvidenceCategory fromFirestoreValue(String value) => switch (value.toLowerCase()) {
        'slope' => EvidenceCategory.slope,
        'crack' => EvidenceCategory.crack,
        'rockfall' => EvidenceCategory.rockfall,
        'waterseepage' || 'water_seepage' => EvidenceCategory.waterSeepage,
        'roaddamage' || 'road_damage' => EvidenceCategory.roadDamage,
        'drainage' => EvidenceCategory.drainage,
        'infrastructure' => EvidenceCategory.infrastructure,
        _ => EvidenceCategory.other,
      };
}

/// Recorded Field Evidence Item attached to an Inspection ID
class FieldEvidenceItem {
  final String id; // Evidence ID (e.g. EVD-2026-001)
  final String inspectionId; // Inspection ID
  final String officerUid; // Field Officer ID
  final EvidenceCategory category; // Category
  final String localFilePath; // Local file path
  final String? cloudUrl; // Remote Storage URL
  final int fileSizeBytes; // File size in bytes
  final String mediaType; // 'photo' | 'video'
  final double latitude; // Capture Latitude
  final double longitude; // Capture Longitude
  final double gpsAccuracyMeters; // GPS Accuracy
  final DateTime capturedAt; // Timestamp
  final bool isZoneVerified; // TRUE only if captured inside assigned inspection zone with valid GPS fix

  const FieldEvidenceItem({
    required this.id,
    required this.inspectionId,
    required this.officerUid,
    required this.category,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.mediaType,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyMeters,
    required this.capturedAt,
    required this.isZoneVerified,
    this.cloudUrl,
  });

  Map<String, dynamic> toFirestore() => {
        'evidence_id': id,
        'inspection_id': inspectionId,
        'officer_uid': officerUid,
        'category': category.firestoreValue,
        'local_file_path': localFilePath,
        'cloud_url': cloudUrl,
        'file_size_bytes': fileSizeBytes,
        'media_type': mediaType,
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy_meters': gpsAccuracyMeters,
        'captured_at': capturedAt.toIso8601String(),
        'is_zone_verified': isZoneVerified,
      };

  factory FieldEvidenceItem.fromFirestore(Map<String, dynamic> data) {
    return FieldEvidenceItem(
      id: data['evidence_id'] as String? ?? '',
      inspectionId: data['inspection_id'] as String? ?? '',
      officerUid: data['officer_uid'] as String? ?? '',
      category: EvidenceCategoryX.fromFirestoreValue(data['category'] as String? ?? 'other'),
      localFilePath: data['local_file_path'] as String? ?? '',
      cloudUrl: data['cloud_url'] as String?,
      fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt() ?? 0,
      mediaType: data['media_type'] as String? ?? 'photo',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      gpsAccuracyMeters: (data['gps_accuracy_meters'] as num?)?.toDouble() ?? 0,
      capturedAt: DateTime.tryParse(data['captured_at'] as String? ?? '') ?? DateTime.now(),
      isZoneVerified: data['is_zone_verified'] as bool? ?? false,
    );
  }
}
