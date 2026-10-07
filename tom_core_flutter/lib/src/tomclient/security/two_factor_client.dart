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
/// — and `'sms'` here is an illustration, not a factor this package provides;
/// see "What the framework ships, and what it does not" below
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
/// **No credential material reaches a panel.** A mechanism gets the decoded
/// `clientData` and nothing else about the login: no principal, no tokens, no
/// backend handle. It renders, it validates locally if it can, and it hands a
/// string back through the context's `onSubmit`. Whether that string travels as
/// a confirmation or as a challenge answer, and what happens to the token pair
/// afterwards, is the flow's business. A mechanism that reached for a token
/// would be re-implementing the choreography the framework already owns (C-15).
///
/// That rule is about *credentials*, and it is worth separating from the
/// question it is often mistaken for: what the **application** may show a panel.
/// A device name beside a WebAuthn prompt, a tenant that disambiguates an
/// account, a brand — none of those is credential material, and the framework
/// has no objection to them in principle.
///
/// **They arrive as named fields on the context, supplied by the controller.**
/// [Tom2FAEnrolmentPanelContext.accountLabel] is the first and so far the only
/// one; it was added because a user with three work accounts in one
/// authenticator cannot tell which of three identical QR codes they are
/// scanning. The next such need adds the next named field, which is why the
/// contexts are values rather than positional parameters — a field added later
/// breaks no mechanism that ever shipped.
///
/// Two shapes were considered for the general case and declined:
///
/// - **An untyped `applicationData` map on both contexts.** One change would
///   cover every future case, at the cost of a bag whose contents no reader can
///   discover from the type. There is already one opaque map on this path — the
///   server's `clientData` — and a second, with different provenance, is how the
///   two come to be confused about which end owns what.
/// - **Routing it through the server.** Putting an application's presentation
///   data in `clientData` means putting it on the wire and through an adaptor
///   whose job is the factor rather than the UI.
///
/// The challenge context carries no application-supplied field at all. Not a
/// prohibition — a challenge screen naming the account it is for would be as
/// useful as an enrolment screen doing so — but nothing has asked, and the
/// discipline is that each field arrives with the case that needs it.
///
/// ## What the framework ships, and what it does not
///
/// **Two client mechanisms are in the box.** `TomTotp2FAClientMechanism`
/// everywhere, and `TomWebAuthn2FAClientMechanism` (passkeys) where
/// `TomWebAuthnPlatform.instance` reports a platform authenticator — on the
/// web. The flow installs both for you.
///
/// The server ships more: `tom_core_server` also registers the delivered-code
/// `email` and `sms` adaptors, each offered once its delivery service is
/// installed. For those two the missing half is this one — a code field, a
/// confirm step at enrolment, and the masked destination the server sends as
/// `hint`. A deployment that offers them writes the mechanism and registers it;
/// until then the enrolment chooser leaves the key out. The
/// `if (type == 'sms')` above and the `SmsClientMechanism()` below are that
/// mechanism.
///
/// The SMS panel is not shipped on purpose. SMS is the weakest of the common
/// factors and the dearest to run, so registering its client mechanism is the
/// explicit step by which a deployment chooses to offer it, and the framework
/// does not take that step for it.
///
/// ## Registration
///
/// The TOTP mechanism installs itself when the flow first builds
/// (`Tom2FAFlowPanel.registerBuiltInMechanisms`), so an application gets it
/// without wiring. Anything else — including the `SmsClientMechanism` below,
/// which an application writes — registers at start-up:
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
  /// public claims. For TOTP: `secret`, `otpauthUri`, `digits` and
  /// `periodSeconds` — the shipped panel reads the first three and ignores the
  /// last.
  final Map<String, Object?> clientData;

  /// The account label to show alongside the factor being set up — typically
  /// the username the login was started with. May be empty.
  ///
  /// The one value the **application** supplies to a panel, through
  /// `Tom2FAFlowController.accountLabel`. Everything else here comes from the
  /// server's offer or from the flow. See the library documentation for why
  /// that channel is a named field rather than a map, and why the challenge
  /// context has no equivalent yet.
  final String accountLabel;

  /// Called with what the mechanism collected to confirm the factor — the
  /// code a user typed for TOTP, the authenticator's encoded response for a
  /// passkey.
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
///
/// It carries **nothing the application supplied**, where the enrolment context
/// carries [Tom2FAEnrolmentPanelContext.accountLabel]. That asymmetry is an
/// absence of demand rather than a rule: a challenge screen naming the account
/// it is for would be as useful, and adding the field is one line here and one
/// in the flow. It is not added on the chance, because a field nobody asked for
/// is a field nobody can say what belongs in.
class Tom2FAChallengePanelContext {
  /// The mechanism key this panel belongs to.
  final String type;

