import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../models/inspection.dart';
import '../../../models/task.dart';
import '../../../screens/field/task_detail_screen.dart';
import '../../../widgets/risk_badge.dart';
import '../../../widgets/task_status_chip.dart';

/// Operational Dashboard for Field Officers.
/// Primary Focus: "WHAT INSPECTION DO I NEED TO DO?"
/// Displays: Officer Profile, Operational Counts (Assigned, Pending, Completed),
/// and the primary Active Inspection Action Card.
class FieldOfficerDashboardScreen extends StatelessWidget {
  const FieldOfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    final officerName = user?.displayName ?? user?.email ?? 'Field Officer';
    final officerUid = appState.uid;

    return StreamBuilder<List<InspectionTask>>(
      stream: appState.taskRepository.watchTasksForOfficer(officerUid),
      builder: (context, taskSnapshot) {
        return StreamBuilder<List<FieldInspection>>(
          stream: appState.inspectionRepository.watchMyInspections(officerUid),
          builder: (context, inspectionSnapshot) {
            final tasks = taskSnapshot.data ?? [];
            final submittedInspections = inspectionSnapshot.data ?? [];

            // Calculate operational counters
            final assignedCount = tasks.length;
            final pendingTasks = tasks.where((t) =>
                t.status == InspectionTaskStatus.assigned ||
                t.status == InspectionTaskStatus.enRoute ||
                t.status == InspectionTaskStatus.onSite).toList();
            final pendingCount = pendingTasks.length;

            final completedTasksCount = tasks
                .where((t) => t.status == InspectionTaskStatus.completed)
                .length;
            final totalCompletedCount = completedTasksCount > submittedInspections.length
                ? completedTasksCount
                : submittedInspections.length;

            // Identify active/next priority inspection task
            final activeTask = pendingTasks.isNotEmpty ? pendingTasks.first : null;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Officer Profile Header Card
                _buildOfficerHeaderCard(
                  context,
                  officerName: officerName,
                  district: 'Dibang Valley',
                ),
                const SizedBox(height: 16),

                // 2. Operational Metrics Cards Grid
                _buildMetricsRow(
                  context,
                  assignedCount: assignedCount,
                  pendingCount: pendingCount,
                  completedCount: totalCompletedCount,
                ),
                const SizedBox(height: 24),

                // 3. Primary Purpose Section: "WHAT INSPECTION DO I NEED TO DO?"
                Text(
                  'WHAT INSPECTION DO I NEED TO DO?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),

                _buildActiveInspectionCard(context, activeTask: activeTask),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOfficerHeaderCard(
    BuildContext context, {
    required String officerName,
    required String district,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.badge_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    district,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Status: Active — On Duty',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context, {
    required int assignedCount,
    required int pendingCount,
    required int completedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Assigned',
            value: '$assignedCount',
            icon: Icons.assignment_outlined,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Pending',
            value: '$pendingCount',
            icon: Icons.pending_actions_outlined,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Completed',
            value: '$completedCount',
            icon: Icons.task_alt_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveInspectionCard(BuildContext context, {required InspectionTask? activeTask}) {
    if (activeTask == null) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF2E7D32)),
              const SizedBox(height: 12),
              Text(
                'No Pending Inspections',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'You have no assigned inspection tasks requiring immediate action at this time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RiskBadge(level: activeTask.riskLevel),
                const Spacer(),
                TaskStatusChip(status: activeTask.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              activeTask.reason,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Lat ${activeTask.lat.toStringAsFixed(4)}, Lng ${activeTask.lng.toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activeTask.instructions,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(task: activeTask),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  'OPEN ACTIVE INSPECTION TASK',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
