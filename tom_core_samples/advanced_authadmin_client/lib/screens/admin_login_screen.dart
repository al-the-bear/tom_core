/// The admin login screen: a bound [AdminLoginForm] over [AdminLoginCredentials]
/// driving [AdminSession.login] (step 33; reflected in todo 13).
///
/// The form is built unscoped, so its `formId: 'adminLogin'` *is* its base path
/// and each field self-addresses as its resource key (`adminLogin.username`,
/// `adminLogin.password`) — exactly the keys the installed public login bundle
/// serves. It is bound to a fresh [AdminLoginCredentials]. On submit we `save()`
/// the form — which validates, then writes the typed fields back into the bound
/// credentials via the reflection round-trip — then fold them into a wire
/// [LoginRequest] for the session.
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
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';
import '../domain/admin_login_credentials.dart';
import '../forms/admin_login_form.dart';

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
  late final AdminLoginForm _form;
  final AdminLoginCredentials _credentials = AdminLoginCredentials();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _form = AdminLoginForm();
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
    // labels/hints come from the same bundle, resolved by the form's fields.
    final texts = TomTextResourceProvider.getAppResources();
    return TomScaffold(
      key: const Key('admin-login-screen'),
      appBar: TomAppBar(title: TomText(text: texts.getText('adminLogin.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              TomText(
                text: texts.getText('adminLogin.intro'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _form.username.widget,
              const SizedBox(height: 12),
              _form.password.widget,
              const SizedBox(height: 16),
              if (_error != null) ...[
                TomText(
                  text: _error!,
                  key: const Key('admin-login-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TomFilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(
                  height: 18,
                  width: 18,
                  child: TomCircularProgressIndicator(strokeWidth: 2),
                )
                    : TomText(text: texts.getText('adminLogin.submit')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
