import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geofence_utils.dart';
import '../../core/responsive.dart';
import '../../models/app_user.dart';
import '../../models/geofence.dart';
import '../../models/inspection.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';

/// Analyst can edit the suggested radius up to this cap (see
/// core/geofence_utils.dart's radiusMetersForSeverity for the default
/// per-severity lookup this pre-fills from).
const _maxManualRadiusMeters = 20000.0;

/// Tasks it still makes sense to (re)assign — a completed or cancelled
/// task is a closed record, not open work, so it's excluded from the
/// "Assign Field Officer" picker and the per-tile Assign/Reassign button.
const _assignableStatuses = {
  InspectionTaskStatus.unassigned,
  InspectionTaskStatus.notified,
  InspectionTaskStatus.assigned,
  InspectionTaskStatus.enRoute,
  InspectionTaskStatus.onSite,
};

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

  /// Opens the "Assign Field Officer" flow — pass [preselectedTask] when
  /// reached from a specific tile's Assign/Reassign button, or leave it
  /// null for the top-level button, where the analyst picks the task too.
  Future<void> _openAssignDialog({InspectionTask? preselectedTask}) async {
    final appState = context.read<AppState>();
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

    final allTasks = await appState.taskRepository.watchAllTasks().first;
    final assignable = allTasks.where((t) => _assignableStatuses.contains(t.status)).toList();
    if (!mounted) return;

    if (assignable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open inspection tasks to assign — flag a zone to create one.')),
      );
      return;
    }

    // InspectionTask has no value equality, so a task tile's own copy
    // (from the screen's live StreamBuilder) is never `identical()` to
    // the matching entry in this dialog's freshly-fetched `assignable`
    // list — resolve by id so the dropdown's initialValue actually
    // matches one of its items instead of silently showing nothing.
    InspectionTask? initialTask;
    if (preselectedTask != null) {
      for (final t in assignable) {
        if (t.id == preselectedTask.id) {
          initialTask = t;
          break;
        }
      }
    }

    final assignedOfficerLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AssignFieldOfficerDialog(
        officers: officers,
        tasks: assignable,
        initialTask: initialTask,
      ),
    );

    if (assignedOfficerLabel != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to $assignedOfficerLabel.')),
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
          if (snapshot.hasError) {
            return ErrorStateView(
              message: 'Could not load inspection tasks: ${snapshot.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final tasks = _filter == null
              ? snapshot.data!
              : snapshot.data!.where((t) => t.status == _filter).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 12 : 16, vertical: 8),
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
              Padding(
                padding: EdgeInsets.fromLTRB(context.isMobile ? 12 : 16, 0, context.isMobile ? 12 : 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _openAssignDialog(),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Assign Field Officer'),
                  ),
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? EmptyStateView(
                        icon: Icons.assignment_outlined,
                        message: _filter == null
                            ? 'No inspection tasks yet.\nFlag a zone or assign a Field Officer to create one.'
                            : 'No ${_filter!.label.toLowerCase()} tasks right now.',
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          context.isMobile ? 12 : 16,
                          0,
                          context.isMobile ? 12 : 16,
                          16,
                        ),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => _TaskTile(
                          task: tasks[index],
                          onAssign: () => _openAssignDialog(preselectedTask: tasks[index]),
                        ),
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
  final VoidCallback onAssign;

  const _TaskTile({required this.task, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final canAssign = _assignableStatuses.contains(task.status);

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
            Text('Task ID: ${task.id}'),
            Text('Assigned to: ${task.assignedOfficerUid ?? 'Unassigned'}'),
            Text(
              task.assignmentType == AssignmentType.manual
                  ? (task.assignedBy != null
                      ? 'Manually assigned by: ${task.assignedBy}'
                      : 'Manual review requested — not yet assigned')
                  : 'Automatically assigned',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            if (task.assignedAt != null || task.dueDate != null)
              Text(
                [
                  if (task.assignedAt != null)
                    'Assigned: ${DateFormat('d MMM y').format(task.assignedAt!)}',
                  if (task.dueDate != null)
                    'Due: ${DateFormat('d MMM y').format(task.dueDate!)}',
                ].join(' · '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            if (task.status == InspectionTaskStatus.notified)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Notified ${DateFormat('d MMM y, HH:mm').format(task.createdAt)} — '
                  'awaiting Field Officer response',
                  style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12),
                ),
              )
            else if (task.acceptedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Accepted: ${DateFormat('d MMM y, HH:mm').format(task.acceptedAt!)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
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
              _CompletedInspectionSection(task: task),
            if (canAssign) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(task.assignedOfficerUid == null ? 'Assign' : 'Reassign'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Once a task is completed, look up its (single) submitted inspection and
/// show what the field officer actually reported — crack/slope/rockfall/
/// water-seepage/road-condition findings, notes, and photo count — behind
/// an expandable section, plus a badge flagging whether the officer's GPS
/// at submission time actually fell inside the geofence (the client-side
/// check from InspectionRepository.submitInspection). Previously only the
/// badge was shown; the rest of FieldInspection's data was captured but
/// never surfaced anywhere in the Analyst UI.
class _CompletedInspectionSection extends StatelessWidget {
  final InspectionTask task;

  const _CompletedInspectionSection({required this.task});

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
        final inspection = match;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VerificationBadge(verified: inspection.locationVerifiedAtSubmission),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Field officer findings',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    _FindingRow(label: 'Crack status', value: inspection.crackStatus.label),
                    _FindingRow(label: 'Slope movement', value: inspection.slopeMovement.label),
                    _FindingRow(
                      label: 'Rockfall observed',
                      value: inspection.rockfall ? 'Yes' : 'No',
                    ),
                    _FindingRow(
                      label: 'Water seepage',
                      value: inspection.waterSeepage ? 'Yes' : 'No',
                    ),
                    _FindingRow(label: 'Road condition', value: inspection.roadCondition.label),
                    _FindingRow(
                      label: 'Submitted',
                      value: DateFormat('d MMM y, HH:mm').format(inspection.submittedAt),
                    ),
                    _FindingRow(
                      label: 'Photos',
                      value: inspection.photoUrls.isEmpty
                          ? 'None attached'
                          : '${inspection.photoUrls.length} attached',
                    ),
                    if (inspection.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Notes', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(inspection.notes, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool verified;

  const _VerificationBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    if (verified) {
      return const Text(
        'Location verified at submission',
        style: TextStyle(color: Color(0xFF2E7D32)),
      );
    }
    return Container(
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
    );
  }
}

class _FindingRow extends StatelessWidget {
  final String label;
  final String value;

  const _FindingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual "Assign Field Officer" flow (Inspection Page). Distinct from
/// [_FlagZoneDialog]: that one creates a brand-new task from a risk zone,
/// this one (re)assigns an existing task — one already on the board,
/// whether unassigned or currently held by a different officer — to the
/// selected Field Officer.
class _AssignFieldOfficerDialog extends StatefulWidget {
  final List<AppUser> officers;
  final List<InspectionTask> tasks;

  /// Pre-selects a task when opened from that task's own Assign/Reassign
  /// button; null when opened from the page-level button, where the
  /// analyst picks the task too. Must be one of the elements of [tasks]
  /// for the dropdown to show it selected — see _openAssignDialog.
  final InspectionTask? initialTask;

  const _AssignFieldOfficerDialog({
    required this.officers,
    required this.tasks,
    this.initialTask,
  });

  @override
  State<_AssignFieldOfficerDialog> createState() => _AssignFieldOfficerDialogState();
}

class _AssignFieldOfficerDialogState extends State<_AssignFieldOfficerDialog> {
  late InspectionTask _selectedTask;
  late AppUser _selectedOfficer;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialTask ?? widget.tasks.first;
    _selectedOfficer = _officerFor(_selectedTask.assignedOfficerUid) ?? widget.officers.first;
    _dueDate = DateTime.now().add(const Duration(days: 3));
  }

  AppUser? _officerFor(String? uid) {
    if (uid == null) return null;
    for (final officer in widget.officers) {
      if (officer.uid == uid) return officer;
    }
    return null;
  }

  void _onTaskChanged(InspectionTask? task) {
    if (task == null) return;
    setState(() {
      _selectedTask = task;
      _selectedOfficer = _officerFor(task.assignedOfficerUid) ?? _selectedOfficer;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final appState = context.read<AppState>();
      await appState.taskRepository.assignTask(
        _selectedTask.id,
        officerUid: _selectedOfficer.uid,
        assignedBy: appState.uid,
        dueDate: _dueDate,
      );
      final officerLabel = _selectedOfficer.displayName ?? _selectedOfficer.email;
      appState.recordActivity('Assigned task "${_selectedTask.reason}" to $officerLabel');
      if (mounted) {
        Navigator.of(context).pop(officerLabel);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _selectedTask;
    final currentOfficer = _officerFor(task.assignedOfficerUid);
    final isReassign = currentOfficer != null && currentOfficer.uid != _selectedOfficer.uid;

    return AlertDialog(
      title: const Text('Assign Field Officer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<InspectionTask>(
              initialValue: _selectedTask,
              decoration: const InputDecoration(labelText: 'Inspection / task'),
              items: [
                for (final t in widget.tasks)
                  DropdownMenuItem(
                    value: t,
                    child: Text('${t.reason} (${t.status.label})', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _onTaskChanged,
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Task ID', value: task.id),
            _DetailRow(
              label: 'Location',
              value: '${task.lat.toStringAsFixed(4)}, ${task.lng.toStringAsFixed(4)}',
            ),
            _DetailRow(label: 'Priority', value: task.riskLevel.label),
            _DetailRow(
              label: 'Assigned date',
              value: task.assignedAt == null
                  ? 'Not yet assigned'
                  : DateFormat('d MMM y').format(task.assignedAt!),
            ),
            if (currentOfficer != null)
              _DetailRow(
                label: 'Currently assigned to',
                value: currentOfficer.displayName ?? currentOfficer.email,
              ),
            const SizedBox(height: 8),
            Text('Task description', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(task.instructions.isEmpty ? task.reason : task.instructions),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppUser>(
              initialValue: _selectedOfficer,
              decoration: const InputDecoration(labelText: 'Field Officer'),
              items: [
                for (final officer in widget.officers)
                  DropdownMenuItem(value: officer, child: Text(officer.displayName ?? officer.email)),
              ],
              onChanged: (officer) => setState(() => _selectedOfficer = officer ?? _selectedOfficer),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due date'),
                child: Text(_dueDate == null ? 'Not set' : DateFormat('d MMM y').format(_dueDate!)),
              ),
            ),
            if (isReassign) ...[
              const SizedBox(height: 12),
              Text(
                'This reassigns the task away from ${currentOfficer.displayName ?? currentOfficer.email} '
                'to ${_selectedOfficer.displayName ?? _selectedOfficer.email}.',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Assign'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
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
    appState.recordActivity(
      'Flagged ${zone.name} for inspection, assigned to '
      '${_selectedOfficer.displayName ?? _selectedOfficer.email}',
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
