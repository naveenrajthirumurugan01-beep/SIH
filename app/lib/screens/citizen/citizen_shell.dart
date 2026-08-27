import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/citizen_theme.dart';
import '../../core/responsive.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'profile_screen.dart';

/// Adaptive navigation shell for the Citizen role — 4 tabs: Home | My
/// Reports | Alerts | Profile. Map and Report-hazard are reached from Home
/// (Quick Actions / full-screen map), not separate tabs.
///
/// This shell is the sole owner of the AppBar for all four tabs — the tab
/// screens themselves (HomeScreen, MyReportsScreen, CitizenAlertsScreen,
/// ProfileScreen) return bare content, not their own Scaffold, so there's
/// exactly one AppBar on screen at any width, not a shell-level one stacked
/// on top of each screen's own.
class CitizenShell extends StatefulWidget {
  const CitizenShell({super.key});

  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      appBarTitle: 'Dibang Valley',
    ),
    (
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
      label: 'My Reports',
      appBarTitle: 'My Reports',
    ),
    (
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Alerts',
      appBarTitle: 'Early Warning Alerts',
    ),
    (
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: 'Profile',
      appBarTitle: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _goTo),
      const MyReportsScreen(),
      const CitizenAlertsScreen(),
      const ProfileScreen(),
    ];

    final isMobile = Breakpoints.mobile > MediaQuery.of(context).size.width;
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return Theme(
      data: CitizenTheme.theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_destinations[_index].appBarTitle),
          actions: [
            if (isMobile)
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
                            _index == i
                                ? _destinations[i].selectedIcon
                                : _destinations[i].icon,
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
        ),
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          destinations: [
            for (final item in _destinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon, color: CitizenTheme.primary),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
