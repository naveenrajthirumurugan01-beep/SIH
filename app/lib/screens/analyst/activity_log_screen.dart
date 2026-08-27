import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../widgets/async_state_views.dart';

/// Recent Analyst actions taken this session — Assign/Reassign,
/// Acknowledge/Escalate/Resolve, Verify/Reject, etc. Backed by
/// AppState.activityLog, an in-memory list (see its doc comment for why
/// this isn't persisted to Firestore). Purely additive/read-only: there is
/// nothing to load over the network, so the only states are empty vs.
/// populated — no loading/error state applies here.
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().activityLog;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: entries.isEmpty
          ? const EmptyStateView(
              icon: Icons.history,
              message: 'No actions taken yet this session.\n'
                  'Assign a task, or respond to an alert or report, and it will show up here.',
            )
          : ListView.separated(
              padding: EdgeInsets.all(context.isMobile ? 12 : 16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(entry.message),
                    subtitle: Text(DateFormat('d MMM y, HH:mm:ss').format(entry.timestamp)),
                  ),
                );
              },
            ),
    );
  }
}