  /// The mechanism's opaque challenge payload. For TOTP: `digits` and
  /// `periodSeconds` — the shipped panel reads the first and ignores the
  /// second.
  final Map<String, Object?> clientData;

  /// A short, displayable hint the mechanism supplied (a masked phone number,
  /// say). Empty when the mechanism has nothing useful to show.
  ///
  /// **No shipped client mechanism renders this.** TOTP is the only one in the
  /// box and it has nothing to hint: the user reads the code off the device
  /// already in their hand, so naming where it came from tells them nothing.
  /// The field earns its place with the delivered-code factors — the server's
  /// `email` and `sms` adaptors fill it with the masked destination, and "we
  /// sent it to ••••4417" is the difference between waiting and giving up on
  /// the wrong phone.
  ///
  /// So the framework's half of the contract is delivery, not display: the flow
  /// hands on whatever the server sent, and it arrives as an empty string
  /// rather than null so a panel can render it without a null check. That half
  /// is held by `test/two_factor_client_test.dart`, whose test-only SMS
  /// mechanism reads it — otherwise the first mechanism that needed the hint
  /// would be the one to discover it never arrived.
  final String hint;

  /// How many verification attempts remain before the challenge is burned.
  final int attemptsRemaining;

  /// Called with what the mechanism collected — a typed code, or a passkey's
  /// encoded response.
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
  /// icon, all as resource keys (G-RES-1). The chooser renders all three.
  ///
  /// Defaults to the `two_factor.<type>.*` convention the server's descriptors
  /// follow, so a mechanism that keeps to the convention says nothing here and
  /// one that cannot (a vendor SDK whose strings ship under another prefix)
  /// overrides in one place.
  ///
  /// The icon resolves in two steps, the convention `tom_flutter_ui` uses
  /// throughout: the key resolves through the text bundle to an icon *name*
  /// (`mSecurity`), and the application's `TomUIIcons` adapter maps that name
  /// to something drawable. A mechanism that wants an icon therefore ships a
  /// bundle entry, not an asset — which is what lets the same descriptor serve
  /// a Flutter client and a web one without knowing which is asking.
  ///
  /// Only the label and the description are load-bearing. A build with no icon
  /// bundle entry, or no adapter installed, renders the row without a leading
  /// icon and loses nothing else.
  Tom2FAMethodDescriptor get descriptor => Tom2FAMethodDescriptor.scoped(type);
}

/// The mechanism catalog the second-factor flow dispatches through.
///
/// A process-wide registry rather than an injected collaborator for the same
/// reason [TomAuthorization]'s adapter is: it is consulted from inside widget
/// builds, several levels below whoever configured it, and threading it down
/// would put a parameter on every panel for a value that is the same everywhere
/// in the process.
///
/// ## Register at start-up
///
/// Nothing bounds *when* [register] may be called, and nothing needs to for a
/// normal application: register before the first [Tom2FAFlowPanel] is built and
/// the question never arises. What is worth knowing is what happens if you do
/// not, because the registry is not sealed and will not complain.
///
/// [Tom2FAFlowPanel] resolves the mechanism on **every build**, so a
/// registration made while a flow is on screen takes effect on the next frame.
/// Whether the user notices depends on what the replacement renders:
///
/// - **A different panel widget takes the screen over**, and the state of the
///   one it replaced — including the [TextEditingController] holding whatever
///   was typed — goes with it. Flutter disposes the old element when the
///   widget type under a slot changes.
/// - **A replacement that renders the same panel keeps it.** An application
///   that wraps or subclasses the shipped panel changes the mechanism object
///   and not the widget type, so the element is reused and the typing survives.
///   That is the likelier replacement, which is why this is a caveat rather
///   than a prohibition.
///
/// So the rule is about the *shape* of a late replacement, not about
/// replacement itself. Registering a differently-shaped panel during a live
/// flow is the one case that costs a user something, and no shipped path does
/// it — [Tom2FAFlowPanel.registerBuiltInMechanisms] runs in `initState`, before
/// the first build, and never overwrites an application's entry.
///
/// Sealing the registry after the first flow build was considered and declined:
/// it would forbid a legitimate late registration — a mechanism arriving from a
/// plugin loaded after the login screen is up — to prevent a misuse nobody has
/// committed.
class Tom2FAClientRegistry {
  Tom2FAClientRegistry._();

  static final Map<String, Tom2FAClientMechanism> _mechanisms = {};

  /// Registers [mechanism], replacing any previous entry for its
  /// [Tom2FAClientMechanism.type].
  ///
  /// Replacing rather than rejecting: an application that wants a different
  /// TOTP panel than the shipped one should get it by registering, not by
  /// having to unregister first.
  ///
  /// **A start-up call.** It is accepted at any time and takes effect on the
  /// next frame, so a replacement made during a live flow that renders a
  /// *different* panel widget discards what the user had typed into the old
  /// one. See the class documentation for when that happens and when it does
  /// not.
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
