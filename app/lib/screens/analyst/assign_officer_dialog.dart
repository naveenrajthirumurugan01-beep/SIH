import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/geofence_utils.dart';
import '../../models/app_user.dart';
import '../../models/geofence.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';

/// Shared "pick a Field Officer" dialog — same interaction pattern already
/// used by TasksScreen's Flag Zone flow and ReportsQueueScreen's Assign
/// flow, factored out here so the new Alerts "Assign" action doesn't
/// duplicate a third copy.
Future<AppUser?> pickFieldOfficer(BuildContext context, List<AppUser> officers) {
  return showDialog<AppUser>(
    context: context,
    builder: (context) => _PickOfficerDialog(officers: officers),
  );
}

/// Creates a manually-assigned inspection task centered at ([lat], [lng])
/// with a severity-appropriate geofence — the same shape TasksScreen and
/// ReportsQueueScreen already create tasks with. [status] defaults to
/// [InspectionTaskStatus.assigned] for those existing direct-assign
/// callers; [notifyFieldOfficerAt] below is a thin wrapper over this same
/// function for the newer notify-then-accept flow.
Future<void> assignInspectionAt(
  AppState appState, {
  required AppUser officer,
  required double lat,
  required double lng,
  required RiskLevel riskLevel,
  required String reason,
  required String instructions,
  String? linkedReportId,
  InspectionTaskStatus status = InspectionTaskStatus.assigned,
}) {
  return appState.taskRepository.createTask(
    InspectionTask(
      id: '',
      assignedOfficerUid: officer.uid,
      linkedReportId: linkedReportId,
      lat: lat,
      lng: lng,
      riskLevel: riskLevel,
      reason: reason,
      instructions: instructions,
      status: status,
      createdAt: DateTime.now(),
      geofence: Geofence.circle(
        centerLat: lat,
        centerLng: lng,
        radiusMeters: radiusMetersForSeverity(riskLevel),
      ),
      assignmentType: AssignmentType.manual,
      assignedBy: appState.uid,
    ),
  );
}

/// Creates a task in [InspectionTaskStatus.notified] rather than jumping
/// straight to [InspectionTaskStatus.assigned] — the Risk Zone panel's
/// "Notify Field Officer" button and the Alerts screen's "Assign" action
/// both call this, instead of duplicating [assignInspectionAt], so the two
/// entry points behave identically. The officer must explicitly accept
/// (see TaskRepository.acceptTask) before the task counts as assigned.
Future<void> notifyFieldOfficerAt(
  AppState appState, {
  required AppUser officer,
  required double lat,
  required double lng,
  required RiskLevel riskLevel,
  required String reason,
  required String instructions,
  String? linkedReportId,
}) {
  return assignInspectionAt(
    appState,
    officer: officer,
    lat: lat,
    lng: lng,
    riskLevel: riskLevel,
    reason: reason,
    instructions: instructions,
    linkedReportId: linkedReportId,
    status: InspectionTaskStatus.notified,
  );
}

class _PickOfficerDialog extends StatefulWidget {
  final List<AppUser> officers;

  const _PickOfficerDialog({required this.officers});

  @override
  State<_PickOfficerDialog> createState() => _PickOfficerDialogState();
}

class _PickOfficerDialogState extends State<_PickOfficerDialog> {
  late AppUser _selected = widget.officers.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Field Officer'),
      content: DropdownButtonFormField<AppUser>(
        initialValue: _selected,
        decoration: const InputDecoration(labelText: 'Field Officer'),
        items: [
          for (final officer in widget.officers)
            DropdownMenuItem(value: officer, child: Text(officer.displayName ?? officer.email)),
        ],
        onChanged: (officer) => setState(() => _selected = officer ?? _selected),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
