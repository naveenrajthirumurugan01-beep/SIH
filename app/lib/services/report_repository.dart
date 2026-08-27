import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../dev/synthetic_dataset.dart';
import '../models/report.dart';
import '../models/user_role.dart';

abstract class ReportRepository {
  /// Live list of reports submitted by [uid] (a real Firebase Auth uid),
  /// newest first.
  Stream<List<Report>> watchMyReports(String uid);

  /// Live list of every report regardless of submitter, newest first. Used
  /// by the Analyst's reports queue and dashboard.
  Stream<List<Report>> watchAllReports();

  Future<Report> submitReport({
    required String uid,
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
  /// SYNTHETIC — replace me. Seeded from the shared [SyntheticDataset] (see
  /// lib/dev/synthetic_dataset.dart) so the Reports Queue isn't empty on
  /// first load — previously started empty until a citizen submitted
  /// something in that exact running session.
  final List<Report> _reports = List.of(SyntheticDataset.instance.reports);
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  List<Report> _filtered(String uid) {
    final mine = _reports.where((r) => r.reporterUid == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  List<Report> _all() {
    final all = List<Report>.from(_reports)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Stream<List<Report>> watchMyReports(String uid) async* {
    yield _filtered(uid);
    await for (final _ in _changes.stream) {
      yield _filtered(uid);
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
    required String uid,
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
      reporterUid: uid,
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
/// Firebase Storage under report_media/{uid}/...
class FirestoreReportRepository implements ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'reports';

  @override
  Stream<List<Report>> watchMyReports(String uid) {
    return _firestore
        .collection(_collection)
        .where('reporter_uid', isEqualTo: uid)
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
    required String uid,
    required UserRole role,
    required HazardType hazardType,
    required String description,
    required double lat,
    required double lng,
    required String district,
    List<String> localMediaPaths = const [],
  }) async {
    final mediaUrls = await Future.wait(
      localMediaPaths.map((path) => _uploadMedia(uid, path)),
    );

    final report = Report(
      id: '', // assigned by Firestore below
      reporterUid: uid,
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

  Future<String> _uploadMedia(String uid, String localPath) async {
    final fileName = '${DateTime.now().microsecondsSinceEpoch}_${localPath.split(Platform.pathSeparator).last}';
    final ref = FirebaseStorage.instance.ref('report_media/$uid/$fileName');
    await ref.putFile(File(localPath));
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
