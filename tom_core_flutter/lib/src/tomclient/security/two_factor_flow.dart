/// The framework-owned second-factor flow: everything about enrolling in and
/// answering a second factor that is the *same* whichever mechanism is in play.
///
/// ## What this owns, and what it deliberately does not
///
/// A second-factor login has a fixed shape. The server offers a set of
/// mechanisms; the user picks one; the chosen mechanism shows the user
/// something and takes an answer; the answer is posted; a refusal is displayed
/// with one attempt fewer, or the login completes. Sometimes declining is
/// allowed, sometimes it costs a grace login, and sometimes there is no
/// enrolment at all — only a challenge against a factor already held.
///
/// All of that is invariant, and so it lives here: the chooser, the frame
/// around a mechanism's panel, the attempt counter, the error line, the skip
/// affordance and the rule that it appears **only** when the server said so.
/// What is *not* invariant is what a mechanism shows and what counts as an
/// answer — and that lives behind [Tom2FAClientMechanism], one registration per
/// mechanism.
///
/// Nor does this own the **token choreography**. It calls a
/// [Tom2FAFlowController] the application implements over its own auth client,
/// and that client already runs its calls through `tomRunWithAuthRetry` /
/// `AuthorizedHttp`. Re-implementing refresh here would be a second, subtly
/// different copy of the mechanism the framework already ships (C-15) — and it
/// would put HTTP in a widget.
///
/// ## Why a controller rather than a backend handle
///
/// The framework cannot call the enrolment endpoints itself: there is no
/// framework-wide auth API contract, because each deployment's auth service
/// owns its own DTOs. What *is* universal is the set of moves — choose,
/// confirm, skip, answer, cancel — so that is what the seam is. Five methods
/// and two pieces of read-only state, which an application implements in a
/// dozen lines over the auth client it already has.
///
/// ## Using it
///
/// ```dart
/// if (session.needsSecondFactor) {
///   return Tom2FAFlowPanel(controller: MyFlowController(session));
/// }
/// ```
///
/// The panel renders whichever stop the login is at, reading it from the
/// controller each build — so an application drives it by rebuilding (its
/// session is already a [ChangeNotifier]) rather than by calling into it.
library;

// Material, not widgets: the frame styles its title, error line and footnotes
// from the ambient `Theme`, which lives in material. The mechanism panels below
// stay on `widgets.dart` — they have no such need.
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'two_factor_client.dart';
import 'two_factor_texts.dart';
import 'two_factor_totp_client.dart';
import 'two_factor_webauthn_client.dart';
import 'webauthn_platform.dart';

/// The moves a second-factor login can make, implemented by the application
/// over its own auth client.
///
/// Every method may throw; the panel catches whatever comes back and renders it
/// through [describeError], so an application surfaces its own typed failure
/// without the framework knowing the type.
abstract class Tom2FAFlowController {
  /// The enrolment the login is part-way through, or `null` when none is owed.
  Tom2FAPendingEnrolment? get pendingEnrolment;

  /// The challenge the login is waiting on, or `null` when none is outstanding.
  Tom2FAChallenge? get pendingChallenge;

  /// The mechanism catalog the server sent with the interim result.
  ///
  /// Supplies the chooser's labels. Empty is legitimate — a server that offered
  /// mechanisms but sent no descriptors still gets a usable chooser, built from
  /// the offered keys via [Tom2FAMethodDescriptor.scoped].
  List<Tom2FAMethodDescriptor> get availableMethods => const [];

  /// The account the factor is being set up for, shown beside the QR code.
  /// Empty when the application would rather not display it.
  String get accountLabel => '';

  /// Begins enrolment in the mechanism the user picked.
  Future<void> chooseMethod(String type);

  /// Confirms the half-built factor with the [code] the user entered.
  Future<void> confirmEnrolment(String code);

  /// Declines the offer. Only reachable when the server marked it skippable —
  /// the panel does not render the affordance otherwise, so an implementation
  /// may treat a call it did not expect as a programming error.
  Future<void> skipEnrolment();

  /// Answers the outstanding challenge with [code].
  Future<void> submitSecondFactor(String code);

  /// Abandons the flow and returns to the credentials screen.
  void cancel();

  /// Turns a failure thrown by any of the above into a displayable message.
  ///
  /// Defaults to the error's own description, which is the right default for a
  /// typed exception whose `toString` is already a message and the wrong one
  /// for anything else — hence the override point.
  String describeError(Object error) => '$error';
}

