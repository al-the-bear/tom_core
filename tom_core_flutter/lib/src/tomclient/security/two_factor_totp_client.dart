/// The shipped TOTP client mechanism: the two panels an authenticator-app
/// factor needs, and nothing else.
///
/// TOTP is the mechanism every deployment has, so it ships registered rather
/// than as a sample to copy. It is also the mechanism that best demonstrates
/// why the panels are pluggable at all: enrolling one means *showing the user
/// a secret* — as a QR code to scan and as a string to type when the camera is
/// not an option — which looks nothing like enrolling an SMS factor (type a
/// phone number, wait for a text) or a WebAuthn one (touch the key, no visible
/// payload at all). A framework that tried to own one enrolment UI for all
/// three would own three special cases.
///
/// ## What arrives in `clientData`, and what the panels read
///
/// The server's `TomTotp2FAService` writes four keys — `secret`, `otpauthUri`,
/// `digits` and `periodSeconds` on an enrolment offer, `digits` and
/// `periodSeconds` on a challenge. The shipped panels read all four:
///
/// | key | written on | read here | meaning |
/// | --- | --- | --- | --- |
/// | `otpauthUri` | enrolment | yes ([uriKey]) | the `otpauth://` URI, rendered as the QR code |
/// | `secret` | enrolment | yes ([secretKey]) | the base32 secret, shown grouped for manual entry |
/// | `digits` | both | yes ([digitsKey]) | the code width the field is sized and validated to |
/// | `periodSeconds` | both | yes ([periodKey]) | the length of one time step, driving the challenge panel's countdown |
///
/// All four are read defensively — the map crossed the wire, and
/// a panel that threw on a missing key would turn a server-side omission into a
/// crashed login screen rather than a field with a sensible default.
///
/// The defence covers *unusable values*, not only absent ones. An `otpauthUri`
/// too long for any QR code to hold is the case that is easiest to reach
/// without anyone doing anything wrong — the URI grows with the issuer and
/// account label a deployment configures — and it renders as a blank square,
/// exactly as a missing URI does. That degradation is safe here specifically
/// because the enrolment panel shows the secret twice over: whatever happens to
/// the code, the base32 string beneath it is a complete enrolment path.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'qr_code_view.dart';
import 'two_factor_client.dart';
import 'two_factor_texts.dart';

/// The authenticator-app mechanism, registered under `'totp'`.
class TomTotp2FAClientMechanism extends Tom2FAClientMechanism {
  /// The mechanism key, matching the server adaptor's.
  static const String mechanismType = 'totp';

  /// `clientData` key holding the `otpauth://` URI the QR code encodes.
  static const String uriKey = 'otpauthUri';

  /// `clientData` key holding the base32 secret shown for manual entry.
  static const String secretKey = 'secret';

  /// `clientData` key holding the code width.
  static const String digitsKey = 'digits';

  /// `clientData` key holding the length of one time step, in seconds.
  static const String periodKey = 'periodSeconds';

  /// Creates the TOTP mechanism.
  const TomTotp2FAClientMechanism() : super(mechanismType);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => _TotpEnrolmentPanel(data: data);

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => _TotpChallengePanel(data: data);

  /// The code width declared in [clientData], or the RFC's six.
  ///
  /// Static and public because the *flow* has no business knowing TOTP's
  /// defaults, but a test — and the cross-tier runner deriving an expected code
  /// — needs the same reading the panel uses, and two readings would be one
  /// too many.
  static int digitsOf(Map<String, Object?> clientData) {
    final declared = clientData[digitsKey];
    if (declared is int && declared > 0) return declared;
    // Servers that JSON-encode numbers as strings are a real thing.
    if (declared is String) {
      final parsed = int.tryParse(declared);
      if (parsed != null && parsed > 0) return parsed;
    }
    return TomTotp.defaultDigits;
  }

  /// The time step declared in [clientData], or the RFC's thirty seconds.
  ///
  /// Public and static for the reason [digitsOf] is: the flow has no business
  /// knowing TOTP's defaults, and a test that wants the same reading the panel
  /// uses must not write a second one. Same defence, too — an `int`, a numeric
  /// `String` a server JSON-encoded that way, and a documented fallback
  /// otherwise.
  ///
  /// A `Duration` rather than an `int` because that is what [TomTotp] deals in,
  /// and the one arithmetic this value is for — where the current step ends —
  /// is easier to get wrong in bare seconds.
  static Duration periodOf(Map<String, Object?> clientData) {
    final declared = clientData[periodKey];
    if (declared is int && declared > 0) return Duration(seconds: declared);
    if (declared is String) {
      final parsed = int.tryParse(declared);
      if (parsed != null && parsed > 0) return Duration(seconds: parsed);
    }
    return TomTotp.defaultPeriod;
  }

