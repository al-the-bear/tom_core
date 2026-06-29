/// The admin login screen: username/password entry driving [AdminSession.login]
/// (step 33).
///
/// Deliberately a plain Material [Form] — not a reflected `TomForm`. The login
/// collects two strings and folds them into a wire [LoginRequest]; there is no
/// domain entity to round-trip, so this screen stays reflection-free (the
/// admin console's reflected forms are the user/role/group editors in step 34).
/// That keeps the step-33 widget tests socket- and reflection-free, matching the
/// step-32 seam.
///
/// A rejected sign-in surfaces its [AdminBackendException] message inline without
/// leaving the page. Two refusals look the same to the user but mean different
/// things: bad credentials (`auth.login.failed`) and — because the role gate is
/// per-operation — a valid non-admin login that fails the admin probe
/// (`admin.access.forbidden`). Either way the shell only opens on success.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';

/// Sign-in screen wired to [session].
class AdminLoginScreen extends StatefulWidget {
  /// Creates the screen over [session]; a successful admin login populates it
  /// and the shell rebuilds onto the console.
  const AdminLoginScreen({super.key, required this.session});

  /// The session the successful login populates.
  final AdminSession session;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(LoginRequest(
        username: _username.text,
        password: _password.text,
      ));
    } on AdminBackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen chrome is server-delivered: the bundle the bootstrap installed
    // supplies the title, intro and submit label (a missing key falls back to
    // itself, which is what the bootstrap test asserts against). The field
    // labels stay plain for now — the reflected form lands in a later step.
    final texts = TomTextResourceProvider.getAppResources();
    return Scaffold(
      key: const Key('admin-login-screen'),
      appBar: AppBar(title: Text(texts.getText('adminLogin.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  texts.getText('adminLogin.intro'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'admin',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    key: const Key('admin-login-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
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
                      : Text(texts.getText('adminLogin.submit')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
