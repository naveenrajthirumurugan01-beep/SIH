import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'models/user_role.dart';
import 'screens/analyst/analyst_shell.dart';
import 'screens/citizen/citizen_shell.dart';
import 'screens/field/field_officer_shell.dart';
import 'screens/role_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real Firebase project (ner-landslide-ews) — see lib/firebase_options.dart.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        home: const _AuthRouter(),
      ),
    );
  }
}

/// Routes purely off AppState.currentUser, which mirrors Firebase Auth +
/// the matching Firestore profile (see AuthRepository.currentAppUser):
/// signed out -> RoleSelectScreen; signed in -> the shell matching their
/// (real, Firestore-backed) role.
class _AuthRouter extends StatelessWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.authResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = appState.currentUser;
    if (user == null) return const RoleSelectScreen();

    return switch (user.role) {
      UserRole.fieldOfficial => const FieldOfficerShell(),
      UserRole.analystAdmin => const AnalystShell(),
      UserRole.citizen => const CitizenShell(),
    };
  }
}
