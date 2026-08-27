import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/app_config.dart';
import '../models/report.dart';
import '../models/user_role.dart';

abstract class ReportRepository {
  /// Live list of reports submitted by [deviceId], newest first.
  Stream<List<Report>> watchMyReports(String deviceId);

  /// Live list of every report regardless of submitter, newest first. Used
  /// by the Analyst's reports queue and dashboard.
  Stream<List<Report>> watchAllReports();

  Future<Report> submitReport({
    required String deviceId,
    required UserRole role,
    required HazardType hazardType,
    required String description,
    required double lat,
    required double lng,
    required String district,
    List<String> localMediaPaths = const [],
  });

  /// Moves a report to [newStatus]. Used by the Field Officer flow to close
  /// the loop when a linked inspection is submitted (see
  /// services/inspection_repository.dart) — fieldVerification -> verified
  /// or -> rejected depending on what the officer found.
  Future<void> updateReportStatus(String reportId, ReportStatus newStatus);
}

/// SYNTHETIC — replace me. In-memory report store, scoped to the running
/// app instance (nothing persists across restarts). Media is referenced by
/// its local file path only — there is no upload step, since there's no
/// Storage bucket to upload to without a real Firebase project.
class MockReportRepository implements ReportRepository {
  /// Fixed id for the seeded "crack near retaining wall" demo report, so
  /// MockTaskRepository can link a task to it without a runtime lookup.
  static const demoSeedReportId = 'demo_crack_report_1';
  static const demoSeedReportLat = 28.8020;
  static const demoSeedReportLng = 95.8180;

  final List<Report> _reports = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  /// Seeds the demo crack report under [citizenDeviceId] the first time
  /// this is called, so a single demo run can show the full loop: submit
  /// as Citizen (or just launch, since this seeds it automatically) ->
  /// inspect as Field Officer -> see the status change back in the
  /// Citizen's My Reports tab. No-op if already seeded.
  void seedDemoDataIfNeeded(String citizenDeviceId) {
    if (_reports.any((r) => r.id == demoSeedReportId)) return;
    _reports.add(
      Report(
        id: demoSeedReportId,
        reporterUid: citizenDeviceId,
        reporterRole: UserRole.citizen,
        hazardType: HazardType.crack,
        description:
            'Crack near the retaining wall along the Anini-Etalin road, roughly '
            '1.5m long and appears to be widening after recent rain.',
        lat: demoSeedReportLat,
        lng: demoSeedReportLng,
        district: AppConfig.district,
        mediaUrls: const [],
        status: ReportStatus.fieldVerification,
        trustWeight: 1.0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    _changes.add(null);
  }

  List<Report> _filtered(String deviceId) {
    final mine = _reports.where((r) => r.reporterUid == deviceId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  List<Report> _all() {
    final all = List<Report>.from(_reports)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Stream<List<Report>> watchMyReports(String deviceId) async* {
    yield _filtered(deviceId);
    await for (final _ in _changes.stream) {
      yield _filtered(deviceId);
    }
  }

  @override
  Stream<List<Report>> watchAllReports() async* {
    yield _all();
    await for (final _ in _changes.stream) {
      yield _all();
    }
  }

  @override
  Future<Report> submitReport({
    required String deviceId,
    required UserRole role,
    required HazardType hazardType,
    required String description,
    required double lat,
    required double lng,
    required String district,
    List<String> localMediaPaths = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final report = Report(
      id: 'mock_report_${_nextId++}',
      reporterUid: deviceId,
      reporterRole: role,
      hazardType: hazardType,
      description: description,
      lat: lat,
      lng: lng,
      district: district,
      mediaUrls: localMediaPaths,
      status: ReportStatus.submitted,
      trustWeight: role == UserRole.citizen ? 1.0 : 2.0,
      createdAt: DateTime.now(),
    );

    _reports.add(report);
    _changes.add(null);
    return report;
  }

  @override
  Future<void> updateReportStatus(String reportId, ReportStatus newStatus) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) return;
    _reports[index] = _reports[index].copyWith(status: newStatus);
    _changes.add(null);
  }
}

/// Writes to the `reports` Firestore collection and uploads media to
/// Firebase Storage under report_media/{deviceId}/...
class FirestoreReportRepository implements ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'reports';

  @override
  Stream<List<Report>> watchMyReports(String deviceId) {
    return _firestore
        .collection(_collection)
        .where('reporter_uid', isEqualTo: deviceId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Report.fromFirestore(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<Report>> watchAllReports() {
    return _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Report.fromFirestore(doc.id, doc.data())).toList());
  }

  @override
  Future<Report> submitReport({
    required String deviceId,
    required UserRole role,
    required HazardType hazardType,
    required String description,
    required double lat,
    required double lng,
    required String district,
    List<String> localMediaPaths = const [],
  }) async {
    final mediaUrls = await Future.wait(
      localMediaPaths.map((path) => _uploadMedia(deviceId, path)),
    );

    final report = Report(
      id: '', // assigned by Firestore below
      reporterUid: deviceId,
      reporterRole: role,
      hazardType: hazardType,
      description: description,
      lat: lat,
      lng: lng,
      district: district,
      mediaUrls: mediaUrls,
      status: ReportStatus.submitted,
      trustWeight: role == UserRole.citizen ? 1.0 : 2.0,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection(_collection).add(report.toFirestore());
    return report._withId(docRef.id);
  }

  @override
  Future<void> updateReportStatus(String reportId, ReportStatus newStatus) {
    return _firestore
        .collection(_collection)
        .doc(reportId)
        .update({'status': newStatus.firestoreValue});
  }

  Future<String> _uploadMedia(String deviceId, String localPath) async {
    final cleanName = localPath.split('/').last.split(r'\').last;
    final fileName = '${DateTime.now().microsecondsSinceEpoch}_$cleanName';
    final ref = FirebaseStorage.instance.ref('report_media/$deviceId/$fileName');
    await ref.putString(localPath);
    return ref.getDownloadURL();
  }
}

extension _ReportWithId on Report {
  Report _withId(String id) => Report(
        id: id,
        reporterUid: reporterUid,
        reporterRole: reporterRole,
        hazardType: hazardType,
        description: description,
        lat: lat,
        lng: lng,
        district: district,
        mediaUrls: mediaUrls,
        status: status,
        trustWeight: trustWeight,
        createdAt: createdAt,
        roadStatus: roadStatus,
      );
}
