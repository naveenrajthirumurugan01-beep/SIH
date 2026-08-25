import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/report.dart';
import '../constants/app_constants.dart';

/// Reads/writes reports directly against Firestore (simpler for a hackathon
/// prototype than round-tripping through the backend for CRUD; the backend
/// report endpoints remain useful for server-side validation/trust-weight
/// logic once that's implemented).
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Report>> watchReports({String? district}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestoreCollections.reports)
        .orderBy('created_at', descending: true);

    if (district != null) {
      query = query.where('district', isEqualTo: district);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Report.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// TODO: upload media_urls via firebase_storage first (see
  /// core/services/storage_service.dart), then write this doc with the
  /// resulting download URLs.
  Future<void> submitReport({
    required String reporterUid,
    required UserRole reporterRole,
    required String description,
    required double lat,
    required double lng,
    required String district,
    List<String> mediaUrls = const [],
    RoadStatus? roadStatus,
  }) {
    throw UnimplementedError('TODO: write report doc to Firestore');
  }

  Future<void> reviewReport(String reportId, ReportStatus status) {
    throw UnimplementedError('TODO: analyst/admin approve or reject a report');
  }
}
