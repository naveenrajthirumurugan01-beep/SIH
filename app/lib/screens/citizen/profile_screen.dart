import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_state.dart';
import '../../core/citizen_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: CitizenTheme.primary.withAlpha(20),
              child: const Icon(Icons.person, size: 52, color: CitizenTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.displayName ?? 'Citizen',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              '${AppConfig.district}, ${AppConfig.stateName}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          // Account info card
          _InfoCard(
            icon: Icons.badge_outlined,
            label: 'Account ID',
            value: appState.uid.length > 20 ? '${appState.uid.substring(0, 20)}…' : appState.uid,
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.location_city_outlined,
            label: 'Region',
            value: '${AppConfig.district}, ${AppConfig.stateName}',
          ),
          const SizedBox(height: 24),
          // Settings tiles
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Alert Notifications',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeThumbColor: CitizenTheme.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            label: 'Language',
            trailing: const Text('English', style: TextStyle(color: Colors.grey)),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'About NER Landslide EWS',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'NER Landslide EWS',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 SIH Team',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => appState.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(icon, color: CitizenTheme.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: CitizenTheme.primary),
      title: Text(label),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
