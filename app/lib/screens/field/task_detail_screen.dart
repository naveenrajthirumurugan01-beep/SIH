import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
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
  /// Tracked locally (not just read off [widget.task]) so accepting the
  /// task updates this screen immediately instead of waiting for the
  /// officer to back out to the live-streamed task list.
  late InspectionTaskStatus _status = widget.task.status;

  InspectionTask get _task => widget.task.copyWith(status: _status);

  Future<void> _accept() async {
    final appState = context.read<AppState>();
    await appState.taskRepository.acceptTask(widget.task.id);
    if (!mounted) return;
    setState(() => _status = InspectionTaskStatus.assigned);
  }

  Future<void> _openMaps() async {
    final task = widget.task;
    final geoUri = Uri.parse(
      'geo:${task.lat},${task.lng}?q=${task.lat},${task.lng}',
    );
    final launched = await launchUrl(
      geoUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) return;

    // Fallback for platforms without a geo: URI handler (desktop/web).
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${task.lat},${task.lng}',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _startInspection() async {
    final appState = context.read<AppState>();
    await appState.taskRepository.updateTaskStatus(
      widget.task.id,
      InspectionTaskStatus.enRoute,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeofenceCheckScreen(
          task: _task.copyWith(status: InspectionTaskStatus.enRoute),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final isPending = task.status == InspectionTaskStatus.notified;
    final canStart = task.status == InspectionTaskStatus.assigned ||
        task.status == InspectionTaskStatus.enRoute ||
        task.status == InspectionTaskStatus.onSite;

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: ListView(
        padding: ResponsivePadding.defaultPadding(context),
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
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(task.instructions),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(
                    'Lat ${task.lat.toStringAsFixed(5)}, Lng ${task.lng.toStringAsFixed(5)}',
                  ),
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
              if (isPending) ...[
                FilledButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Task'),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: canStart ? _startInspection : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  task.status == InspectionTaskStatus.completed
                      ? 'Inspection Completed'
                      : isPending
                          ? 'Accept task to begin'
                          : 'Start Inspection',
                ),
          ),
        ],
      ),
    );
  }
}
