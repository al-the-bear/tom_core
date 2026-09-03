/// The login screen: a bound [LoginForm] over [LoginCredentials], driving
/// [AppSession.login].
///
/// The form is constructed directly (so its `basePath` is the clean `login`
/// scope its field resources address) and bound to a fresh [LoginCredentials].
/// On submit we `save()` the form — which writes the typed fields back into the
/// bound credentials via the reflection round-trip — then hand the values to the
/// session. A failed login surfaces its [TodoApiException] message inline without
/// leaving the screen. All visible copy resolves through [TomCtr] (G-RES-1).
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../api/todo_api.dart';
import '../app/app_session.dart';
import '../domain/login_credentials.dart';
import '../forms/login_form.dart';

/// Sign-in screen wired to [session].
class LoginScreen extends StatefulWidget {
  /// Creates the screen over [session].
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
    _form = LoginForm();
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
      await widget.session.login(
        _credentials.username.get(),
        _credentials.password.get(),
      );
    } on TodoApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        title: TomText(text: TomCtr.text('login.appbar.title')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              TomText(
                text: TomCtr.text('login.intro'),
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
                    : TomText(text: TomCtr.text('login.submit')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
