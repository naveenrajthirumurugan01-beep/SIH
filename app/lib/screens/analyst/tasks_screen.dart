import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/risk_zone.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';

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
    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _FlagZoneDialog(zones: zones),
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
            Text('Assigned to: ${task.assignedOfficerUid}'),
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
          ],
        ),
      ),
    );
  }
}

class _FlagZoneDialog extends StatefulWidget {
  final List<RiskZone> zones;

  const _FlagZoneDialog({required this.zones});

  @override
  State<_FlagZoneDialog> createState() => _FlagZoneDialogState();
}

class _FlagZoneDialogState extends State<_FlagZoneDialog> {
  RiskZone? _selectedZone;
  final _idController = TextEditingController(text: demoOfficerUid);
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) _selectedZone = widget.zones.first;
  }

  Future<void> _submit() async {
    final zone = _selectedZone;
    if (zone == null || _idController.text.trim().isEmpty) return;

    final appState = context.read<AppState>();
    await appState.taskRepository.createTask(
      InspectionTask(
        id: '',
        assignedOfficerUid: _idController.text.trim(),
        lat: zone.lat,
        lng: zone.lng,
        riskLevel: zone.level,
        reason: 'AI/susceptibility flagged — manual review requested by analyst',
        instructions:
            'Inspect ${zone.name}. This task was flagged directly from the risk map, '
            'not from a citizen report — confirm current ground conditions.',
        status: InspectionTaskStatus.assigned,
        createdAt: DateTime.now(),
      ),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Flag Zone for Inspection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<RiskZone>(
            initialValue: _selectedZone,
            decoration: const InputDecoration(labelText: 'Risk zone'),
            items: [
              for (final zone in widget.zones)
                DropdownMenuItem(value: zone, child: Text('${zone.name} (${zone.level.label})')),
            ],
            onChanged: (zone) => setState(() => _selectedZone = zone),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Officer Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: 'Officer ID',
              helperText: 'Keep "demo_officer" to route to the demo Field Officer',
            ),
          ),
        ],
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
