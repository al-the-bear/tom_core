/// The admin login screen: a bound [AdminLoginForm] over [AdminLoginCredentials]
/// driving [AdminSession.login] — and, when the administrator's account owes
/// one, the second factor that completes it.
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
///
/// **Two phases, one screen.** No administrator is 2FA-enrolled in the seeded
/// sample, but an enrolment is an *account* property the console does not
/// control: the day someone enrols `admin`, a console that ignored `requires2FA`
/// would store the interim token and then fail every call. So the screen
/// switches to a code phase on [AdminSession.awaitingSecondFactor] and builds an
/// [AdminSecondFactorForm] sized from the challenge's own `clientData['digits']`.
/// Staying on one screen rather than pushing a route keeps the shell's rule
/// intact — the home is a pure function of `isLoggedIn`, with no navigator state
/// to unwind when a spent challenge drops back to the credentials phase.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';
import '../domain/admin_login_credentials.dart';
import '../domain/admin_second_factor_code.dart';
import '../forms/admin_login_form.dart';
import '../forms/admin_second_factor_form.dart';

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

  /// The code form, built only once a challenge exists — its field width comes
  /// from that challenge, so there is nothing to build before one arrives.
  AdminSecondFactorForm? _codeForm;
  AdminSecondFactorCode? _codeValue;

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
      await widget.session.login(
        LoginRequest(
          username: _credentials.username.get(),
          password: _credentials.password.get(),
        ),
      );
      // A login that owes a second factor leaves the session awaiting one; the
      // build below then shows the code phase. The `admin` probe has not run
      // yet — it cannot, against an interim token — so a non-admin with a
      // second factor is still refused, just one pass later.
      if (mounted && widget.session.awaitingSecondFactor) _buildCodeForm();
    } on AdminBackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates the code form for the outstanding challenge, sized from the
  /// mechanism's declared code width (6 for TOTP) rather than a constant here.
  void _buildCodeForm() {
    _codeForm?.dispose();
    final value = AdminSecondFactorCode();
    final form = AdminSecondFactorForm(digits: _digits)..bind(value);
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
    } on AdminBackendException catch (e) {
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
    // itself, which is what the bootstrap test asserts against). The field
    // labels/hints come from the same bundle, resolved by the form's fields.
    final texts = TomTextResourceProvider.getAppResources();
    final codePhase = widget.session.awaitingSecondFactor && _codeForm != null;
    final scope = codePhase ? 'adminTwoFactor' : 'adminLogin';
    return TomScaffold(
      key: const Key('admin-login-screen'),
      appBar: TomAppBar(title: TomText(text: texts.getText('$scope.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: codePhase
                ? _codePhaseChildren(context, texts)
                : _credentialsPhaseChildren(context, texts),
          ),
        ),
      ),
    );
  }

  List<Widget> _credentialsPhaseChildren(
    BuildContext context,
    TomTextResourceProvider texts,
  ) => [
    TomText(
      text: texts.getText('adminLogin.intro'),
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
          : TomText(text: texts.getText('adminLogin.submit')),
    ),
  ];

  List<Widget> _codePhaseChildren(
    BuildContext context,
    TomTextResourceProvider texts,
  ) {
    final challenge = widget.session.pendingChallenge;
    return [
      TomText(
        // Placeholders are substituted here, the way every other parameterised
        // text in the console is (G-RES): the bundle owns the wording, the
        // screen owns the value.
        text: texts
            .getText('adminTwoFactor.intro')
            .replaceAll('{digits}', '$_digits'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      _codeForm!.code.widget,
      const SizedBox(height: 12),
      if (challenge != null)
        TomText(
          key: const Key('admin-login-attempts'),
          text: texts
              .getText('adminTwoFactor.attemptsRemaining')
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
            : TomText(text: texts.getText('adminTwoFactor.submit')),
      ),
      const SizedBox(height: 8),
      TomTextButton(
        onPressed: _busy ? null : _cancelCode,
        child: TomText(text: texts.getText('adminTwoFactor.cancel')),
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
            key: const Key('admin-login-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ];
}
