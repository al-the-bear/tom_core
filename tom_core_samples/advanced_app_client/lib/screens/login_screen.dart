/// The login screen: a bound [LoginForm] over [LoginCredentials], driving
/// [AppSession.login] (step 28) — and, when the account owes one, the second
/// factor that completes it.
///
/// The form is built unscoped, so its `formId: 'login'` *is* its base path and
/// each field self-addresses as its resource key (`login.username`,
/// `login.password`) — exactly the keys the installed login bundle serves. It is
/// bound to a fresh [LoginCredentials]. On submit we `save()` the form — which
/// writes the typed fields back into the bound credentials via the reflection
/// round-trip — then fold them into a wire [LoginRequest] for the session. A
/// rejected login surfaces its [AppBackendException] message inline without
/// leaving the screen (the shell only swaps to the board on success).
///
/// **Two phases, one screen.** A login that returns `requires2FA` is not a
/// session, so the shell keeps showing *this* screen; it switches to the code
/// phase on [AppSession.awaitingSecondFactor] and builds a [SecondFactorForm]
/// sized from the challenge's own `clientData['digits']`. Staying on one screen
/// rather than pushing a route is what keeps the shell's rule intact — the home
/// is a pure function of `isLoggedIn`, with no navigator state to unwind when a
/// spent challenge drops back to the credentials phase.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';
import '../domain/login_credentials.dart';
import '../domain/second_factor_code.dart';
import '../forms/login_form.dart';
import '../forms/second_factor_form.dart';

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

  /// The code form, built only once a challenge exists — its field width comes
  /// from that challenge, so there is nothing to build before one arrives.
  SecondFactorForm? _codeForm;
  SecondFactorCode? _codeValue;

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
    _codeForm?.dispose();
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
      // A login that owes a second factor leaves the session awaiting one; the
      // build below then shows the code phase.
      if (mounted && widget.session.awaitingSecondFactor) _buildCodeForm();
    } on AppBackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates the code form for the outstanding challenge, sized from the
  /// mechanism's declared code width (6 for TOTP) rather than a constant here.
  void _buildCodeForm() {
    _codeForm?.dispose();
    final value = SecondFactorCode();
    final form = SecondFactorForm(digits: _digits)..bind(value);
    _codeForm = form;
    _codeValue = value;
  }

  /// The challenge's code width, defaulting to the RFC's six when a mechanism
  /// declares none.
  int get _digits {
    final declared = widget.session.pendingChallenge?.clientData['digits'];
    return declared is int && declared > 0 ? declared : 6;
  }

  Future<void> _submitCode() async {
    final form = _codeForm;
    final value = _codeValue;
    if (form == null || value == null) return;
    if (!await form.save()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.submitSecondFactor(value.code.get());
    } on AppBackendException catch (e) {
      // A retryable refusal keeps the code phase (with one attempt fewer); a
      // spent challenge has already returned the session to the credentials
      // phase, and the message explains why the password screen is back.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelCode() {
    widget.session.cancelSecondFactor();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    // Screen chrome is server-delivered: the bundle the bootstrap installed
    // supplies the title, intro and submit label (a missing key falls back to
    // itself, which is what the bootstrap test asserts against).
    final texts = TomTextResourceProvider.getAppResources();
    final codePhase = widget.session.awaitingSecondFactor && _codeForm != null;
    final scope = codePhase ? 'twoFactor' : 'login';
    return TomScaffold(
      key: const Key('login-screen'),
      appBar: TomAppBar(title: TomText(text: texts.getText('$scope.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: codePhase
                ? _codePhase(context, texts)
                : _credentialsPhase(context, texts),
          ),
        ),
      ),
    );
  }

  List<Widget> _credentialsPhase(
    BuildContext context,
    TomTextResourceProvider texts,
  ) =>
      [
        TomText(
          text: texts.getText('login.intro'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _form.username.widget,
        const SizedBox(height: 12),
        _form.password.widget,
        const SizedBox(height: 16),
        ..._errorBlock(context),
        TomFilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: TomCircularProgressIndicator(strokeWidth: 2),
                )
              : TomText(text: texts.getText('login.submit')),
        ),
      ];

  List<Widget> _codePhase(
    BuildContext context,
    TomTextResourceProvider texts,
  ) {
    final challenge = widget.session.pendingChallenge;
    return [
      TomText(
        // Placeholders are substituted here, the way every other
        // parameterised text in the app is (G-RES): the bundle owns the
        // wording, the screen owns the value.
        text: texts
            .getText('twoFactor.intro')
            .replaceAll('{digits}', '$_digits'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      _codeForm!.code.widget,
      const SizedBox(height: 12),
      if (challenge != null)
        TomText(
          key: const Key('login-attempts'),
          text: texts
              .getText('twoFactor.attemptsRemaining')
              .replaceAll('{count}', '${challenge.attemptsRemaining}'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: 16),
      ..._errorBlock(context),
      TomFilledButton(
        onPressed: _busy ? null : _submitCode,
        child: _busy
            ? SizedBox(
                height: 18,
                width: 18,
                child: TomCircularProgressIndicator(strokeWidth: 2),
              )
            : TomText(text: texts.getText('twoFactor.submit')),
      ),
      const SizedBox(height: 8),
      TomTextButton(
        onPressed: _busy ? null : _cancelCode,
        child: TomText(text: texts.getText('twoFactor.cancel')),
      ),
    ];
  }

  /// The inline failure message, shown in both phases under the same key so a
  /// caller (and the widget tests) has one place to read it from.
  List<Widget> _errorBlock(BuildContext context) => _error == null
      ? const []
      : [
          TomText(
            text: _error!,
            key: const Key('login-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ];
}
