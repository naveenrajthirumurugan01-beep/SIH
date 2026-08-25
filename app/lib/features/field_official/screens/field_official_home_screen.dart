import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/role_scaffold.dart';

/// Field Official home: same reporting ability as citizens, but their
/// reports carry a higher trust_weight (see backend/app/services/report_service.py),
/// plus the ability to update road connectivity status.
class FieldOfficialHomeScreen extends StatelessWidget {
  const FieldOfficialHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Field Official',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Risk Map'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.riskMap),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Submit Field Report'),
              subtitle: const Text('Weighted higher than citizen reports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.reportSubmit),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('All Reports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.reportsList),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Alerts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.alerts),
            ),
          ),
          // TODO: road status update list — for each road in the official's
          // district, a control to set clear / partially_open / blocked.
          Card(
            child: ListTile(
              leading: const Icon(Icons.alt_route),
              title: const Text('Update Road Status'),
              subtitle: const Text('TODO: road list + status picker'),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
