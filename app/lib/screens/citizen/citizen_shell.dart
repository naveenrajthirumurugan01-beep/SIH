import 'package:flutter/material.dart';

import 'alerts_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'report_hazard_screen.dart';
import 'risk_map_screen.dart';

/// Bottom-nav shell tying together the five Citizen screens.
class CitizenShell extends StatefulWidget {
  const CitizenShell({super.key});

  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _goTo),
      const CitizenRiskMapScreen(),
      const ReportHazardScreen(),
      const MyReportsScreen(),
      const CitizenAlertsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_a_photo_outlined),
            selectedIcon: Icon(Icons.add_a_photo),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
