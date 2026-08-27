import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../models/app_user.dart';
import '../../models/task.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';
import 'task_detail_screen.dart';

/// The Field Officer's first/main screen: a welcome header identifying the
/// signed-in officer (name + real Firestore uid, never hardcoded) above the
/// live list of tasks assigned to them.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Officer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => appState.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<InspectionTask>>(
        stream: appState.taskRepository.watchTasksForOfficer(appState.uid),
        builder: (context, snapshot) {
          final tasks = snapshot.data;
          final notifiedCount =
              tasks?.where((t) => t.status == InspectionTaskStatus.notified).length ?? 0;

          return ListView(
            padding: ResponsivePadding.defaultPadding(context),
            children: [
              _DashboardHeader(user: user),
              if (notifiedCount > 0) ...[
                const SizedBox(height: 16),
                _NotificationBanner(count: notifiedCount),
              ],
              const SizedBox(height: 24),
              Text(
                'Assigned Inspections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (tasks == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No assignments yet',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...tasks.map((task) => _TaskCard(task: task)),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final AppUser? user;

  const _DashboardHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? 'Field Officer');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Field Officer ID: ${user?.uid ?? '-'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown at the top of the task list when one or more tasks are
/// still awaiting the officer's Accept — see [_TaskCard]'s own Accept
/// button below, which is what actually clears these.
class _NotificationBanner extends StatelessWidget {
  final int count;

  const _NotificationBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 new notification — a task needs your response'
                  : '$count new notifications — tasks need your response',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final InspectionTask task;

  const _TaskCard({required this.task});

  Future<void> _accept(BuildContext context) async {
    final appState = context.read<AppState>();
    await appState.taskRepository.acceptTask(task.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task accepted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = task.status == InspectionTaskStatus.notified;

    return Card(
      shape: isPending
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
            )
          : null,
      color: isPending
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
        borderRadius: BorderRadius.circular(12),
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
              Text(
                task.reason,
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 4),
              Text(
                'Lat ${task.lat.toStringAsFixed(4)}, Lng ${task.lng.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _accept(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