  /// Whole seconds left in the time step containing [at] (default: now).
  ///
  /// Counts down to the instant the authenticator's code changes. TOTP steps
  /// are aligned to the Unix epoch rather than to when a challenge was issued,
  /// so this needs no server timestamp: the boundary is the same one
  /// [TomTotp.counterFor] divides by, and it is derived from the same UTC
  /// seconds.
  ///
  /// Answers the full [period] exactly on a boundary rather than zero, because
  /// a caller renders it as "valid for another N seconds" and a step that has
  /// just begun has all of them.
  static int secondsRemainingIn(Duration period, {DateTime? at}) {
    final step = period.inSeconds;
    if (step <= 0) return 0;
    final seconds =
        (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    return step - (seconds % step);
  }

  /// Splits [secret] into space-separated groups of four.
  ///
  /// Typing a 32-character base32 string off a screen is where manual TOTP
  /// enrolment actually fails; grouping is the difference between "annoying"
  /// and "abandoned". Four is what every authenticator app displays.
  static String groupSecret(String secret) {
    final buffer = StringBuffer();
    for (var i = 0; i < secret.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(
        secret.substring(i, i + 4 > secret.length ? secret.length : i + 4),
      );
    }
    return buffer.toString();
  }
}

/// Shows the secret (scannable and typable) and takes the confirmation code.
class _TotpEnrolmentPanel extends StatefulWidget {
  const _TotpEnrolmentPanel({required this.data});

  final Tom2FAEnrolmentPanelContext data;

  @override
  State<_TotpEnrolmentPanel> createState() => _TotpEnrolmentPanelState();
}

class _TotpEnrolmentPanelState extends State<_TotpEnrolmentPanel> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _uri {
    final raw = widget.data.clientData[TomTotp2FAClientMechanism.uriKey];
    return raw is String ? raw : '';
  }

  String get _secret {
    final raw = widget.data.clientData[TomTotp2FAClientMechanism.secretKey];
    return raw is String ? raw : '';
  }

  int get _digits => TomTotp2FAClientMechanism.digitsOf(widget.data.clientData);

  @override
  Widget build(BuildContext context) {
    final busy = widget.data.busy;
    return Column(
      key: const Key('tom-2fa-totp-enrolment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TomText(text: Tom2FATexts.text(Tom2FATexts.totpEnrolIntro)),
        const SizedBox(height: 16),
        Center(
          child: TomQrCodeView(
            key: const Key('tom-2fa-totp-qr'),
            data: _uri,
            semanticsLabel: Tom2FATexts.text(Tom2FATexts.totpEnrolQrLabel),
          ),
        ),
        // The account the factor belongs to, under the code it is encoded in.
        // A user with three work accounts in one authenticator scans three
        // visually identical QR codes; without this they cannot tell which one
        // they are adding until it is already in the list. Omitted entirely
        // when the application did not supply a name — an empty caption would
        // just be a gap.
        if (widget.data.accountLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: TomText(
              key: const Key('tom-2fa-totp-account'),
              text: widget.data.accountLabel,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TomText(text: Tom2FATexts.text(Tom2FATexts.totpEnrolManualEntry)),
        const SizedBox(height: 4),
        // Selectable so a user on a desktop can copy it rather than transcribe
        // it — the same fallback the grouping exists to make bearable.
        TomSelectableText(
          key: const Key('tom-2fa-totp-secret'),
          text: TomTotp2FAClientMechanism.groupSecret(_secret),
        ),
        const SizedBox(height: 16),
        TomTextField(
          key: const Key('tom-2fa-totp-enrolment-code'),
          controller: _code,
          label: Tom2FATexts.text(Tom2FATexts.totpEnrolCodeLabel),
          maxLength: _digits,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !busy,
          onSubmitted: busy ? null : (value) => widget.data.onSubmit(value),
        ),
        const SizedBox(height: 12),
        TomFilledButton(
          key: const Key('tom-2fa-totp-enrolment-submit'),
          onPressed: busy ? null : () => widget.data.onSubmit(_code.text),
          child: TomText(text: Tom2FATexts.text(Tom2FATexts.totpEnrolSubmit)),
        ),
      ],
    );
  }
}

/// Takes the one-time code that answers an outstanding TOTP challenge.
class _TotpChallengePanel extends StatefulWidget {
  const _TotpChallengePanel({required this.data});

  final Tom2FAChallengePanelContext data;

  @override
  State<_TotpChallengePanel> createState() => _TotpChallengePanelState();
}

class _TotpChallengePanelState extends State<_TotpChallengePanel> {
  final TextEditingController _code = TextEditingController();

  /// Drives the countdown. One second is the resolution the line is rendered
  /// at, so a faster timer would repaint without changing anything.
  Timer? _tick;

  /// Whole seconds left before the authenticator's code changes.
  ///
  /// **Seeded from the true boundary, then counted down.** TOTP steps are
  /// aligned to the Unix epoch, so where the current one ends is known without
  /// asking the server — [TomTotp2FAClientMechanism.secondsRemainingIn] derives
  /// it from the same UTC seconds [TomTotp.counterFor] divides. After that the
  /// timer decrements: re-reading the clock every second would buy accuracy
  /// nobody can see, since the jitter of a one-second timer over the five
  /// minutes a challenge stays answerable is a fraction of one of the seconds
  /// this displays, and the number is advice to a person rather than an input
  /// to anything.
  late int _remaining;

  /// How many rollovers this panel has watched.
  ///
  /// Compared against [_typedInStep] to notice that a code was overtaken. A
  /// counter local to the panel rather than [TomTotp.counterFor]'s, because the
  /// question is "has the code changed *since you typed*", which is about this
  /// screen's lifetime and not about absolute time.
  int _step = 0;

  /// The value of [_step] when the field's text was last edited, or `null`
  /// while the field is empty.
  int? _typedInStep;

  Duration get _period =>
      TomTotp2FAClientMechanism.periodOf(widget.data.clientData);

  @override
  void initState() {
    super.initState();
    _remaining = TomTotp2FAClientMechanism.secondsRemainingIn(_period);
    _code.addListener(_rememberStep);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.removeListener(_rememberStep);
    _code.dispose();
    super.dispose();
  }

  /// Records which step the text now in the field belongs to.
  ///
  /// Every edit refreshes it, so a user who retypes after a rollover is not
  /// left looking at a warning about the code they have just replaced.
  void _rememberStep() {
    final typed = _code.text.isEmpty ? null : _step;
    if (typed == _typedInStep) return;
    setState(() => _typedInStep = typed);
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      if (_remaining > 1) {
        _remaining--;
        return;
      }
      // The rollover. The authenticator now shows a different code, so this
      // step is over and whatever was typed belongs to the last one.
      _remaining = _period.inSeconds;
      _step++;
    });
  }

