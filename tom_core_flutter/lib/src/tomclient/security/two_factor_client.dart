/// The client half of the pluggable second-factor design: a registry of
/// mechanism-specific *panels*, keyed by the same mechanism string the server
/// dispatches on.
///
/// ## Why the client needs a registry at all
///
/// The server's 2FA design is deliberately open: an adaptor owns generating a
/// challenge, verifying an answer, and beginning an enrolment, and the framework
/// passes an opaque `clientData` map through untouched precisely so a new
/// mechanism can ship without the framework learning about it. That contract is
/// only half kept if the *client* still has to grow an `if (type == 'sms')`
/// somewhere. So the client mirrors it: one [Tom2FAClientMechanism] per
/// mechanism, each knowing how to render its own two moments —
///
/// * **enrolment** — "here is the factor you are setting up" (for TOTP: the QR
///   code and the base32 string, plus a confirmation field), and
/// * **challenge** — "prove you hold it" (for TOTP: a six-digit field, sized
///   from what the challenge itself declared).
///
/// Everything *around* those two panels — choosing a mechanism, the skip
/// affordance, error display, the submit button, the calls to the server — is
/// identical for every mechanism and belongs to the framework, not to the
/// mechanism. That split is what [Tom2FAFlowPanel] implements above this file.
///
/// ## What a mechanism may and may not assume
///
/// A mechanism receives the decoded `clientData` and nothing else about the
/// login: no principal, no tokens, no backend handle. It renders, it validates
/// locally if it can, and it hands a string back through the context's
/// `onSubmit`. Whether that string travels as a confirmation or as a challenge
/// answer, and what happens to the token pair afterwards, is the flow's
/// business. A mechanism that reached for a token would be re-implementing the
/// choreography the framework already owns (C-15).
///
/// ## Registration
///
/// The TOTP mechanism installs itself when the flow first builds
/// (`Tom2FAFlowPanel.registerBuiltInMechanisms`), so an application gets it
/// without wiring. Anything else registers at start-up:
///
/// ```dart
/// Tom2FAClientRegistry.register(SmsClientMechanism());
/// ```
///
/// Registering before the first flow build also *replaces* a built-in, which is
/// how an application substitutes its own TOTP panel: the flow only installs a
/// mechanism nothing is registered under.
library;

import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// What a mechanism's **enrolment** panel is given to render itself.
///
/// A value rather than a bag of positional parameters so that adding a field
/// later (a "resend" affordance, say) does not break every mechanism that ever
/// shipped.
class Tom2FAEnrolmentPanelContext {
  /// The mechanism key this panel belongs to — passed so one class can serve
  /// several closely-related mechanisms if it wants to.
  final String type;

  /// The mechanism's own enrolment payload, decoded from the interim token's
  /// public claims. For TOTP: `secret`, `otpauthUri`, `digits`, `periodSeconds`.
  final Map<String, Object?> clientData;

  /// The account label to show alongside the factor being set up — typically
  /// the username the login was started with. May be empty.
  final String accountLabel;

  /// Called with whatever the user typed to confirm the factor.
  ///
  /// The panel does *not* decide what happens next: the flow posts it, handles
  /// the refusal, and re-renders. A panel that awaited a result here would be
  /// owning the error presentation the flow already owns.
  final ValueChanged<String> onSubmit;

  /// Whether the flow is mid-call. Panels disable their controls on this rather
  /// than tracking a "busy" flag of their own.
  final bool busy;

  /// Creates the context handed to an enrolment panel builder.
  const Tom2FAEnrolmentPanelContext({
    required this.type,
    required this.clientData,
    required this.onSubmit,
    this.accountLabel = '',
    this.busy = false,
  });
}

/// What a mechanism's **challenge** panel is given to render itself.
///
/// The sibling of [Tom2FAEnrolmentPanelContext] — same shape, one step later in
/// the story, plus the attempt budget the user is spending.
class Tom2FAChallengePanelContext {
  /// The mechanism key this panel belongs to.
  final String type;

  /// The mechanism's opaque challenge payload. For TOTP: `digits`.
  final Map<String, Object?> clientData;

  /// A short, displayable hint the mechanism supplied (a masked phone number,
  /// say). Empty when the mechanism has nothing useful to show.
  final String hint;

  /// How many verification attempts remain before the challenge is burned.
  final int attemptsRemaining;

  /// Called with the code the user entered.
  final ValueChanged<String> onSubmit;

  /// Whether the flow is mid-call.
  final bool busy;

  /// Creates the context handed to a challenge panel builder.
  const Tom2FAChallengePanelContext({
    required this.type,
    required this.clientData,
    required this.onSubmit,
    this.hint = '',
    this.attemptsRemaining = 0,
    this.busy = false,
  });
}

/// One mechanism's client-side rendering, registered under its mechanism key.
///
/// The client mirror of the server's 2FA adaptor: the server knows how to
/// *generate and verify* the factor, this knows how to *show* it. The pairing
/// is by [type] alone — neither side imports the other — which is what lets a
/// mechanism ship as a package that adds a server adaptor and a client
/// mechanism and touches no framework file.
abstract class Tom2FAClientMechanism {
  /// Creates a mechanism registered under [type].
  const Tom2FAClientMechanism(this.type);

  /// The mechanism key, matching the server adaptor's (e.g. `'totp'`).
  final String type;

  /// Renders the panel that walks the user through setting the factor up.
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  );

  /// Renders the panel that asks the user to answer a challenge.
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  );

  /// The mechanism's catalog entry for the chooser — its label, description and
  /// icon, all as resource keys (G-RES-1).
  ///
  /// Defaults to the `two_factor.<type>.*` convention the server's descriptors
  /// follow, so a mechanism that keeps to the convention says nothing here and
  /// one that cannot (a vendor SDK whose strings ship under another prefix)
  /// overrides in one place.
  Tom2FAMethodDescriptor get descriptor =>
      Tom2FAMethodDescriptor.scoped(type);
}

/// The mechanism catalog the second-factor flow dispatches through.
///
/// A process-wide registry rather than an injected collaborator for the same
/// reason [TomAuthorization]'s adapter is: it is consulted from inside widget
/// builds, several levels below whoever configured it, and threading it down
/// would put a parameter on every panel for a value that is the same everywhere
/// in the process.
class Tom2FAClientRegistry {
  Tom2FAClientRegistry._();

  static final Map<String, Tom2FAClientMechanism> _mechanisms = {};

  /// Registers [mechanism], replacing any previous entry for its
  /// [Tom2FAClientMechanism.type].
  ///
  /// Replacing rather than rejecting: an application that wants a different
  /// TOTP panel than the shipped one should get it by registering, not by
  /// having to unregister first.
  static void register(Tom2FAClientMechanism mechanism) {
    _mechanisms[mechanism.type] = mechanism;
  }

  /// The mechanism registered under [type], or `null` when none is.
  ///
  /// Nullable rather than throwing because "the server offered a mechanism this
  /// build cannot render" is a real deployment state — a server upgraded ahead
  /// of its clients — and the flow's answer is to omit that entry from the
  /// chooser, not to crash the login screen.
  static Tom2FAClientMechanism? find(String type) => _mechanisms[type];

  /// Whether a mechanism is registered under [type].
  static bool has(String type) => _mechanisms.containsKey(type);

  /// Every registered mechanism key.
  static Iterable<String> get types => _mechanisms.keys;

  /// Drops every registration, including the built-ins.
  ///
  /// For tests that need to assert what the flow does with an unrenderable
  /// mechanism. Production code has no reason to call it.
  @visibleForTesting
  static void reset() => _mechanisms.clear();
}
