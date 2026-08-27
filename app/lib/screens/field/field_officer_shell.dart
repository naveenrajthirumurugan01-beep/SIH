import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/responsive.dart';
import 'my_inspections_screen.dart';
import 'task_list_screen.dart';

/// Adaptive navigation shell for the two persistent Field Officer destinations.
/// Task detail / geofence check / inspection form are pushed on top of
/// this as a linear flow from a task list entry, not separate tabs.
class FieldOfficerShell extends StatefulWidget {
  const FieldOfficerShell({super.key});

  @override
  State<FieldOfficerShell> createState() => _FieldOfficerShellState();
}

class _FieldOfficerShellState extends State<FieldOfficerShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Tasks'),
    (icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'My Inspections'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = const [
      TaskListScreen(),
      MyInspectionsScreen(),
    ];

    final isMobile = Breakpoints.mobile > MediaQuery.of(context).size.width;
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: Text(_destinations[_index].label),
              leading: const Icon(Icons.terrain),
              actions: [
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
            )
          : null,
      body: IndexedStack(index: _index, children: screens),
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
    );
  }
}

