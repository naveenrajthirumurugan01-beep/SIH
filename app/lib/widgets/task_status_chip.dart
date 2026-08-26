import 'package:flutter/material.dart';

import '../models/task.dart';

/// Shared with the Analyst dashboard's task-pin map layer, so a task's
/// color means the same thing everywhere it appears.
Color colorForTaskStatus(InspectionTaskStatus status) => switch (status) {
      InspectionTaskStatus.assigned => Colors.blueGrey,
      InspectionTaskStatus.enRoute => const Color(0xFFF9A825),
      InspectionTaskStatus.onSite => const Color(0xFFEF6C00),
      InspectionTaskStatus.completed => const Color(0xFF2E7D32),
      InspectionTaskStatus.cancelled => const Color(0xFFC62828),
    };

/// Color-coded chip for an [InspectionTaskStatus], used across the Field
/// Officer task list/detail screens.
class TaskStatusChip extends StatelessWidget {
  final InspectionTaskStatus status;

  const TaskStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = colorForTaskStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(
        status.label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
