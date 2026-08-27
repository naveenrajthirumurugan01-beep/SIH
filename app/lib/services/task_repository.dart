import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import 'report_repository.dart';

const demoFieldOfficerUid = 'D37iiSHTW6YXreM1qfX9a3bq5XD3';
const demoOfficerUid = demoFieldOfficerUid;

const activeTaskStatuses = {
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

abstract class TaskRepository {
  Stream<List<InspectionTask>> watchTasksForOfficer(String officerUid);
  Stream<List<InspectionTask>> watchAllTasks();
  Future<void> updateTaskStatus(String taskId, InspectionTaskStatus status);
  Future<void> completeTask(String taskId);
  Future<int> countActiveTasksForOfficer(String officerUid);
  Future<InspectionTask> createTask(InspectionTask task);
}

class MockTaskRepository implements TaskRepository {
  MockTaskRepository({required this.reportRepository});

  final ReportRepository reportRepository;

  final List<InspectionTask> _tasks = [
    InspectionTask(
      id: 'task_1',
      assignedOfficerUid: demoFieldOfficerUid,
      linkedReportId: MockReportRepository.demoSeedReportId,
      lat: MockReportRepository.demoSeedReportLat,
      lng: MockReportRepository.demoSeedReportLng,
      riskLevel: RiskLevel.high,
      reason: 'Citizen report: crack near retaining wall',
      instructions:
          'Inspect the reported crack near the retaining wall along the '
          'Anini-Etalin road. Check whether it is actively widening, look '
          'for related slope movement nearby, and photograph the crack '
          'with a size reference.',
      status: InspectionTaskStatus.assigned,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      assignmentType: AssignmentType.manual,
      assignedBy: 'demo_analyst',
    ),
    InspectionTask(
      id: 'task_2',
      assignedOfficerUid: demoFieldOfficerUid,
      lat: 28.7891,
      lng: 95.8328,
      riskLevel: RiskLevel.critical,
      reason: 'AI flagged rising risk — no citizen report yet',
      instructions:
          'Verify current slope condition at the Dri River Slope monitoring '
          'point. Model output shows a sharp rise in predicted risk over the '
          'last 48h; confirm whether visible ground movement, cracking, or '
          'water saturation supports that.',
      status: InspectionTaskStatus.assigned,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      assignmentType: AssignmentType.auto,
    ),
  ];

  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 3;

  int _riskThenRecency(InspectionTask a, InspectionTask b) {
    final riskCompare = b.riskLevel.index.compareTo(a.riskLevel.index);
    if (riskCompare != 0) return riskCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  List<InspectionTask> _filtered(String officerUid) {
    final mine = _tasks
        .where((t) => t.assignedOfficerUid == officerUid || t.assignedOfficerUid == demoOfficerUid)
        .toList()
      ..sort(_riskThenRecency);
    return mine;
  }

  List<InspectionTask> _all() {
    final all = List<InspectionTask>.from(_tasks)..sort(_riskThenRecency);
    return all;
  }

  @override
  Stream<List<InspectionTask>> watchTasksForOfficer(String officerUid) async* {
    yield _filtered(officerUid);
    await for (final _ in _changes.stream) {
      yield _filtered(officerUid);
    }
  }

  @override
  Stream<List<InspectionTask>> watchAllTasks() async* {
    yield _all();
    await for (final _ in _changes.stream) {
      yield _all();
    }
  }

  @override
  Future<void> updateTaskStatus(String taskId, InspectionTaskStatus status) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(status: status);
    _changes.add(null);
  }

  @override
  Future<void> completeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      status: InspectionTaskStatus.completed,
      geofenceStatus: GeofenceStatus.outside,
    );
    _changes.add(null);
  }

  @override
  Future<int> countActiveTasksForOfficer(String officerUid) async {
    return _tasks
        .where((t) =>
            t.assignedOfficerUid == officerUid && activeTaskStatuses.contains(t.status))
        .length;
  }

  @override
  Future<InspectionTask> createTask(InspectionTask task) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final saved = task._withId('mock_task_${_nextId++}');
    _tasks.add(saved);
    _changes.add(null);

    final linkedReportId = saved.linkedReportId;
    if (linkedReportId != null) {
      await reportRepository.updateReportStatus(linkedReportId, ReportStatus.fieldVerification);
    }

    return saved;
  }
}

class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({required this.reportRepository});

  final ReportRepository reportRepository;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'inspection_tasks';

  int _riskThenRecency(InspectionTask a, InspectionTask b) {
    final riskCompare = b.riskLevel.index.compareTo(a.riskLevel.index);
    if (riskCompare != 0) return riskCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  Stream<List<InspectionTask>> watchTasksForOfficer(String officerUid) {
    return _firestore
        .collection(_collection)
        .where('assigned_officer_uid', isEqualTo: officerUid)
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => InspectionTask.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort(_riskThenRecency);
      return tasks;
    });
  }

  @override
  Stream<List<InspectionTask>> watchAllTasks() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => InspectionTask.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort(_riskThenRecency);
      return tasks;
    });
  }

  @override
  Future<void> updateTaskStatus(String taskId, InspectionTaskStatus status) {
    return _firestore
        .collection(_collection)
        .doc(taskId)
        .update({'status': status.firestoreValue});
  }

  @override
  Future<void> completeTask(String taskId) {
    return _firestore.collection(_collection).doc(taskId).update({
      'status': InspectionTaskStatus.completed.firestoreValue,
      'geofence_status': GeofenceStatus.outside.name,
    });
  }

  @override
  Future<int> countActiveTasksForOfficer(String officerUid) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('assigned_officer_uid', isEqualTo: officerUid)
        .where(
          'status',
          whereIn: activeTaskStatuses.map((s) => s.firestoreValue).toList(),
        )
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<InspectionTask> createTask(InspectionTask task) async {
    final docRef = await _firestore.collection(_collection).add(task.toFirestore());
    final saved = task._withId(docRef.id);

    final linkedReportId = saved.linkedReportId;
    if (linkedReportId != null) {
      await reportRepository.updateReportStatus(linkedReportId, ReportStatus.fieldVerification);
    }

    return saved;
  }
}

extension _TaskWithId on InspectionTask {
  InspectionTask _withId(String id) => InspectionTask(
        id: id,
        assignedOfficerUid: assignedOfficerUid,
        linkedReportId: linkedReportId,
        lat: lat,
        lng: lng,
        riskLevel: riskLevel,
        reason: reason,
        instructions: instructions,
        status: status,
        createdAt: createdAt,
        assignmentType: assignmentType,
        assignedBy: assignedBy,
        geofenceStatus: geofenceStatus,
      );
}
