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
/// ## What it reads from `clientData`
///
/// Exactly the keys the server's `TomTotp2FAService` writes, and nothing more:
///
/// | key | used by | meaning |
/// | --- | --- | --- |
/// | `otpauthUri` | enrolment | the `otpauth://` URI, rendered as the QR code |
/// | `secret` | enrolment | the base32 secret, shown grouped for manual entry |
/// | `digits` | both | the code width the field is sized and validated to |
///
/// Every one is read defensively: the map crossed the wire, and a panel that
/// threw on a missing key would turn a server-side omission into a crashed
/// login screen rather than a field with a sensible default.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  /// Creates the TOTP mechanism.
  const TomTotp2FAClientMechanism() : super(mechanismType);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) =>
      _TotpEnrolmentPanel(data: data);

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) =>
      _TotpChallengePanel(data: data);

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

  int get _digits =>
      TomTotp2FAClientMechanism.digitsOf(widget.data.clientData);

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

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.data.busy;
    final digits =
        TomTotp2FAClientMechanism.digitsOf(widget.data.clientData);
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
        const SizedBox(height: 12),
        TomFilledButton(
          key: const Key('tom-2fa-totp-challenge-submit'),
          onPressed: busy ? null : () => widget.data.onSubmit(_code.text),
          child:
              TomText(text: Tom2FATexts.text(Tom2FATexts.totpChallengeSubmit)),
        ),
      ],
    );
  }
}