/// Renders whichever stop of the second-factor flow [controller] reports.
///
/// Stateless with respect to the *login*: the flow's position is read from the
/// controller on every build, and the only state held here is what belongs to
/// the widget — whether a call is in flight and what the last failure said.
/// That is what lets an application drive the panel by rebuilding, and what
/// stops the panel and the session disagreeing about where the login is.
class Tom2FAFlowPanel extends StatefulWidget {
  /// Creates the flow panel over [controller].
  const Tom2FAFlowPanel({super.key, required this.controller});

  /// The seam to the application's auth client.
  final Tom2FAFlowController controller;

  /// Registers the mechanisms the framework ships with: TOTP always, passkeys
  /// where [TomWebAuthnPlatform.instance] reports a platform authenticator.
  ///
  /// Called by the panel itself, so an application gets TOTP without wiring —
  /// a framework whose one built-in mechanism required three lines of set-up
  /// would be advertising an extension point while charging rent on the common
  /// case. Idempotent, and it never overwrites a mechanism an application
  /// registered under the same key first.
  static void registerBuiltInMechanisms() {
    if (!Tom2FAClientRegistry.has(TomTotp2FAClientMechanism.mechanismType)) {
      Tom2FAClientRegistry.register(const TomTotp2FAClientMechanism());
    }
    // A target with no authenticator leaves the key unregistered, so the
    // chooser omits passkeys and a challenge for one reads as unrenderable
    // rather than opening a button that can only fail.
    if (TomWebAuthnPlatform.instance.isAvailable &&
        !Tom2FAClientRegistry.has(
          TomWebAuthn2FAClientMechanism.mechanismType,
        )) {
      Tom2FAClientRegistry.register(const TomWebAuthn2FAClientMechanism());
    }
  }

  @override
  State<Tom2FAFlowPanel> createState() => _Tom2FAFlowPanelState();
}

