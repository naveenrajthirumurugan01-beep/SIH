/// Location Verification Model & State Machine for Field Officer Inspection (Phase 7)
enum LocationVerificationState {
  gpsUnavailable, // State 1: GPS disabled or permission denied
  accuracyTooPoor, // State 2: GPS accuracy > 30m
  outsideInspectionZone, // State 3: GPS fix valid, but officer is outside boundary
  insideInspectionZone, // State 4: Officer inside boundary, verifying stability
  locationVerified, // State 5: FULLY VERIFIED! All criteria satisfied
}

/// Official Recorded Location Verification Proof
class LocationVerificationRecord {
  final String inspectionId;
  final String officerUid;
  final double latitude;
  final double longitude;
  final double gpsAccuracyMeters;
  final DateTime timestamp;
  final LocationVerificationState state;
  final String message;
  final bool isVerified;

  const LocationVerificationRecord({
    required this.inspectionId,
    required this.officerUid,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyMeters,
    required this.timestamp,
    required this.state,
    required this.message,
    required this.isVerified,
  });

  Map<String, dynamic> toFirestore() => {
        'inspection_id': inspectionId,
        'officer_uid': officerUid,
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy_meters': gpsAccuracyMeters,
        'timestamp': timestamp.toIso8601String(),
        'verification_state': state.name,
        'is_verified': isVerified,
      };

  factory LocationVerificationRecord.fromFirestore(Map<String, dynamic> data) {
    return LocationVerificationRecord(
      inspectionId: data['inspection_id'] as String? ?? '',
      officerUid: data['officer_uid'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      gpsAccuracyMeters: (data['gps_accuracy_meters'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ?? DateTime.now(),
      state: LocationVerificationState.values.firstWhere(
        (e) => e.name == data['verification_state'],
        orElse: () => LocationVerificationState.gpsUnavailable,
      ),
      message: data['message'] as String? ?? '',
      isVerified: data['is_verified'] as bool? ?? false,
    );
  }
}
