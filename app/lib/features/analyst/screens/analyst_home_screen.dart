import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/role_scaffold.dart';

/// Analyst/Admin home: full GIS risk heatmap across all districts, report
/// moderation queue, road connectivity overview, alert triggers/overrides,
/// and emergency-response prioritization.
class AnalystHomeScreen extends StatelessWidget {
  const AnalystHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Analyst Dashboard',
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          _DashboardTile(
            icon: Icons.map,
            label: 'Full Risk Heatmap',
            onTap: () => context.push(AppRoutes.riskMap),
          ),
          _DashboardTile(
            icon: Icons.fact_check,
            label: 'Review Reports',
            onTap: () => context.push(AppRoutes.reportsList),
          ),
          // TODO: emergency-response prioritization view — ranks districts
          // by risk score x population/road-access impact.
          const _DashboardTile(
            icon: Icons.priority_high,
            label: 'Emergency Priorities',
            enabled: false,
          ),
          // TODO: road connectivity status board across all districts.
          const _DashboardTile(
            icon: Icons.alt_route,
            label: 'Road Connectivity',
            enabled: false,
          ),
          // TODO: manual alert trigger/override screen -> POST /alerts/trigger.
          const _DashboardTile(
            icon: Icons.campaign,
            label: 'Trigger Alert',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _DashboardTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
