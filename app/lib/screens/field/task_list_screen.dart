import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/task.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/task_status_chip.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => appState.authRepository.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<InspectionTask>>(
        stream: appState.taskRepository.watchTasksForOfficer(appState.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tasks assigned.', textAlign: TextAlign.center),
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
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
        ),
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
              Text(task.reason, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Lat ${task.lat.toStringAsFixed(4)}, Lng ${task.lng.toStringAsFixed(4)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
