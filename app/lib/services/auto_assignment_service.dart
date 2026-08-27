import '../core/geofence_utils.dart';
import '../models/geofence.dart';
import '../models/risk_zone.dart';
import '../models/task.dart';
import 'auth_repository.dart';
import 'task_repository.dart';

/// Stands in for a real risk-engine trigger, which doesn't exist yet (no
/// FastAPI backend). Today this only runs from the Analyst dashboard's
/// "Simulate AI Detection" demo button — see
/// screens/analyst/dashboard_screen.dart — but its signature takes plain
/// repositories rather than anything UI-specific, so a future real
/// trigger (a Cloud Function reacting to a risk-zone update, say) can call
/// this same function without it changing shape.
///
/// TODO(future work): wire this to an actual automatic trigger once the
/// FastAPI risk engine exists — out of scope for this pass.
Future<InspectionTask> autoAssignInspection({
  required RiskZone zone,
  required TaskRepository taskRepository,
  required AuthRepository authRepository,
}) async {
  final radiusMeters = radiusMetersForSeverity(zone.level);

  final officers = await authRepository.watchEnabledFieldOfficers().first;

  String? assignedOfficerUid;
  var status = InspectionTaskStatus.unassigned;

  if (officers.isNotEmpty) {
    // Simplest fair rule: whichever enabled officer currently has the
    // fewest non-completed tasks. Ties go to whichever officer is checked
    // first (list order), which is fine for this MVP.
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
  // If no officer is enabled/available, the task is created unassigned
  // rather than failing — see InspectionTaskStatus.unassigned.

  final task = InspectionTask(
    id: '',
    assignedOfficerUid: assignedOfficerUid,
    lat: zone.lat,
    lng: zone.lng,
    riskLevel: zone.level,
    reason: 'AI flagged rising risk — no citizen report yet',
    instructions:
        'Inspect ${zone.name}. This task was flagged automatically by the risk '
        'model, not from a citizen report — confirm current ground conditions.',
    status: status,
    createdAt: DateTime.now(),
    geofence: Geofence.circle(
      centerLat: zone.lat,
      centerLng: zone.lng,
      radiusMeters: radiusMeters,
    ),
    assignmentType: AssignmentType.automatic,
  );

  return taskRepository.createTask(task);
}
