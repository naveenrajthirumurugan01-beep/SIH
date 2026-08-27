import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../models/user_role.dart';
import '../../auth/providers/auth_provider.dart';

/// Dedicated authentication screen for Field Officers.
/// Validates credentials via Firebase Auth, retrieves the user profile,
/// and strictly verifies that:
/// 1. profile.role == UserRole.fieldOfficial
/// 2. profile.status == 'active'
class FieldOfficerLoginScreen extends StatefulWidget {
  const FieldOfficerLoginScreen({super.key});

  @override
  State<FieldOfficerLoginScreen> createState() => _FieldOfficerLoginScreenState();
}

class _FieldOfficerLoginScreenState extends State<FieldOfficerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'officer@ner.gov.in');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final appState = context.read<AppState>();

      // Perform authenticating & strict role/status validation
      final profile = await authProvider.signInFieldOfficer(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Sync officer identity to AppState container for downstream repositories
      await appState.setRole(
        UserRole.fieldOfficial,
        officerName: profile.fullName,
        officerId: profile.officerId ?? profile.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${profile.fullName} (${profile.officerId ?? profile.uid})'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      // Dismiss login modal/screen to reveal Field Officer Dashboard
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString();
      final cleanMessage = rawError.contains(']')
          ? rawError.substring(rawError.indexOf(']') + 1).trim()
          : rawError;
      setState(() => _errorMessage = cleanMessage);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Officer Portal Login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield, size: 64, color: Color(0xFF1565C0)),
                  const SizedBox(height: 12),
                  Text(
                    'Field Official Portal',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authorized Personnel Only — Credential & Role Verification Required',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Official Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters required' : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isSubmitting ? 'Verifying Credentials...' : 'Authenticate & Enter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
