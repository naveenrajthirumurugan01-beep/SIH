import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/geo_utils.dart';
import '../models/inspection.dart';
import '../models/report.dart';
import '../models/task.dart';
import 'report_repository.dart';
import 'task_repository.dart';

abstract class InspectionRepository {
  /// Live list of inspections submitted by [officerUid], newest first.
  Stream<List<FieldInspection>> watchMyInspections(String officerUid);

  Future<FieldInspection> submitInspection({
    required InspectionTask task,
    required String officerUid,
    required String officerName,
    required double checkInLat,
    required double checkInLng,
    required DateTime checkInAt,
    required double submissionLat,
    required double submissionLng,
    required CrackStatus crackStatus,
    required SlopeMovement slopeMovement,
    required bool rockfall,
    required bool waterSeepage,
    required RoadCondition roadCondition,
    required String notes,
    List<String> localPhotoPaths = const [],
  });
}

/// SYNTHETIC — replace me. In-memory inspection store, scoped to the
/// running app instance. Holds [reportRepository] and [taskRepository] so
/// submitting an inspection can perform the closed-loop update itself
/// (mark the task completed, and push the linked citizen report forward)
/// without the calling screen having to orchestrate three repositories.
class MockInspectionRepository implements InspectionRepository {
  MockInspectionRepository({required this.reportRepository, required this.taskRepository});

  final ReportRepository reportRepository;
  final TaskRepository taskRepository;

  final List<FieldInspection> _inspections = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  List<FieldInspection> _filtered(String officerUid) {
    final mine = _inspections.where((i) => i.officerUid == officerUid).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return mine;
  }

  @override
  Stream<List<FieldInspection>> watchMyInspections(String officerUid) async* {
    yield _filtered(officerUid);
    await for (final _ in _changes.stream) {
      yield _filtered(officerUid);
    }
  }

  @override
  Future<FieldInspection> submitInspection({
    required InspectionTask task,
    required String officerUid,
    required String officerName,
    required double checkInLat,
    required double checkInLng,
    required DateTime checkInAt,
    required double submissionLat,
    required double submissionLng,
    required CrackStatus crackStatus,
    required SlopeMovement slopeMovement,
    required bool rockfall,
    required bool waterSeepage,
    required RoadCondition roadCondition,
    required String notes,
    List<String> localPhotoPaths = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final inspection = FieldInspection(
      id: 'mock_inspection_${_nextId++}',
      taskId: task.id,
      officerUid: officerUid,
      officerName: officerName,
      geofenceVerified: true,
      checkInLat: checkInLat,
      checkInLng: checkInLng,
      checkInAt: checkInAt,
      crackStatus: crackStatus,
      slopeMovement: slopeMovement,
      rockfall: rockfall,
      waterSeepage: waterSeepage,
      roadCondition: roadCondition,
      notes: notes,
      photoUrls: localPhotoPaths,
      submittedAt: DateTime.now(),
      submissionLat: submissionLat,
      submissionLng: submissionLng,
      locationVerifiedAtSubmission: isInsideGeofence(submissionLat, submissionLng, task.boundary),
    );

    _inspections.add(inspection);
    _changes.add(null);

    await _closeLoop(task, inspection);

    return inspection;
  }

  Future<void> _closeLoop(InspectionTask task, FieldInspection inspection) async {
    await taskRepository.completeTask(task.id);

    final linkedReportId = task.linkedReportId;
    if (linkedReportId == null) return;

    final newStatus =
        inspection.indicatesHazard ? ReportStatus.verified : ReportStatus.rejected;
    await reportRepository.updateReportStatus(linkedReportId, newStatus);
  }
}

/// Writes to the `field_inspections` Firestore collection and uploads
/// photos to Firebase Storage under field_inspection_media/{officerUid}/...
class FirestoreInspectionRepository implements InspectionRepository {
  FirestoreInspectionRepository({required this.reportRepository, required this.taskRepository});

  final ReportRepository reportRepository;
  final TaskRepository taskRepository;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'field_inspections';

  @override
  Stream<List<FieldInspection>> watchMyInspections(String officerUid) {
    return _firestore
        .collection(_collection)
        .where('officer_uid', isEqualTo: officerUid)
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FieldInspection.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<FieldInspection> submitInspection({
    required InspectionTask task,
    required String officerUid,
    required String officerName,
    required double checkInLat,
    required double checkInLng,
    required DateTime checkInAt,
    required double submissionLat,
    required double submissionLng,
    required CrackStatus crackStatus,
    required SlopeMovement slopeMovement,
    required bool rockfall,
    required bool waterSeepage,
    required RoadCondition roadCondition,
    required String notes,
    List<String> localPhotoPaths = const [],
  }) async {
    final photoUrls = await Future.wait(
      localPhotoPaths.map((path) => _uploadPhoto(officerUid, path)),
    );

    final inspection = FieldInspection(
      id: '', // assigned by Firestore below
      taskId: task.id,
      officerUid: officerUid,
      officerName: officerName,
      geofenceVerified: true,
      checkInLat: checkInLat,
      checkInLng: checkInLng,
      checkInAt: checkInAt,
      crackStatus: crackStatus,
      slopeMovement: slopeMovement,
      rockfall: rockfall,
      waterSeepage: waterSeepage,
      roadCondition: roadCondition,
      notes: notes,
      photoUrls: photoUrls,
      submittedAt: DateTime.now(),
      submissionLat: submissionLat,
      submissionLng: submissionLng,
      locationVerifiedAtSubmission: isInsideGeofence(submissionLat, submissionLng, task.boundary),
    );

    final docRef = await _firestore.collection(_collection).add(inspection.toFirestore());
    final saved = FieldInspection.fromFirestore(docRef.id, inspection.toFirestore());

    await _closeLoop(task, saved);

    return saved;
  }

  Future<void> _closeLoop(InspectionTask task, FieldInspection inspection) async {
    await taskRepository.completeTask(task.id);

    final linkedReportId = task.linkedReportId;
    if (linkedReportId == null) return;

    final newStatus =
        inspection.indicatesHazard ? ReportStatus.verified : ReportStatus.rejected;
    await reportRepository.updateReportStatus(linkedReportId, newStatus);
  }

  Future<String> _uploadPhoto(String officerUid, String localPath) async {
    final cleanName = localPath.split('/').last.split(r'\').last;
    final fileName = '${DateTime.now().microsecondsSinceEpoch}_$cleanName';
    final ref = FirebaseStorage.instance.ref('field_inspection_media/$officerUid/$fileName');
    await ref.putString(localPath);
    return ref.getDownloadURL();
  }
}