  /// Whether the text in the field was typed before a rollover.
  bool get _codeChanged => _typedInStep != null && _typedInStep != _step;

  @override
  Widget build(BuildContext context) {
    final busy = widget.data.busy;
    final digits = TomTotp2FAClientMechanism.digitsOf(widget.data.clientData);
    return Column(
      key: const Key('tom-2fa-totp-challenge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TomTextField(
          key: const Key('tom-2fa-totp-challenge-code'),
          controller: _code,
          label: Tom2FATexts.text(Tom2FATexts.totpChallengeCodeLabel),
          maxLength: digits,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !busy,
          onSubmitted: busy ? null : (value) => widget.data.onSubmit(value),
        ),
        const SizedBox(height: 4),
        // How long the code on the user's authenticator is still the current
        // one. Shown from the moment the panel opens, because "how long have I
        // got" is the question a user asks before they start typing.
        TomText(
          key: const Key('tom-2fa-totp-challenge-countdown'),
          text: Tom2FATexts.textWith(
            Tom2FATexts.totpChallengeExpiresIn,
            'seconds',
            _remaining,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // Shown only once a rollover has overtaken something already typed —
        // not at every rollover, which would say something alarming every
        // thirty seconds to a user who is still reading.
        //
        // It does not clear the field and it does not disable the button. The
        // server accepts one step either side of its own
        // (`TomTotp2FAService.globalSettingWindowSteps`), so a code typed just
        // before a rollover is still good, and a panel that refused to send it
        // would enforce a policy stricter than the one that judges it — and
        // would cost the user the very attempt it was trying to save. What the
        // line removes is the confusion: a refusal that would otherwise read as
        // "you typed it wrong" reads as "you typed it too late".
        if (_codeChanged) ...[
          const SizedBox(height: 4),
          TomText(
            key: const Key('tom-2fa-totp-challenge-code-changed'),
            text: Tom2FATexts.text(Tom2FATexts.totpChallengeCodeChanged),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        TomFilledButton(
          key: const Key('tom-2fa-totp-challenge-submit'),
          onPressed: busy ? null : () => widget.data.onSubmit(_code.text),
          child: TomText(
            text: Tom2FATexts.text(Tom2FATexts.totpChallengeSubmit),
          ),
        ),
      ],
    );
  }
}
