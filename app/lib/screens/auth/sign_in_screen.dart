import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/responsive.dart';
import '../../models/user_role.dart';
import 'sign_up_screen.dart';

/// Reached from RoleSelectScreen with [role] already picked and not
/// editable here — this only affects display (heading, and whether the
/// "Sign up instead" link shows) and never authorization. What actually
/// determines which shell a signed-in user lands in is their real role on
/// the Firestore users/{uid} doc (see AppState.currentUser / main.dart).
class SignInScreen extends StatefulWidget {
  final UserRole role;

  const SignInScreen({super.key, required this.role});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  String get _roleLabel => switch (widget.role) {
        UserRole.citizen => 'Citizen',
        UserRole.fieldOfficial => 'Field Officer',
        UserRole.analystAdmin => 'Analyst',
      };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await context.read<AppState>().authRepository.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // AppState's auth stream updates and main.dart's _AuthRouter (the
      // MaterialApp's `home`, underneath this pushed route) rebuilds into
      // the right shell — but that rebuild happens on the route beneath
      // this one, so it stays invisible until we pop back to it.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on StateError catch (e) {
      // e.g. a Firebase Auth account with no matching users/{uid} doc yet.
      setState(() => _errorMessage = e.message);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Sign in failed.');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_roleLabel Sign In')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsivePadding.defaultPadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.terrain, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in as $_roleLabel',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log In'),
                  ),
                  if (widget.role == UserRole.citizen) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      ),
                      child: const Text("Don't have an account? Sign up"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
