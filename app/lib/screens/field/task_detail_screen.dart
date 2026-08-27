import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';
import '../../widgets/field_gps_status_card.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';

class TaskDetailScreen extends StatefulWidget {
  final InspectionTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late InspectionTask _currentTask;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  Future<void> _startInspection() async {
    final appState = context.read<AppState>();
    final authProvider = context.read<AuthProvider>();

    final currentOfficerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    // 1. Validation: Check if inspection is still valid
    if (_currentTask.status == InspectionTaskStatus.completed ||
        _currentTask.status == InspectionTaskStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot start: Inspection is already ${_currentTask.status.label}.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // 2. Validation: Check ownership against logged-in Field Officer
    final isAssignedToOfficer = _currentTask.assignedOfficerUid == currentOfficerUid ||
        _currentTask.assignedOfficerUid == demoOfficerUid;
    if (!isAssignedToOfficer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: This inspection task is not assigned to your officer account.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // 3. Update status in architecture repository (assigned -> enRoute)
      await appState.taskRepository.updateTaskStatus(
        _currentTask.id,
        InspectionTaskStatus.enRoute,
      );

      setState(() {
        _currentTask = _currentTask.copyWith(status: InspectionTaskStatus.enRoute);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inspection ${_currentTask.id} status updated to EN ROUTE.'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update inspection status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _currentTask;
    final formattedDate = DateFormat('MMMM d, y • HH:mm').format(task.createdAt);
    final canStart = task.status == InspectionTaskStatus.assigned;

    return Scaffold(
      appBar: AppBar(
        title: Text('Inspection Details — ${task.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Header Card: Risk Level, Priority, and Status
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RiskBadge(level: task.riskLevel),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          'Priority: ${task.priority}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TaskStatusChip(status: task.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    task.reason,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Metadata Section Card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASSIGNMENT METADATA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const Divider(height: 20),
                  _DetailRow(label: 'Inspection ID', value: task.id),
                  _DetailRow(label: 'Assigned Officer ID', value: task.assignedOfficerUid),
                  _DetailRow(label: 'Risk Zone ID', value: task.riskZoneId),
                  _DetailRow(label: 'Location Area', value: task.locationName),
                  _DetailRow(
                    label: 'GPS Target Coordinates',
                    value: '${task.lat.toStringAsFixed(5)}, ${task.lng.toStringAsFixed(5)}',
                  ),
                  _DetailRow(
                    label: 'Geofence Radius',
                    value: '${task.geofenceRadiusMeters.toStringAsFixed(0)} meters',
                  ),
                  _DetailRow(label: 'Assigned By', value: task.assignedBy),
                  _DetailRow(label: 'Assigned Timestamp', value: formattedDate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Live GPS Telemetry Card (Active Inspection)
          if (task.status == InspectionTaskStatus.enRoute || task.status == InspectionTaskStatus.onSite) ...[
            Text(
              'LIVE GPS SATELLITE TELEMETRY',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            const FieldGpsStatusCard(),
            const SizedBox(height: 16),
          ],

          // 4. Operational Instructions Card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIELD INSTRUCTIONS',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.instructions,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 4. Primary Action Button: [ START INSPECTION ]
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: (_isUpdating || !canStart) ? null : _startInspection,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                task.status == InspectionTaskStatus.enRoute
                    ? 'INSPECTION IN PROGRESS (EN ROUTE)'
                    : task.status == InspectionTaskStatus.completed
                        ? 'INSPECTION COMPLETED'
                        : 'START INSPECTION',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
