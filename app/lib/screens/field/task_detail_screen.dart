import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../models/task.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';
import 'geofence_check_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final InspectionTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Future<void> _openMaps() async {
    final task = widget.task;
    final geoUri = Uri.parse('geo:${task.lat},${task.lng}?q=${task.lat},${task.lng}');
    final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    if (launched) return;

    // Fallback for platforms without a geo: URI handler (desktop/web).
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${task.lat},${task.lng}',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _startInspection() async {
    final appState = context.read<AppState>();
    await appState.taskRepository.updateTaskStatus(widget.task.id, InspectionTaskStatus.enRoute);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GeofenceCheckScreen(task: widget.task.copyWith(status: InspectionTaskStatus.enRoute)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final canStart = task.status != InspectionTaskStatus.completed &&
        task.status != InspectionTaskStatus.cancelled;

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              RiskBadge(level: task.riskLevel),
              const SizedBox(width: 8),
              const Spacer(),
              TaskStatusChip(status: task.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(task.reason, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Text('Instructions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(task.instructions),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: Text('Lat ${task.lat.toStringAsFixed(5)}, Lng ${task.lng.toStringAsFixed(5)}'),
              subtitle: Text(
                'A ${task.geofence.radiusMeters.toStringAsFixed(0)}m geofence around this point applies.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openMaps,
            icon: const Icon(Icons.map),
            label: const Text('Navigate'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canStart ? _startInspection : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              task.status == InspectionTaskStatus.completed
                  ? 'Inspection Completed'
                  : 'Start Inspection',
            ),
          ),
        ],
      ),
    );
  }
}
