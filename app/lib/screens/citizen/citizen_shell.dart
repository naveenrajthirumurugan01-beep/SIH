import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/responsive.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'report_hazard_screen.dart';
import 'risk_map_screen.dart';

/// Adaptive navigation shell tying together the five Citizen screens.
class CitizenShell extends StatefulWidget {
  const CitizenShell({super.key});

  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'),
    (icon: Icons.add_a_photo_outlined, selectedIcon: Icons.add_a_photo, label: 'Report'),
    (icon: Icons.list_alt_outlined, selectedIcon: Icons.list_alt, label: 'My Reports'),
    (icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: 'Alerts'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _goTo),
      const CitizenRiskMapScreen(),
      const ReportHazardScreen(),
      const MyReportsScreen(),
      const CitizenAlertsScreen(),
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
                  onSelected: _goTo,
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
                      child: Text(user?.displayName ?? user?.email ?? 'Citizen'),
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
        onDestinationSelected: _goTo,
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

