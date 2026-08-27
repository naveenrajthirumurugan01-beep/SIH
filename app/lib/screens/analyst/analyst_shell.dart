import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/responsive.dart';
import '../../models/risk_zone.dart';
import 'activity_log_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'environmental_monitoring_screen.dart';
import 'field_officer_tracking_screen.dart';
import 'reports_queue_screen.dart';
import 'risk_map_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

enum _AnalystSection {
  dashboard(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  riskMap(Icons.map_outlined, Icons.map, 'Risk Map'),
  inspections(Icons.assignment_outlined, Icons.assignment, 'Inspections'),
  fieldOfficers(Icons.groups_outlined, Icons.groups, 'Field Officers'),
  environmental(Icons.sensors_outlined, Icons.sensors, 'Environmental'),
  alerts(Icons.campaign_outlined, Icons.campaign, 'Alerts'),
  reports(Icons.inbox_outlined, Icons.inbox, 'Reports'),
  activityLog(Icons.history_outlined, Icons.history, 'Activity Log'),
  settings(Icons.settings_outlined, Icons.settings, 'Settings');

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _AnalystSection(this.icon, this.selectedIcon, this.label);
}

/// Sidebar-based shell for the Analyst / control-room web dashboard. Every
/// destination is wired to real data (no stub pages left — see Phase 3
/// polish pass). Historical Landslides and the GIS layer panel live inside
/// Risk Map (a toggleable layer/panel there) rather than as separate
/// sidebar destinations — see risk_map_screen.dart.
class AnalystShell extends StatefulWidget {
  const AnalystShell({super.key});

  @override
  State<AnalystShell> createState() => _AnalystShellState();
}

class _AnalystShellState extends State<AnalystShell> {
  _AnalystSection _section = _AnalystSection.dashboard;
  RiskLevel? _riskMapFilter;

  void _goTo(_AnalystSection section, {RiskLevel? riskMapFilter}) {
    setState(() {
      _section = section;
      _riskMapFilter = riskMapFilter;
    });
  }

  Widget _buildContent() {
    switch (_section) {
      case _AnalystSection.dashboard:
        return AnalystDashboardScreen(
          onOpenReportsQueue: () => _goTo(_AnalystSection.reports),
          onOpenRiskMap: ({severityFilter}) =>
              _goTo(_AnalystSection.riskMap, riskMapFilter: severityFilter),
          onOpenAlerts: () => _goTo(_AnalystSection.alerts),
          onOpenInspections: () => _goTo(_AnalystSection.inspections),
        );
      case _AnalystSection.riskMap:
        return RiskMapScreen(initialSeverityFilter: _riskMapFilter);
      case _AnalystSection.inspections:
        return const TasksScreen();
      case _AnalystSection.fieldOfficers:
        return const FieldOfficerTrackingScreen();
      case _AnalystSection.environmental:
        return const EnvironmentalMonitoringScreen();
      case _AnalystSection.alerts:
        return const AnalystAlertsScreen();
      case _AnalystSection.reports:
        return const ReportsQueueScreen();
      case _AnalystSection.activityLog:
        return const ActivityLogScreen();
      case _AnalystSection.settings:
        return const AnalystSettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.mobile > MediaQuery.of(context).size.width;

    if (isMobile) {
      final appState = context.watch<AppState>();
      final user = appState.currentUser;

      return Scaffold(
        appBar: AppBar(
          title: Text(_section.label),
          leading: const Icon(Icons.terrain),
          actions: [
            PopupMenuButton<_AnalystSection>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Navigation Menu',
              onSelected: (section) => _goTo(section),
              itemBuilder: (context) => [
                for (final section in _AnalystSection.values)
                  PopupMenuItem(
                    value: section,
                    child: Row(
                      children: [
                        Icon(
                          _section == section ? section.selectedIcon : section.icon,
                          color: _section == section ? Theme.of(context).colorScheme.primary : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          section.label,
                          style: TextStyle(
                            fontWeight: _section == section ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Account',
              onSelected: (value) {
                if (value == 'signout') signOutToRoleSelect(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(user?.displayName ?? user?.email ?? 'Analyst'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
            ),
          ],
        ),
        body: _buildContent(),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Column(
        children: [
          const _AnalystHeader(),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  extended: isWide,
                  minExtendedWidth: 200,
                  selectedIndex: _section.index,
                  onDestinationSelected: (i) => _goTo(_AnalystSection.values[i]),
                  labelType: isWide ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
                  destinations: [
                    for (final section in _AnalystSection.values)
                      NavigationRailDestination(
                        icon: Icon(section.icon),
                        selectedIcon: Icon(section.selectedIcon),
                        label: Text(section.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalystHeader extends StatelessWidget {
  const _AnalystHeader();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.terrain),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dibang Valley', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'Landslide Risk Monitoring System',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const Spacer(),
            // Search bar and live rainfall readout are stubbed out for this
            // pass — see the Analyst dashboard build task's scope.
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: null,
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (value) {
                if (value == 'signout') signOutToRoleSelect(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(user?.displayName ?? user?.email ?? 'Analyst'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Analyst',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Role: Analyst',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
