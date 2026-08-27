import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/role_select_screen.dart';
import 'app_state.dart';

/// The one correct way to sign out and leave a shell — used by every
/// sign-out button (Analyst header menu, Settings page, ...). Signs out
/// via [AppState.signOut], then navigates directly to [RoleSelectScreen]
/// with `pushAndRemoveUntil` rather than relying on main.dart's
/// _AuthRouter to react to the auth-stream update: this shell was itself
/// reached via a direct `pushAndRemoveUntil` from RoleSelectScreen (see
/// its demo sign-in flow), which clears _AuthRouter's own route out of
/// the navigation stack — so nothing is left listening for
/// [AppState.currentUser] to go null and route back on its own.
Future<void> signOutToRoleSelect(BuildContext context) async {
  final appState = context.read<AppState>();
  final navigator = Navigator.of(context);
  await appState.signOut();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
    (route) => false,
  );
}
