/// The login screen: a bound [LoginForm] over [LoginCredentials], driving
/// [AppSession.login] (step 28).
///
/// The form is created inside a [TomScope] (so its fields resolve ids/resources
/// consistently) and bound to a fresh [LoginCredentials]. On submit we `save()`
/// the form — which writes the typed fields back into the bound credentials via
/// the reflection round-trip — then fold them into a wire [LoginRequest] for the
/// session. A rejected login surfaces its [AppBackendException] message inline
/// without leaving the screen (the shell only swaps to the board on success).
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';
import '../domain/login_credentials.dart';
import '../forms/login_form.dart';

/// Sign-in screen wired to [session].
class LoginScreen extends StatefulWidget {
  /// Creates the screen over [session]; a successful login populates it and the
  /// shell rebuilds onto the board.
  const LoginScreen({super.key, required this.session});

  /// The session the successful login populates.
  final AppSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginForm _form;
  final LoginCredentials _credentials = LoginCredentials();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('login', LoginForm.new);
    _form.bind(_credentials);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!await _form.save()) return; // validation failed; fields show errors
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(LoginRequest(
        username: _credentials.username.get(),
        password: _credentials.password.get(),
      ));
    } on AppBackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login-screen'),
      appBar: AppBar(title: const Text('Advanced Todo — sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Try alice, bob or val (any non-empty password).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _form.username.widget,
              const SizedBox(height: 12),
              _form.password.widget,
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('login-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
