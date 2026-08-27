import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'reports_queue_screen.dart';
import 'tasks_screen.dart';

/// Bottom-nav shell for the four Analyst destinations. Unlike the Field
/// Officer flow, each of these is a flat list/dashboard — no linear
/// multi-step flow to push on top, so a plain IndexedStack + NavigationBar
/// is enough here.
class AnalystShell extends StatefulWidget {
  const AnalystShell({super.key});

  @override
  State<AnalystShell> createState() => _AnalystShellState();
}

class _AnalystShellState extends State<AnalystShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              AnalystDashboardScreen(onOpenReportsQueue: () => _goTo(1)),
              const ReportsQueueScreen(),
              const TasksScreen(),
              const AnalystAlertsScreen(),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton.filledTonal(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () => appState.authRepository.signOut(),
              ),
            ),
          ),
        ],
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
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
