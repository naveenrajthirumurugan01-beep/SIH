import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/app_state.dart';
import 'core/firebase_options.dart';
import 'core/theme.dart';
import 'models/user_role.dart';
import 'screens/analyst/analyst_shell.dart';
import 'screens/citizen/citizen_shell.dart';
import 'screens/field/field_officer_shell.dart';
import 'screens/role_entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No Firebase project exists yet: AppConfig.useMockData gates every
  // Firebase call in the app, including this one, so the app is fully
  // runnable today with zero config. Flip the flag (and regenerate
  // core/firebase_options.dart via `flutterfire configure`) to go live.
  if (!AppConfig.useMockData) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final appState = await AppState.create();

  runApp(LandslideEwsApp(appState: appState));
}

class LandslideEwsApp extends StatelessWidget {
  final AppState appState;

  const LandslideEwsApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'NER Landslide EWS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const _RoleRouter(),
      ),
    );
  }
}

/// Routes to the role-entry screen (no role chosen yet — see
/// screens/role_entry_screen.dart, a placeholder for real login), the
/// Field Officer shell, or the Citizen shell. The Citizen shell gets a
/// small "switch role" debug overlay layered on top here rather than
/// inside its own screens, so this task doesn't have to modify them.
class _RoleRouter extends StatelessWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final role = appState.currentRole;

    if (role == null) return const RoleEntryScreen();
    if (role == UserRole.fieldOfficial) return const FieldOfficerShell();
    if (role == UserRole.analystAdmin) return const AnalystShell();

    return Stack(
      children: [
        const CitizenShell(),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton.filledTonal(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch role (demo)',
              onPressed: appState.clearRole,
            ),
          ),
        ),
      ],
    );
  }
}
