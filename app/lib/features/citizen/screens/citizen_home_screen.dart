import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/role_scaffold.dart';

/// Citizen home: view risk map for their area, receive push/SMS alerts,
/// and submit geo-tagged reports. Detail level on the risk map is lower
/// than the analyst view (TODO: filter payload fields client-side or via
/// a query param once the backend distinguishes detail tiers).
class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'My Area',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Risk Map'),
              subtitle: const Text('View landslide risk for your district'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.riskMap),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report an Issue'),
              subtitle: const Text('Cracks, slope movement, blocked roads'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.reportSubmit),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('My Reports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.reportsList),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Alerts'),
              subtitle: const Text('Push and SMS alert history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.alerts),
            ),
          ),
        ],
      ),
    );
  }
}
