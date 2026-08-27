import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final authProvider = context.watch<AuthProvider>();
    final officerUid = authProvider.profile?.uid ?? appState.officerId ?? demoOfficerUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Tasks'),
      ),
      body: StreamBuilder<List<InspectionTask>>(
        stream: appState.taskRepository.watchTasksForOfficer(officerUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No inspection tasks assigned to your officer account.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final InspectionTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, y • HH:mm').format(task.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Risk Level + Priority Badge + Status Chip
              Row(
                children: [
                  RiskBadge(level: task.riskLevel),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      'Priority: ${task.priority}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TaskStatusChip(status: task.status),
                ],
              ),
              const SizedBox(height: 10),

              // Title / Trigger Reason
              Text(
                task.reason,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),

              // Assignment IDs & Zone Info
              Row(
                children: [
                  Icon(Icons.qr_code, size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${task.id}  •  Zone: ${task.riskZoneId}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Location & Geofence
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${task.locationName} (${task.lat.toStringAsFixed(4)}, ${task.lng.toStringAsFixed(4)})  •  Radius: ${task.geofenceRadiusMeters.toStringAsFixed(0)}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer: Assigned By & Assigned Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assigned by: ${task.assignedBy}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
