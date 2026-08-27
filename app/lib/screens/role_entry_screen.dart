import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/user_role.dart';

import '../features/field_official/screens/field_officer_login_screen.dart';

/// Role Selection & Auth Launch Entry Screen.
class RoleEntryScreen extends StatefulWidget {
  const RoleEntryScreen({super.key});

  @override
  State<RoleEntryScreen> createState() => _RoleEntryScreenState();
}

class _RoleEntryScreenState extends State<RoleEntryScreen> {
  UserRole _selected = UserRole.citizen;

  Future<void> _continue() async {
    final appState = context.read<AppState>();
    if (_selected == UserRole.fieldOfficial) {
      // Require real email/password authentication & role verification for Field Officer
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FieldOfficerLoginScreen()),
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
                  'Choose portal to continue.',
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
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Field Officer portal requires credential authentication & role verification.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _continue,
                  child: Text(_selected == UserRole.fieldOfficial ? 'Proceed to Officer Login' : 'Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