class _Tom2FAFlowPanelState extends State<Tom2FAFlowPanel> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Tom2FAFlowPanel.registerBuiltInMechanisms();
  }

  /// Runs one controller move, owning the busy flag and the error line so no
  /// mechanism panel has to.
  Future<void> _run(Future<void> Function() move) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await move();
    } catch (e) {
      if (mounted) setState(() => _error = widget.controller.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final challenge = controller.pendingChallenge;
    // A challenge outranks an enrolment: a principal who both holds a factor
    // and owes a new one must prove the one they have before setting up
    // another, or enrolment would be a way around the factor it is meant to
    // strengthen.
    if (challenge != null) return _challengeStop(context, challenge);

    final enrolment = controller.pendingEnrolment;
    if (enrolment == null) return const SizedBox.shrink();
    return enrolment.hasOffer
        ? _enrolmentStop(context, enrolment)
        : _chooserStop(context, enrolment);
  }

  // --- Stop 1: choose a mechanism ---------------------------------------

  Widget _chooserStop(BuildContext context, Tom2FAPendingEnrolment enrolment) {
    // Only mechanisms this build can actually render: a server upgraded ahead
    // of its clients offers keys we have no panel for, and listing one would
    // strand the user on a blank step they cannot back out of.
    final renderable = enrolment.offeredTypes
        .where(Tom2FAClientRegistry.has)
        .toList();

    if (renderable.isEmpty) {
      return _frame(
        context,
        key: const Key('tom-2fa-chooser'),
        title: Tom2FATexts.text(Tom2FATexts.chooseTitle),
        children: [
          TomText(
            key: const Key('tom-2fa-no-methods'),
            text: Tom2FATexts.text(Tom2FATexts.noRenderableMethods),
          ),
        ],
        enrolment: enrolment,
      );
    }

    return _frame(
      context,
      key: const Key('tom-2fa-chooser'),
      title: Tom2FATexts.text(Tom2FATexts.chooseTitle),
      enrolment: enrolment,
      children: [
        TomText(text: Tom2FATexts.text(Tom2FATexts.chooseIntro)),
        const SizedBox(height: 12),
        for (final type in renderable) _methodTile(type),
      ],
    );
  }

  /// One row of the chooser, labelled entirely from resource keys (G-RES-5).
  ///
  /// The descriptor is the server's when it sent one and the scoped default
  /// otherwise — so a mechanism keeping to the `two_factor.<type>.*` convention
  /// is labelled correctly whether or not its server bothered to describe it.
  ///
  /// All three of the descriptor's keys are rendered: the label, the
  /// description and the icon.
  Widget _methodTile(String type) {
    final descriptor = widget.controller.availableMethods.firstWhere(
      (d) => d.type == type,
      orElse: () => Tom2FAMethodDescriptor.scoped(type),
    );
    return TomListTile(
      key: Key('tom-2fa-method-$type'),
      leading: _methodIcon(descriptor),
      // `titleText`, not a `title` widget: the label is text, and the text form
      // is the one the tile styles from the ambient list-tile theme.
      titleText: Tom2FATexts.text(descriptor.displayNameKey),
      subtitle: TomText(text: Tom2FATexts.text(descriptor.descriptionKey)),
      enabled: !_busy,
      onTap: _busy
          ? null
          : () => _run(() => widget.controller.chooseMethod(type)),
    );
  }

  /// The descriptor's icon, or null when this build cannot produce one.
  ///
  /// Two steps, which is the convention `tom_flutter_ui` uses throughout:
  /// [Tom2FAMethodDescriptor.iconKey] resolves through the text bundle to an
  /// icon *name* (`mSecurity`), and [TomUIIcons] maps that name to an
  /// [IconData]. The key names an icon rather than pointing at an asset
  /// precisely so that each client tier can answer it in its own vocabulary —
  /// this tier's answer is the adapter an application installs at start-up.
  ///
  /// Null at any step, and null is a perfectly ordinary outcome rather than a
  /// misconfiguration: a bundle that never mentions icons, an application that
  /// installs no adapter, or a mechanism whose icon that adapter does not carry
  /// all land here. The row then renders without a leading slot and loses
  /// nothing else, so the icon is an enhancement and never a requirement.
  ///
  /// This is also why a missing key cannot leak the way missing text does.
  /// [TomTextResourceProvider] answers an unknown key with the key itself,
  /// which is deliberately conspicuous on a label — but `two_factor.sms.icon`
  /// is not an icon name, so it resolves to null and shows nothing at all.
  Widget? _methodIcon(Tom2FAMethodDescriptor descriptor) {
    final icon = TomUIIcons.resolveIcon(Tom2FATexts.text(descriptor.iconKey));
    return icon == null ? null : Icon(icon);
  }

  // --- Stop 2: set the chosen mechanism up ------------------------------

  Widget _enrolmentStop(
    BuildContext context,
    Tom2FAPendingEnrolment enrolment,
  ) {
    final mechanism = Tom2FAClientRegistry.find(enrolment.type);
    return _frame(
      context,
      key: const Key('tom-2fa-enrolment'),
      title: Tom2FATexts.text(Tom2FATexts.enrolTitle),
      enrolment: enrolment,
      children: [
        if (enrolment.isExpired()) ...[
          _expiryNotice(
            const Key('tom-2fa-enrolment-expired'),
            Tom2FATexts.enrolmentExpired,
          ),
          const SizedBox(height: 12),
        ],
        if (mechanism == null)
          TomText(
            key: const Key('tom-2fa-no-methods'),
            text: Tom2FATexts.text(Tom2FATexts.noRenderableMethods),
          )
        else
          mechanism.buildEnrolmentPanel(
            context,
            Tom2FAEnrolmentPanelContext(
              type: enrolment.type,
              clientData: enrolment.clientData,
              accountLabel: widget.controller.accountLabel,
              busy: _busy,
              onSubmit: (code) =>
                  _run(() => widget.controller.confirmEnrolment(code)),
            ),
          ),
        if (enrolment.attemptsAllowed > 0) ...[
          const SizedBox(height: 12),
          _attemptsLine(enrolment.attemptsRemaining),
        ],
      ],
    );
  }

  // --- Stop 3: answer the challenge -------------------------------------

  Widget _challengeStop(BuildContext context, Tom2FAChallenge challenge) {
    final mechanism = Tom2FAClientRegistry.find(challenge.type);

    // A challenge has nothing to filter. The chooser can drop a mechanism this
    // build cannot render and offer the rest; here the server is holding one
    // outstanding challenge, of one type, and there is no alternative to switch
    // to. The state is a client behind its server — a principal enrolled
    // through a newer build, signing in from an older one — and it is not
    // recoverable on this side, which is why the message names the version gap
    // instead of borrowing the chooser's, which is about setting a factor *up*.
    if (mechanism == null) {
      return _frame(
        context,
        key: const Key('tom-2fa-challenge'),
        title: Tom2FATexts.text(Tom2FATexts.challengeTitle),
        children: [
          TomText(
            key: const Key('tom-2fa-unrenderable-challenge'),
            text: Tom2FATexts.text(Tom2FATexts.unrenderableChallenge),
          ),
        ],
      );
    }

    return _frame(
      context,
      key: const Key('tom-2fa-challenge'),
      title: Tom2FATexts.text(Tom2FATexts.challengeTitle),
      children: [
        if (challenge.isExpired()) ...[
          _expiryNotice(
            const Key('tom-2fa-challenge-expired'),
            Tom2FATexts.challengeExpired,
          ),
          const SizedBox(height: 12),
        ],
        mechanism.buildChallengePanel(
          context,
          Tom2FAChallengePanelContext(
            type: challenge.type,
            clientData: challenge.clientData,
            hint: challenge.hint,
            attemptsRemaining: challenge.attemptsRemaining,
            busy: _busy,
            onSubmit: (code) =>
                _run(() => widget.controller.submitSecondFactor(code)),
          ),
        ),
        const SizedBox(height: 12),
        // Only beside a panel that can spend one. An attempt budget printed
        // under a message saying no attempt can be made counts down something
        // the user has no way to use.
        _attemptsLine(challenge.attemptsRemaining),
      ],
    );
  }

  // --- The shared frame --------------------------------------------------

  /// The chrome every stop shares: title, the stop's own body, the error line,
  /// and the two exits (skip, when permitted, and cancel).
  Widget _frame(
    BuildContext context, {
    required Key key,
    required String title,
    required List<Widget> children,
    Tom2FAPendingEnrolment? enrolment,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TomText(
          key: const Key('tom-2fa-title'),
          text: title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...children,
        if (_error != null) ...[
          const SizedBox(height: 12),
          TomText(
            key: const Key('tom-2fa-error'),
            text: _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        // The skip affordance exists only because the *server* said declining
        // is permitted — never because the client thinks it should be on offer.
        // Rendering it on any other basis would put the policy decision on the
        // side of the wire that does not get to make it.
        if (enrolment != null && enrolment.skippable) ...[
          const SizedBox(height: 12),
          TomTextButton(
            key: const Key('tom-2fa-skip'),
            onPressed: _busy
                ? null
                : () => _run(widget.controller.skipEnrolment),
            child: TomText(text: Tom2FATexts.text(Tom2FATexts.skip)),
          ),
          if (enrolment.skipSpendsGrace)
            TomText(
              key: const Key('tom-2fa-skip-cost'),
              text: Tom2FATexts.text(Tom2FATexts.skipSpendsGrace),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        const SizedBox(height: 4),
        TomTextButton(
          key: const Key('tom-2fa-cancel'),
          onPressed: _busy ? null : widget.controller.cancel,
          child: TomText(text: Tom2FATexts.text(Tom2FATexts.cancel)),
        ),
      ],
    );
  }

  /// The line shown above a panel whose deadline has passed.
  ///
  /// **A notice, not a refusal.** The panel stays, the submit button stays, and
  /// the server decides what it will accept. `expiresAt` is an absolute instant
  /// the server issued, and the comparison against it is only as good as *this*
  /// device's clock: a client running ten minutes fast would find every
  /// challenge expired on arrival, and a flow that hid the panel on its own
  /// verdict would lock that user out of a login the server was still willing
  /// to complete. Nothing on this side tolerates skew — the deadline is a hard
  /// one with no window — so the client says what it believes and lets the
  /// authority answer.
  ///
  /// What it removes is the same thing the unrenderable-challenge line removes:
  /// a refusal that would otherwise arrive with no explanation, as late as it
  /// possibly can, after the user has scanned a code and typed one in.
  Widget _expiryNotice(Key key, String textKey) => TomText(
    key: key,
    text: Tom2FATexts.text(textKey),
    style: Theme.of(context).textTheme.bodySmall,
  );

  Widget _attemptsLine(int remaining) => TomText(
    key: const Key('tom-2fa-attempts'),
    text: Tom2FATexts.textWith(
      Tom2FATexts.attemptsRemaining,
      'count',
      remaining,
    ),
    style: Theme.of(context).textTheme.bodySmall,
  );
}
