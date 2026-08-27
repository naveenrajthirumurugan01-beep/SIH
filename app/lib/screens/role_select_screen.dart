import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/responsive.dart';
import '../models/user_role.dart';
import 'analyst/analyst_shell.dart';
import 'auth/sign_in_screen.dart';
import 'citizen/citizen_shell.dart';
import 'field/field_officer_shell.dart';

/// First screen shown whenever no one is signed in (see main.dart). Picking
/// a role just locks which sign-in screen you land on next — it doesn't
/// authenticate anything by itself, and the app never trusts this choice
/// for authorization (AppState.currentUser's role, read from Firestore
/// after a real sign-in, is what every shell/rule actually checks).
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _isSigningIn = false;

  // TEMPORARY (see AppConfig.skipAuthForDemo) — known demo-account
  // credentials per role. The bypass below signs in for real through
  // Firebase Auth with these rather than faking a local AppUser: a faked
  // user has no backing Firebase Auth session, so request.auth.uid is
  // empty and every firestore.rules check (users/{uid}, risk_zones,
  // inspection_tasks, ...) denies it with permission-denied. Real sign-in
  // means every screen's real Firestore reads work exactly as they would
  // for a normal login.
  //
  // Citizen uses a fixed citizen@gmail.com demo account (created the same
  // way as Field Officer/Analyst below) rather than the pre-existing
  // hello@gmail.com — that account was self-registered by a real user
  // through the app's sign-up flow, so its real password is unknown here;
  // reusing it would just fail with an "incorrect credential" error.
  static const _demoCredentials = <UserRole, (String email, String password)>{
    UserRole.citizen: ('citizen@gmail.com', 'test!1234'),
    UserRole.fieldOfficial: ('field@gmail.com', 'test!1234'),
    UserRole.analystAdmin: ('analyst@gmail.com', 'test!1234'),
  };

  @override
  void initState() {
    super.initState();
    // Clear any leftover session the moment this screen loads (e.g. left
    // over from a previous test run, hot restart, or a different role's
    // sign-in) so a fresh role tap always starts from a clean slate
    // rather than racing whatever was signed in before.
    unawaited(_forceSignOut());
  }

  Future<void> _forceSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Nothing was signed in, or the sign-out itself failed — either way
      // there's no leftover session left to worry about.
    }
  }

  Widget _shellFor(UserRole role) => switch (role) {
        UserRole.citizen => const CitizenShell(),
        UserRole.fieldOfficial => const FieldOfficerShell(),
        UserRole.analystAdmin => const AnalystShell(),
      };

  Future<void> _goToSignIn(BuildContext context, UserRole role) async {
    if (AppConfig.skipAuthForDemo) {
      final (email, password) = _demoCredentials[role]!;
      final appState = context.read<AppState>();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isSigningIn = true);
      try {
        // Sign out first — ignore errors, there may be nothing signed in.
        // This guarantees the sign-in below always starts from a clean
        // session instead of potentially racing a previous one.
        await _forceSignOut();

        await appState.authRepository.signIn(email: email, password: password);

        // Navigate directly to the role's shell rather than waiting for
        // AppState's auth stream to emit and main.dart's _AuthRouter to
        // react to it: that stream update is not instantaneous, and
        // waiting on it here made the demo flow flaky. pushAndRemoveUntil
        // clears the navigation history so there's no way back to a
        // stale RoleSelectScreen/SignInScreen route underneath.
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => _shellFor(role)),
          (route) => false,
        );
      } on FirebaseAuthException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Demo sign-in failed: ${e.message ?? e.code}')),
        );
      } on StateError catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Demo sign-in failed: $e')));
      } finally {
        if (mounted) setState(() => _isSigningIn = false);
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignInScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: ResponsivePadding.defaultPadding(context),
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
                          onTap: _isSigningIn ? null : () => _goToSignIn(context, UserRole.citizen),
                        ),
                        _RoleTile(
                          icon: Icons.directions_walk,
                          label: 'Field Officer',
                          onTap:
                              _isSigningIn ? null : () => _goToSignIn(context, UserRole.fieldOfficial),
                        ),
                        _RoleTile(
                          icon: Icons.admin_panel_settings,
                          label: 'Analyst',
                          onTap:
                              _isSigningIn ? null : () => _goToSignIn(context, UserRole.analystAdmin),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isSigningIn)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

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
