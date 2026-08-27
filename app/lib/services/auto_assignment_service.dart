import '../models/risk_zone.dart';
import '../models/task.dart';
import 'auth_repository.dart';
import 'task_repository.dart';

Future<InspectionTask> autoAssignInspection({
  required RiskZone zone,
  required TaskRepository taskRepository,
  required AuthRepository authRepository,
}) async {
  final officers = await authRepository.watchEnabledFieldOfficers().first;

  String? assignedOfficerUid;
  var status = InspectionTaskStatus.unassigned;

  if (officers.isNotEmpty) {
    final counts = await Future.wait(
      officers.map((o) => taskRepository.countActiveTasksForOfficer(o.uid)),
    );

    var minIndex = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] < counts[minIndex]) minIndex = i;
    }

    assignedOfficerUid = officers[minIndex].uid;
    status = InspectionTaskStatus.assigned;
  }

  final task = InspectionTask(
    id: '',
    assignedOfficerUid: assignedOfficerUid ?? demoOfficerUid,
    lat: zone.lat,
    lng: zone.lng,
    riskLevel: zone.level,
    reason: 'AI flagged rising risk — no citizen report yet',
    instructions:
        'Inspect ${zone.name}. This task was flagged automatically by the risk '
        'model, not from a citizen report — confirm current ground conditions.',
    status: status,
    createdAt: DateTime.now(),
    assignmentType: AssignmentType.auto,
  );

  return taskRepository.createTask(task);
}
