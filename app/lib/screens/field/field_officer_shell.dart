import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/responsive.dart';
import '../../features/field_official/screens/field_officer_dashboard_screen.dart';
import '../../services/field_officer_sync_service.dart';
import '../../widgets/field_sync_banner.dart';
import 'my_inspections_screen.dart';
import 'task_list_screen.dart';

/// Adaptive navigation shell for the three persistent Field Officer
/// destinations. Task detail / geofence check / inspection form are pushed
/// on top of this as a linear flow from a task list entry, not separate tabs.
///
/// This shell is the sole owner of the AppBar for all three tabs — the tab
/// screens themselves (TaskListScreen, MyInspectionsScreen,
/// FieldOfficerDashboardScreen) return bare content, not their own Scaffold,
/// so there's exactly one AppBar on screen at any width, not a shell-level
/// one stacked on top of each screen's own.
class FieldOfficerShell extends StatefulWidget {
  const FieldOfficerShell({super.key});

  @override
  State<FieldOfficerShell> createState() => _FieldOfficerShellState();
}

class _FieldOfficerShellState extends State<FieldOfficerShell> {
  int _index = 0;
  late final FieldOfficerSyncService _syncService;

  static const _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      appBarTitle: 'Field Operational Dashboard',
    ),
    (
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Tasks',
      appBarTitle: 'Assigned Inspections',
    ),
    (
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'My Inspections',
      appBarTitle: 'My Inspections',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncService = FieldOfficerSyncService()..initialize();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = const [
      FieldOfficerDashboardScreen(),
      TaskListScreen(),
      MyInspectionsScreen(),
    ];

    final isMobile = Breakpoints.mobile > MediaQuery.of(context).size.width;
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return ChangeNotifierProvider<FieldOfficerSyncService>.value(
      value: _syncService,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_destinations[_index].appBarTitle),
          leading: const Icon(Icons.terrain),
          actions: [
            if (isMobile)
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Navigation Menu',
                onSelected: (index) => setState(() => _index = index),
                itemBuilder: (context) => [
                  for (int i = 0; i < _destinations.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(
                            _index == i ? _destinations[i].selectedIcon : _destinations[i].icon,
                            color: _index == i ? Theme.of(context).colorScheme.primary : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _destinations[i].label,
                            style: TextStyle(
                              fontWeight: _index == i ? FontWeight.bold : FontWeight.normal,
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
                  child: Text(user?.displayName ?? user?.email ?? 'Field Officer'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            const FieldSyncBanner(),
            Expanded(child: IndexedStack(index: _index, children: screens)),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            for (final item in _destinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
