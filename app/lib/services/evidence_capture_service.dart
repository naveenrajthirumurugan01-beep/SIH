import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field_evidence.dart';
import '../models/task.dart';
import 'location_service.dart';

class EvidenceCaptureException implements Exception {
  final String message;
  final String code; // 'permission_denied' | 'capture_failed' | 'storage_failed'

  EvidenceCaptureException(this.message, {this.code = 'capture_failed'});

  @override
  String toString() => message;
}

/// Service handling live camera evidence capture for Field Officer inspection (Phase 9).
/// Fully cross-platform supported on Web, Android, iOS, and Desktop.
class EvidenceCaptureService {
  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();
  int _nextEvidenceCounter = 101;

  Future<FieldEvidenceItem> captureLiveCameraEvidence({
    required InspectionTask task,
    required String officerUid,
    required EvidenceCategory category,
  }) async {
    // 1. Trigger Live Camera / Image Capture
    XFile? capturedFile;
    try {
      capturedFile = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('permission') || errStr.contains('denied')) {
        throw EvidenceCaptureException(
          'Camera permission was denied. Please grant camera access in system settings to capture field evidence.',
          code: 'permission_denied',
        );
      }
      throw EvidenceCaptureException(
        'Camera capture failed: ${e.toString()}',
        code: 'capture_failed',
      );
    }

    if (capturedFile == null) {
      throw EvidenceCaptureException('Camera capture was cancelled by officer.', code: 'cancelled');
    }

    // 2. Cross-platform file length retrieval
    int fileSize = 0;
    try {
      fileSize = await capturedFile.length();
    } catch (_) {
      fileSize = 1024 * 50; // Fallback size if unavailable
    }

    // 3. Acquire Live Telemetry & Verify Inspection Zone
    final fix = await _locationService.getFieldGpsFix();
    final isInsideBoundary = task.boundary.containsPoint(fix.latitude, fix.longitude);
    final isZoneVerified = isInsideBoundary && fix.accuracyMeters <= 30.0 && fix.accuracyMeters > 0;

    final evidenceId = 'EVD-${DateTime.now().year}-${_nextEvidenceCounter++}';

    return FieldEvidenceItem(
      id: evidenceId,
      inspectionId: task.id,
      officerUid: officerUid,
      category: category,
      localFilePath: capturedFile.path,
      fileSizeBytes: fileSize,
      mediaType: 'photo',
      latitude: fix.latitude,
      longitude: fix.longitude,
      gpsAccuracyMeters: fix.accuracyMeters,
      capturedAt: DateTime.now(),
      isZoneVerified: isZoneVerified,
    );
  }
}
