import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import 'report_repository.dart';

/// No real assignment system yet (see role_entry_screen.dart) — every
/// seeded mock task is assigned to this fixed officer id, and the role
/// entry screen prefills the Officer ID field with it so the demo tasks
/// show up without any extra setup.
const demoOfficerUid = 'demo_officer';

abstract class TaskRepository {
  /// Live list of tasks assigned to [officerUid], highest risk then
  /// newest first.
  Stream<List<InspectionTask>> watchTasksForOfficer(String officerUid);

  /// Live list of every task regardless of assignee, highest risk then
  /// newest first. Used by the Analyst's tasks screen and dashboard.
  Stream<List<InspectionTask>> watchAllTasks();

  Future<void> updateTaskStatus(String taskId, InspectionTaskStatus status);

  /// Creates a task (pass `id: ''`; a real id is assigned and returned).
  /// When [InspectionTask.linkedReportId] is set, this also pushes that
  /// report to `fieldVerification` — the same cross-repository pattern
  /// InspectionRepository uses when an inspection is submitted, just run
  /// at assignment time instead of completion time.
  Future<InspectionTask> createTask(InspectionTask task);
}

/// SYNTHETIC — replace me. Two seeded tasks: one linked to the demo crack
/// report (see MockReportRepository.demoSeedReportId), one at the
/// critical-risk landslide-inventory point with no citizen report behind
/// it yet.
class MockTaskRepository implements TaskRepository {
  MockTaskRepository({required this.reportRepository});

  final ReportRepository reportRepository;

  final List<InspectionTask> _tasks = [
    InspectionTask(
      id: 'task_1',
      assignedOfficerUid: demoOfficerUid,
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
    ),
    InspectionTask(
      id: 'task_2',
      assignedOfficerUid: demoOfficerUid,
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
    ),
  ];

  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 3; // task_1 and task_2 are already taken by the seed data

  int _riskThenRecency(InspectionTask a, InspectionTask b) {
    final riskCompare = b.riskLevel.index.compareTo(a.riskLevel.index);
    if (riskCompare != 0) return riskCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  List<InspectionTask> _filtered(String officerUid) {
    final mine = _tasks.where((t) => t.assignedOfficerUid == officerUid).toList()
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

/// Reads/writes the `inspection_tasks` Firestore collection once a real
/// Firebase project is wired up (see AppConfig.useMockData).
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
      );
}
