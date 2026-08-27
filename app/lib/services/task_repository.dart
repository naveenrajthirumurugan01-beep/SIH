import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../dev/synthetic_dataset.dart';
import '../models/report.dart';
import '../models/task.dart';
import 'report_repository.dart';

/// Task statuses that count as "still open" for the purposes of the
/// automatic-assignment fairness rule (see auto_assignment_service.dart) —
/// deliberately excludes completed/cancelled/unassigned.
const activeTaskStatuses = {
  InspectionTaskStatus.notified,
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

abstract class TaskRepository {
  /// Live list of tasks assigned to [officerUid], highest risk then
  /// newest first.
  Stream<List<InspectionTask>> watchTasksForOfficer(String officerUid);

  /// Live list of every task regardless of assignee, highest risk then
  /// newest first. Used by the Analyst's tasks screen and dashboard.
  Stream<List<InspectionTask>> watchAllTasks();

  Future<void> updateTaskStatus(String taskId, InspectionTaskStatus status);

  /// Marks a task completed AND its geofence inactive in one update — this
  /// is the combined transition that happens when an inspection is
  /// submitted (see InspectionRepository.submitInspection). The geofence
  /// data itself is kept, not deleted, for audit/review.
  Future<void> completeTask(String taskId);

  /// Count of [activeTaskStatuses] tasks currently assigned to [officerUid]
  /// — the fairness signal automatic assignment picks the minimum of.
  Future<int> countActiveTasksForOfficer(String officerUid);

  /// Creates a task (pass `id: ''`; a real id is assigned and returned).
  /// When [InspectionTask.linkedReportId] is set, this also pushes that
  /// report to `fieldVerification` — the same cross-repository pattern
  /// InspectionRepository uses when an inspection is submitted, just run
  /// at assignment time instead of completion time.
  Future<InspectionTask> createTask(InspectionTask task);

  /// Manually (re)assigns an existing task to [officerUid] — the Analyst
  /// Inspections page's "Assign Field Officer" flow. Distinct from
  /// [createTask]: this targets a task that already exists (whether
  /// unassigned or previously assigned to someone else), not a brand-new
  /// one. Always resets [InspectionTask.status] to
  /// [InspectionTaskStatus.assigned] — a (re)assignment means whoever now
  /// holds it hasn't started yet, even if a previous officer had — and
  /// stamps [InspectionTask.assignedAt]/[InspectionTask.assignedBy] with
  /// this action, leaving [InspectionTask.createdAt] untouched.
  Future<void> assignTask(
    String taskId, {
    required String officerUid,
    required String assignedBy,
    DateTime? dueDate,
  });

  /// Field Officer accepts a task currently in
  /// [InspectionTaskStatus.notified] — stamps [InspectionTask.acceptedAt]
  /// and moves [InspectionTask.status] to [InspectionTaskStatus.assigned],
  /// which is what unlocks the inspection flow (geofence check, inspection
  /// form) on the Field Officer side.
  Future<void> acceptTask(String taskId);
}

/// SYNTHETIC — replace me. Tasks come from the shared [SyntheticDataset]
/// (see lib/dev/synthetic_dataset.dart), spread across every status and
/// assigned to the real field@gmail.com Field Officer account so signing
/// in as that account actually sees them.
class MockTaskRepository implements TaskRepository {
  MockTaskRepository({required this.reportRepository});

  final ReportRepository reportRepository;

  final List<InspectionTask> _tasks = List.of(SyntheticDataset.instance.tasks);

  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

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
  Future<void> completeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      status: InspectionTaskStatus.completed,
      geofenceStatus: GeofenceStatus.inactive,
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

  @override
  Future<void> assignTask(
    String taskId, {
    required String officerUid,
    required String assignedBy,
    DateTime? dueDate,
  }) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      assignedOfficerUid: officerUid,
      status: InspectionTaskStatus.assigned,
      assignedBy: assignedBy,
      assignedAt: DateTime.now(),
      dueDate: dueDate,
    );
    _changes.add(null);
  }

  @override
  Future<void> acceptTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      status: InspectionTaskStatus.assigned,
      acceptedAt: DateTime.now(),
    );
    _changes.add(null);
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
  Future<void> completeTask(String taskId) {
    return _firestore.collection(_collection).doc(taskId).update({
      'status': InspectionTaskStatus.completed.firestoreValue,
      'geofence_status': GeofenceStatus.inactive.firestoreValue,
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

  @override
  Future<void> assignTask(
    String taskId, {
    required String officerUid,
    required String assignedBy,
    DateTime? dueDate,
  }) {
    return _firestore.collection(_collection).doc(taskId).update({
      'assigned_officer_uid': officerUid,
      'status': InspectionTaskStatus.assigned.firestoreValue,
      'assigned_by': assignedBy,
      'assigned_at': DateTime.now().toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
    });
  }

  @override
  Future<void> acceptTask(String taskId) {
    return _firestore.collection(_collection).doc(taskId).update({
      'status': InspectionTaskStatus.assigned.firestoreValue,
      'accepted_at': DateTime.now().toIso8601String(),
    });
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
        geofence: geofence,
        assignmentType: assignmentType,
        assignedBy: assignedBy,
        geofenceStatus: geofenceStatus,
      );
}
