import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'auth/sign_in_screen.dart';

/// First screen shown whenever no one is signed in (see main.dart). Picking
/// a role just locks which sign-in screen you land on next — it doesn't
/// authenticate anything by itself, and the app never trusts this choice
/// for authorization (AppState.currentUser's role, read from Firestore
/// after a real sign-in, is what every shell/rule actually checks).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _goToSignIn(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignInScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terrain, size: 64),
                const SizedBox(height: 8),
                Text(
                  'NER Landslide Early Warning',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Continue as...',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                  children: [
                    _RoleTile(
                      icon: Icons.person,
                      label: 'Citizen',
                      onTap: () => _goToSignIn(context, UserRole.citizen),
                    ),
                    _RoleTile(
                      icon: Icons.directions_walk,
                      label: 'Field Officer',
                      onTap: () => _goToSignIn(context, UserRole.fieldOfficial),
                    ),
                    _RoleTile(
                      icon: Icons.admin_panel_settings,
                      label: 'Analyst',
                      onTap: () => _goToSignIn(context, UserRole.analystAdmin),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
