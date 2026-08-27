import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geofence_utils.dart';
import '../../models/app_user.dart';
import '../../models/geofence.dart';
import '../../models/inspection.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';

/// Analyst can edit the suggested radius up to this cap (see
/// core/geofence_utils.dart's radiusMetersForSeverity for the default
/// per-severity lookup this pre-fills from).
const _maxManualRadiusMeters = 20000.0;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  InspectionTaskStatus? _filter;

  Future<void> _flagZone() async {
    final appState = context.read<AppState>();
    final zones = await appState.riskRepository.getRiskZones();
    final officers = await appState.authRepository.watchEnabledFieldOfficers().first;
    if (!mounted) return;

    if (officers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved Field Officer accounts yet — approve one under Pending Accounts first.'),
        ),
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _FlagZoneDialog(zones: zones, officers: officers),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _flagZone,
        icon: const Icon(Icons.flag),
        label: const Text('Flag Zone'),
      ),
      body: StreamBuilder<List<InspectionTask>>(
        stream: appState.taskRepository.watchAllTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = _filter == null
              ? snapshot.data!
              : snapshot.data!.where((t) => t.status == _filter).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final status in InspectionTaskStatus.values) ...[
                      ChoiceChip(
                        label: Text(status.label),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('No tasks match this filter.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => _TaskTile(task: tasks[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final InspectionTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RiskBadge(level: task.riskLevel),
                const Spacer(),
                TaskStatusChip(status: task.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.reason, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Assigned to: ${task.assignedOfficerUid ?? 'Unassigned'}'),
            Text(
              task.assignmentType == AssignmentType.manual
                  ? 'Manually assigned by: ${task.assignedBy ?? 'unknown'}'
                  : 'Automatically assigned',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            Text(
              'Geofence: ${task.geofence.radiusMeters.toStringAsFixed(0)}m radius '
              '(${task.geofenceStatus == GeofenceStatus.active ? 'active' : 'inactive'})',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            Text(
              'Lat ${task.lat.toStringAsFixed(4)}, Lng ${task.lng.toStringAsFixed(4)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            if (task.linkedReportId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Linked report: ${task.linkedReportId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (task.status == InspectionTaskStatus.completed)
              _InspectionVerificationBadge(task: task),
          ],
        ),
      ),
    );
  }
}

/// Once a task is completed, look up its (single) submitted inspection and
/// flag whether the officer's GPS at submission time actually fell inside
/// the geofence — this is the client-side check from
/// InspectionRepository.submitInspection, surfaced here for analyst review
/// per the design's "review carefully if unverified" requirement.
class _InspectionVerificationBadge extends StatelessWidget {
  final InspectionTask task;

  const _InspectionVerificationBadge({required this.task});

  @override
  Widget build(BuildContext context) {
    final officerUid = task.assignedOfficerUid;
    if (officerUid == null) return const SizedBox.shrink();

    final appState = context.read<AppState>();
    return StreamBuilder<List<FieldInspection>>(
      stream: appState.inspectionRepository.watchMyInspections(officerUid),
      builder: (context, snapshot) {
        final inspections = snapshot.data ?? const <FieldInspection>[];
        FieldInspection? match;
        for (final inspection in inspections) {
          if (inspection.taskId == task.id) {
            match = inspection;
            break;
          }
        }
        if (match == null) return const SizedBox.shrink();

        if (match.locationVerifiedAtSubmission) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Location verified at submission', style: TextStyle(color: Color(0xFF2E7D32))),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Location not verified at submission — review carefully',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlagZoneDialog extends StatefulWidget {
  final List<RiskZone> zones;
  final List<AppUser> officers;

  const _FlagZoneDialog({required this.zones, required this.officers});

  @override
  State<_FlagZoneDialog> createState() => _FlagZoneDialogState();
}

class _FlagZoneDialogState extends State<_FlagZoneDialog> {
  RiskZone? _selectedZone;
  late AppUser _selectedOfficer = widget.officers.first;
  late final TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) _selectedZone = widget.zones.first;
    _radiusController = TextEditingController(
      text: radiusMetersForSeverity(_selectedZone?.level ?? RiskLevel.low).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  void _onZoneChanged(RiskZone? zone) {
    setState(() {
      _selectedZone = zone;
      // Re-suggest the radius for the newly picked zone's severity — the
      // analyst can still edit it afterwards.
      _radiusController.text = radiusMetersForSeverity(zone?.level ?? RiskLevel.low).toStringAsFixed(0);
    });
  }

  Future<void> _submit() async {
    final zone = _selectedZone;
    if (zone == null) return;

    final radiusMeters = double.tryParse(_radiusController.text);
    if (radiusMeters == null || radiusMeters <= 0) return;

    final appState = context.read<AppState>();
    await appState.taskRepository.createTask(
      InspectionTask(
        id: '',
        assignedOfficerUid: _selectedOfficer.uid,
        lat: zone.lat,
        lng: zone.lng,
        riskLevel: zone.level,
        reason: 'AI/susceptibility flagged — manual review requested by analyst',
        instructions:
            'Inspect ${zone.name}. This task was flagged directly from the risk map, '
            'not from a citizen report — confirm current ground conditions.',
        status: InspectionTaskStatus.assigned,
        createdAt: DateTime.now(),
        geofence: Geofence.circle(
          centerLat: zone.lat,
          centerLng: zone.lng,
          radiusMeters: radiusMeters.clamp(1, _maxManualRadiusMeters),
        ),
        assignmentType: AssignmentType.manual,
        assignedBy: appState.uid,
      ),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final zone = _selectedZone;

    return AlertDialog(
      title: const Text('Flag Zone for Inspection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<RiskZone>(
              initialValue: _selectedZone,
              decoration: const InputDecoration(labelText: 'Risk zone'),
              items: [
                for (final z in widget.zones)
                  DropdownMenuItem(value: z, child: Text('${z.name} (${z.level.label})')),
              ],
              onChanged: _onZoneChanged,
            ),
            if (zone != null) ...[
              const SizedBox(height: 8),
              Text(
                'Center: ${zone.lat.toStringAsFixed(4)}, ${zone.lng.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Geofence radius (m)',
                helperText: 'Suggested from risk severity — editable up to '
                    '${_maxManualRadiusMeters.toStringAsFixed(0)}m',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppUser>(
              initialValue: _selectedOfficer,
              decoration: const InputDecoration(labelText: 'Field Officer'),
              items: [
                for (final officer in widget.officers)
                  DropdownMenuItem(
                    value: officer,
                    child: Text(officer.displayName ?? officer.email),
                  ),
              ],
              onChanged: (officer) => setState(() => _selectedOfficer = officer ?? _selectedOfficer),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create Task')),
      ],
    );
  }
}
