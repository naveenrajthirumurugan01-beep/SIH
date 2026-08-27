import 'package:flutter/material.dart';

import '../../core/citizen_theme.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell for the Citizen role — 4 tabs matching the image design:
/// Home | My Reports | Alerts | Profile
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
      const MyReportsScreen(),
      const CitizenAlertsScreen(),
      const ProfileScreen(),
    ];

    return Theme(
      data: CitizenTheme.theme,
      child: Scaffold(
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: CitizenTheme.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt, color: CitizenTheme.primary),
              label: 'My Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon:
                  Icon(Icons.notifications, color: CitizenTheme.primary),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person, color: CitizenTheme.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
