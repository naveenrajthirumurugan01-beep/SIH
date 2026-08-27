import 'package:flutter/material.dart';

import '../../features/field_official/screens/field_officer_dashboard_screen.dart';
import 'my_inspections_screen.dart';
import 'task_list_screen.dart';

import '../../widgets/field_sync_banner.dart';

/// Bottom-nav shell for persistent Field Officer destinations: Dashboard, Tasks, and Inspections.
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
      FieldOfficerDashboardScreen(),
      TaskListScreen(),
      MyInspectionsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FieldSyncBanner(),
            Expanded(
              child: IndexedStack(index: _index, children: screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Inspections',
          ),
        ],
      ),
    );
  }
}
