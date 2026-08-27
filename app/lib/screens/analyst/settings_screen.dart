import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth_navigation.dart';
import '../../core/responsive.dart';
import '../../models/user_role.dart';

/// Analyst Settings page (Phase 3 polish pass). Deliberately simple — a
/// real profile block plus a sign-out button, not a settings tree. There
/// is no editable account-settings backend yet (email/password change,
/// notification preferences, ...), so this doesn't pretend to offer any.
class AnalystSettingsScreen extends StatelessWidget {
  const AnalystSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(context.isMobile ? 12 : 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Analyst',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '—'),
                        const SizedBox(height: 4),
                        Text(
                          user?.role.label ?? UserRole.analystAdmin.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Analyst ID: ${user.uid}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a demo build of the NER Landslide Early Warning System, scoped '
                      'to the Dibang Valley study area (Arunachal Pradesh) only. Risk scores, '
                      'weather readings, and forecasts shown throughout the app are demo-shaped '
                      'placeholders, not live sensor or model output — see each screen for the '
                      'specific caveat.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => signOutToRoleSelect(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
