import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/user_role.dart';
import '../services/task_repository.dart';

/// PLACEHOLDER FOR REAL LOGIN. Shown at launch whenever AppState.currentRole
/// is null (see main.dart), and reachable again any time via the "switch
/// role" action in each shell. Stands in for a real Firebase Auth
/// signup/role-selection flow — replace once that exists.
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
                const Icon(Icons.terrain, size: 64),
                const SizedBox(height: 8),
                Text(
                  'NER Landslide EWS',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Demo build — no login yet. Choose how to continue.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.citizen, label: Text('Citizen')),
                    ButtonSegment(
                      value: UserRole.fieldOfficial,
                      label: Text('Field Officer'),
                    ),
                    ButtonSegment(
                      value: UserRole.analystAdmin,
                      label: Text('Analyst'),
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
                      helperText: 'Keep "demo_officer" to see the seeded demo tasks',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _canContinue ? _continue : null,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
