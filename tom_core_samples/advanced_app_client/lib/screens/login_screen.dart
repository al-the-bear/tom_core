/// The login screen: a bound [LoginForm] over [LoginCredentials], driving
/// [AppSession.login] — and, when the account owes one, the second
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
/// **Two phases, one screen.** A login that returns `requires2FA` or
/// `requires2FAEnrolment` is not a session, so the shell keeps showing *this*
/// screen; it switches to the second-factor phase on
/// [AppSession.awaitingTwoFactor]. Staying on one screen rather than pushing a
/// route is what keeps the shell's rule intact — the home is a pure function of
/// `isLoggedIn`, with no navigator state to unwind when a spent challenge drops
/// back to the credentials phase.
///
/// **The second-factor phase is the framework's, not this app's.** It is one
/// widget — [Tom2FAFlowPanel] over a [SessionTwoFactorController] — and that is
/// deliberate: the chooser, the QR code, the code field's width, the attempt
/// counter and the rule that "Not now" appears only when the server permits it
/// are all invariant across applications, so they live in `tom_core_flutter`.
/// This screen contributes the app-bar title and nothing else. Notably absent is
/// any reading of `clientData['digits']`: a mechanism with a different code
/// shape needs no change here, which is the property the split exists for.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/app_session.dart';
import '../app/session_two_factor_controller.dart';
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

  /// The app's seam into the framework flow. Built once and kept, so the panel
  /// it drives is not rebuilt from scratch on every notification.
  late final SessionTwoFactorController _twoFactor;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _form = LoginForm();
    _form.bind(_credentials);
    _twoFactor = SessionTwoFactorController(widget.session);
    // Rebuild as the flow advances: the panel reads its position from the
    // session on every build, so a move that changes that position has to reach
    // this screen. The session is the notifier either way — the panel holds no
    // copy of where the login is.
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _form.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
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
      // A login that owes a second factor — to answer or to set up — leaves the
      // session awaiting one, and the build below shows the flow panel.
    } on AppBackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen chrome is server-delivered: the bundle the bootstrap installed
    // supplies the title, intro and submit label (a missing key falls back to
    // itself, which is what the bootstrap test asserts against).
    final texts = TomTextResourceProvider.getAppResources();
    final twoFactorPhase = widget.session.awaitingTwoFactor;
    final scope = twoFactorPhase ? 'twoFactor' : 'login';
    return TomScaffold(
      key: const Key('login-screen'),
      appBar: TomAppBar(title: TomText(text: texts.getText('$scope.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: twoFactorPhase
                ? [Tom2FAFlowPanel(controller: _twoFactor)]
                : _credentialsPhase(context, texts),
          ),
        ),
      ),
    );
  }

  List<Widget> _credentialsPhase(
    BuildContext context,
    TomTextResourceProvider texts,
  ) => [
    TomText(
      text: texts.getText('login.intro'),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 16),
    _form.username.widget,
    const SizedBox(height: 12),
    _form.password.widget,
    const SizedBox(height: 16),
    // The rejected-credentials message, or — when the phase we just left was
    // the second factor's — the reason it ended. The flow panel's own error
    // line disappeared with the panel, so a spent challenge would otherwise
    // drop the user back here with no account of what happened.
    ..._errorBlock(context, _error ?? widget.session.abandonedTwoFactorMessage),
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

  /// The inline failure line for the credentials phase, showing [message]. The
  /// second-factor phase has its own (`tom-2fa-error`), owned by the flow panel
  /// while the flow is running.
  List<Widget> _errorBlock(BuildContext context, String? message) =>
      message == null
      ? const []
      : [
          TomText(
            text: message,
            key: const Key('login-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ];
}
