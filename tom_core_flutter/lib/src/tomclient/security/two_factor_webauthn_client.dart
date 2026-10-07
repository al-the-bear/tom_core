/// The passkey second factor's client half.
///
/// Its panels have nothing to show and nothing to type: a sentence and one
/// button, which hands the server's options to [TomWebAuthnPlatform] and
/// submits what the authenticator returned. The button is the point — Safari
/// refuses a WebAuthn ceremony that a user gesture did not start, so the panel
/// cannot begin one on its own when it appears.
///
/// ## Through the `String` seam
///
/// [Tom2FAEnrolmentPanelContext.onSubmit] and
/// [Tom2FAChallengePanelContext.onSubmit] take what the mechanism collected as
/// a `String`. Here that is the authenticator's signed response, encoded with
/// `toSubmission()` — its W3C JSON form, base64url — which the server's
/// `TomWebAuthn2FAService` decodes. The flow, which owns the busy flag and the
/// error line, neither knows nor needs to know that this answer was not typed.
///
/// ## Registered only where it can run
///
/// The flow registers this mechanism only when [TomWebAuthnPlatform.instance]
/// reports a platform authenticator — on the web, in a browser with
/// `navigator.credentials`. On any other target the key stays unregistered, so
/// the enrolment chooser leaves passkeys out and a challenge for one shows the
/// flow's "this app cannot render that method" message.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'two_factor_client.dart';
import 'two_factor_texts.dart';
import 'webauthn_platform.dart';

/// The passkey mechanism, registered under `'webauthn'`.
class TomWebAuthn2FAClientMechanism extends Tom2FAClientMechanism {
  /// The mechanism key, matching the server adaptor's.
  static const String mechanismType = 'webauthn';

  /// The `clientData` key the server sends its options under.
  static const String optionsKey = 'publicKey';

  /// Creates the mechanism.
  const TomWebAuthn2FAClientMechanism() : super(mechanismType);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => _PasskeyPanel(
    key: const Key('tom-2fa-webauthn-enrolment'),
    intro: Tom2FATexts.webauthnEnrolIntro,
    submit: Tom2FATexts.webauthnEnrolSubmit,
    busy: data.busy,
    ceremony: () async {
      final options = TomWebAuthnCreationOptions.fromJson(
        data.clientData[optionsKey],
      );
      if (options == null) {
        throw const TomWebAuthnPlatformException('no creation options');
      }
      final response = await TomWebAuthnPlatform.instance.create(options);
      return response.toSubmission();
    },
    onSubmit: data.onSubmit,
  );

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => _PasskeyPanel(
    key: const Key('tom-2fa-webauthn-challenge'),
    intro: Tom2FATexts.webauthnChallengeIntro,
    submit: Tom2FATexts.webauthnChallengeSubmit,
    busy: data.busy,
    ceremony: () async {
      final options = TomWebAuthnRequestOptions.fromJson(
        data.clientData[optionsKey],
      );
      if (options == null) {
        throw const TomWebAuthnPlatformException('no request options');
      }
      final response = await TomWebAuthnPlatform.instance.get(options);
      return response.toSubmission();
    },
    onSubmit: data.onSubmit,
  );
}

class _PasskeyPanel extends StatefulWidget {
  const _PasskeyPanel({
    super.key,
    required this.intro,
    required this.submit,
    required this.busy,
    required this.ceremony,
    required this.onSubmit,
  });

  final String intro;
  final String submit;
  final bool busy;
  final Future<String> Function() ceremony;
  final ValueChanged<String> onSubmit;

  @override
  State<_PasskeyPanel> createState() => _PasskeyPanelState();
}

class _PasskeyPanelState extends State<_PasskeyPanel> {
  bool _prompting = false;
  bool _failed = false;

  Future<void> _start() async {
    setState(() {
      _prompting = true;
      _failed = false;
    });
    String? submission;
    try {
      submission = await widget.ceremony();
    } on TomWebAuthnPlatformException catch (error) {
      tomLog.info('Passkey ceremony did not complete: ${error.message}');
    }
    if (!mounted) return;
    setState(() {
      _prompting = false;
      _failed = submission == null;
    });
    // Handed on outside setState: the flow's own state change follows, and
    // a wrong answer comes back through its error line like any other.
    if (submission != null) widget.onSubmit(submission);
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy || _prompting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TomText(text: Tom2FATexts.text(widget.intro)),
        if (_failed) ...[
          const SizedBox(height: 8),
          TomText(
            key: const Key('tom-2fa-webauthn-failed'),
            text: Tom2FATexts.text(Tom2FATexts.webauthnFailed),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        TomFilledButton(
          key: const Key('tom-2fa-webauthn-submit'),
          onPressed: busy ? null : _start,
          child: TomText(text: Tom2FATexts.text(widget.submit)),
        ),
      ],
    );
  }
}
