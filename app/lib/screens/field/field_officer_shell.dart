import 'package:flutter/material.dart';

import 'my_inspections_screen.dart';
import 'task_list_screen.dart';

/// Bottom-nav shell for the two persistent Field Officer destinations.
/// Task detail / geofence check / inspection form are pushed on top of
/// this as a linear flow from a task list entry, not separate tabs.
class FieldOfficerShell extends StatefulWidget {
  const FieldOfficerShell({super.key});

  @override
  State<FieldOfficerShell> createState() => _FieldOfficerShellState();
}

class _FieldOfficerShellState extends State<FieldOfficerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      TaskListScreen(),
      MyInspectionsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'My Inspections',
          ),
        ],
      ),
    );
  }
}
