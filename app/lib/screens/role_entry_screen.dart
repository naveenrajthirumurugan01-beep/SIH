import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/user_role.dart';
import '../services/task_repository.dart';

class RoleEntryScreen extends StatefulWidget {
  const RoleEntryScreen({super.key});

  @override
  State<RoleEntryScreen> createState() => _RoleEntryScreenState();
}

class _RoleEntryScreenState extends State<RoleEntryScreen> {
  UserRole _selected = UserRole.citizen;
  final _nameController = TextEditingController();
  final _idController = TextEditingController(text: demoOfficerUid);

  bool get _canContinue {
    if (_selected != UserRole.fieldOfficial) return true;
    return _nameController.text.trim().isNotEmpty && _idController.text.trim().isNotEmpty;
  }

  void _continue() {
    final appState = context.read<AppState>();
    if (_selected == UserRole.fieldOfficial) {
      appState.setRole(
        UserRole.fieldOfficial,
        officerName: _nameController.text.trim(),
        officerId: _idController.text.trim(),
      );
    } else {
      appState.setRole(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.terrain_rounded, size: 68, color: Colors.tealAccent),
                const SizedBox(height: 12),
                Text(
                  'NER Landslide Early Warning System',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'North Eastern Region Disaster Management Portal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Card(
                  color: Colors.teal.withAlpha(38),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Icon(Icons.public, color: Colors.tealAccent, size: 28),
                        SizedBox(height: 8),
                        Text(
                          'Open Public Access for Citizens',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Receive instant geolocation landslide alerts and capture live hazard reports.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.citizen,
                      label: Text('Public Citizen'),
                      icon: Icon(Icons.person_pin_circle),
                    ),
                    ButtonSegment(
                      value: UserRole.fieldOfficial,
                      label: Text('Field Officer'),
                      icon: Icon(Icons.verified_user),
                    ),
                    ButtonSegment(
                      value: UserRole.analystAdmin,
                      label: Text('Analyst'),
                      icon: Icon(Icons.analytics),
                    ),
                  ],
                  selected: {_selected},
                  onSelectionChanged: (selection) =>
                      setState(() => _selected = selection.first),
                ),
                if (_selected == UserRole.fieldOfficial) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Officer Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _idController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Officer ID',
                      helperText: 'Keep "demo_officer" to view assigned tasks',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _canContinue ? _continue : null,
                  child: Text(
                    _selected == UserRole.citizen
                        ? 'Enter as Citizen (Open Public Access)'
                        : 'Continue to Portal',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
