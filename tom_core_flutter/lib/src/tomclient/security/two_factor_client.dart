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
/// without wiring. Anything else arrives one of two ways.
///
/// **Annotated**, which needs no start-up code at all and is what makes the
/// "ships as a package" promise above true on both tiers:
///
/// ```dart
/// @tomReflector
/// @TomClient2FAAdaptor('sms')
/// class SmsClientMechanism extends Tom2FAClientMechanism { /* ... */ }
/// ```
///
/// [Tom2FAClientRegistry] scans the reflected program the first time anything
/// reads it and registers every annotated mechanism it finds.
///
/// **Registered**, for a mechanism that cannot be built by an argument-free
/// constructor, or in an application that does not run the reflection
/// generator:
///
/// ```dart
/// Tom2FAClientRegistry.register(SmsClientMechanism(smsGateway));
/// ```
///
/// Registering also *replaces*, which is how an application substitutes its own
/// TOTP panel: the flow only installs a mechanism nothing is registered under,
/// and the scan skips a key an explicit registration already holds.
library;

import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/client_exceptions.dart';
import 'authentication.dart';

/// A failure raised while assembling the client's second-factor mechanisms.
///
/// A thin semantic subtype of [TomClientException] so a caller can tell a 2FA
/// wiring failure from any other client-side error with one `is` check. Every
/// instance comes from the annotation scan, and the `key` is a stable dotted
/// code — `two_factor_client.adaptor_type_mismatch`,
/// `two_factor_client.duplicate_adaptor` — so a caller branches on the code
/// rather than on message text.
///
/// There is deliberately no failure for "no mechanism is registered for this
/// key". That is not a wiring error but a real deployment state — a server
/// upgraded ahead of its clients — and the flow's answer is to omit the entry
/// from the chooser, which is why [Tom2FAClientRegistry.find] returns null
/// instead.
class Tom2FAClientException extends TomClientException {
  /// Creates a client 2FA exception. See [TomException] for the meaning of each
  /// argument.
  Tom2FAClientException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

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

  /// The mechanism's opaque challenge payload. For TOTP: `digits` and
  /// `periodSeconds` — the shipped panel reads the first and ignores the
  /// second.
  final Map<String, Object?> clientData;

  /// A short, displayable hint the mechanism supplied (a masked phone number,
  /// say). Empty when the mechanism has nothing useful to show.
  ///
  /// **No shipped mechanism renders this.** TOTP is the only one in the box and
  /// it has nothing to hint: the user reads the code off the device already in
  /// their hand, so naming where it came from tells them nothing. The field
  /// earns its place with the mechanisms that are not shipped — SMS and email
  /// deliver the code *somewhere*, and "we sent it to ••••4417" is the
  /// difference between waiting and giving up on the wrong phone.
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
class Tom2FAClientRegistry {
  Tom2FAClientRegistry._();

  static final Map<String, Tom2FAClientMechanism> _mechanisms = {};

  /// Whether the annotation scan has completed *successfully*.
  ///
  /// Only a successful scan is remembered. A scan that could not run, or that
  /// threw, leaves this false so the next access tries again — see
  /// [_ensureScanned].
  static bool _scanned = false;

  /// Whether a scan is on the stack right now, so a re-entrant access does not
  /// start a second one. Distinct from [_scanned], which means *finished*.
  static bool _scanning = false;

  /// Whether the "nothing to scan" diagnostic has already been emitted for this
  /// registry lifetime.
  static bool _scanSkipLogged = false;

  /// Registers [mechanism], replacing any previous entry for its
  /// [Tom2FAClientMechanism.type].
  ///
  /// Replacing rather than rejecting: an application that wants a different
  /// TOTP panel than the shipped one should get it by registering, not by
  /// having to unregister first. That is also why an explicit registration
  /// **beats** a discovered one (see [registerAnnotated]): calling this is a
  /// decision already taken, and the scan does not get to undo it.
  ///
  /// Registering does not run the scan. A write is not a read, and scanning
  /// here would put the discovered mechanism in the map *before* the explicit
  /// one, leaving "explicit wins" to depend on the order the two happened to
  /// arrive in.
  static void register(Tom2FAClientMechanism mechanism) {
    _mechanisms[mechanism.type] = mechanism;
  }

  /// The mechanism registered under [type], or `null` when none is.
  ///
  /// Nullable rather than throwing because "the server offered a mechanism this
  /// build cannot render" is a real deployment state — a server upgraded ahead
  /// of its clients — and the flow's answer is to omit that entry from the
  /// chooser, not to crash the login screen.
  static Tom2FAClientMechanism? find(String type) {
    _ensureScanned();
    return _mechanisms[type];
  }

  /// Whether a mechanism is registered under [type].
  static bool has(String type) {
    _ensureScanned();
    return _mechanisms.containsKey(type);
  }

  /// Every registered mechanism key.
  static Iterable<String> get types {
    _ensureScanned();
    return _mechanisms.keys;
  }

  /// Drops every registration, including the built-ins, and re-arms the scan.
  ///
  /// For tests that need to assert what the flow does with an unrenderable
  /// mechanism. Production code has no reason to call it.
  ///
  /// The scan flag is cleared with the map, not left standing: a reset that
  /// dropped the registrations but remembered the scan would leave a
  /// permanently empty registry, which is the failure mode hardest to
  /// recognise from the outside.
  ///
  /// The *log* latch is deliberately left standing, because it counts consoles
  /// rather than registries. A suite that resets between cases would otherwise
  /// repeat the "no generated reflection" line once per test — which is the
  /// noise the latch exists to prevent, arriving by the one route that clears
  /// it.
  @visibleForTesting
  static void reset() {
    _mechanisms.clear();
    _scanned = false;
  }

  /// Runs the annotation scan once, on first read.
  ///
  /// "Once" means once *successfully*. A scan that could not run leaves the
  /// registry unarmed, so the next access tries again: the reflector is
  /// initialised by generated code at some point during start-up, and whatever
  /// touches the registry before that point must not decide the question for
  /// the rest of the process.
  ///
  /// On first *read* rather than on first registration, which is what makes the
  /// precedence rule need no ordering rules of its own:
  /// `Tom2FAFlowPanel.registerBuiltInMechanisms` asks [has] before it installs
  /// the shipped TOTP panel, so the scan has already run by then and an
  /// annotated custom TOTP wins without anybody having to say so.
  static void _ensureScanned() {
    // `_scanning` rather than `_scanned` is what makes this re-entrant-safe: a
    // mechanism whose constructor touches the registry sees the partial map and
    // does not start a second scan, but the scan it interrupted is still the
    // one that gets to record success.
    if (_scanned || _scanning) return;

    final Iterable<ClassMirror> candidates;
    try {
      candidates = tomReflector.annotatedClasses;
    } on StateError {
      // No generated reflection *yet*. Annotation discovery is a convenience on
      // top of [register], not a precondition of it, so an application that
      // registers its mechanisms by hand — which is every application that does
      // not run the reflection generator — must keep working.
      //
      // Said out loud, because a registry holding only the built-in TOTP is
      // otherwise indistinguishable from one whose annotated mechanism was
      // found and rejected. Informational rather than a warning: hand-wiring is
      // supported, and a reflector that arrives later is picked up by the retry
      // this early return leaves armed. Once per lifetime, because reads happen
      // on every build of the flow.
      if (!_scanSkipLogged) {
        _scanSkipLogged = true;
        tomLog.info(
          'Tom2FAClientRegistry: the 2FA mechanism scan found no generated '
          'reflection in this program, so annotated mechanisms were not '
          'discovered. Mechanisms registered by hand still resolve, and the '
          'scan is retried on the next access.',
        );
      }
      return;
    }

    _scanning = true;
    try {
      registerAnnotated(candidates);
    } finally {
      _scanning = false;
    }
    _scanned = true;
  }

  /// Registers every class in [candidates] that carries a [TomClient2FAAdaptor]
  /// annotation and is not already spoken for.
  ///
  /// The automatic scan hands this the reflection registry's own class list. It
  /// is separate from that scan because a candidate set is not always the whole
  /// program: an application that composes its mechanisms from a chosen set of
  /// libraries supplies its own, and the tests for the malformed cases must
  /// supply theirs — a class annotated `@TomClient2FAAdaptor` but unusable
  /// cannot live in a reflected library, because the automatic scan would then
  /// reach it from every other test in the process.
  ///
  /// Three things can be wrong with a candidate, and all three throw
  /// [Tom2FAClientException] naming the class and the mechanism it claimed: it
  /// cannot be constructed, it is not a [Tom2FAClientMechanism] at all, or its
  /// own [Tom2FAClientMechanism.type] contradicts the annotation. The last is
  /// what makes the key's appearance in two places safe — the annotation
  /// mirrors the server's `@Tom2FAAdaptor('sms')` idiom, so dropping the field
  /// would break the pairing that lets one mechanism ship both halves, and
  /// trusting one over the other would leave two silently divergent sources of
  /// truth.
  ///
  /// A half-registered registry is not offered as an alternative: a mechanism
  /// set that is wrong is wrong at start-up, not at the login that happens to
  /// need the missing panel. So a failed call registers nothing and leaves
  /// registrations made before it untouched — both halves matter now that a
  /// failed scan is retried, because leftovers from the first attempt would
  /// collide with the second attempt's fresh instances.
  ///
  /// Two candidates claiming one key also throw, which is where this parts
  /// company with [register]: replacing is a decision an application takes on
  /// purpose, whereas two annotations claiming one key is a wiring bug nobody
  /// decided, and picking a winner would make it depend on reflection ordering.
  /// A key an *explicit* registration already holds is the third case and is
  /// **skipped**, silently — that is the documented way to substitute a panel,
  /// and warning about it would make the supported path noisy.
  static void registerAnnotated(Iterable<ClassMirror> candidates) {
    // The map as it stands before the scan: exactly the explicit registrations,
    // which is both what a discovered mechanism must not displace and what a
    // failure must be rolled back to.
    final explicit = Map<String, Tom2FAClientMechanism>.of(_mechanisms);
    // Which candidate claimed which key, so a duplicate can name both classes.
    // Kept apart from the registry because a key skipped in favour of an
    // explicit registration is still claimed, and a second claimant on it is
    // still ambiguous.
    final claims = <String, ClassMirror>{};
    try {
      for (final candidate in candidates) {
        final annotations = candidate.metadata.whereType<TomClient2FAAdaptor>();
        if (annotations.isEmpty) continue;
        final annotation = annotations.first;

        final claimed = claims[annotation.type];
        if (claimed != null) {
          throw Tom2FAClientException(
            'two_factor_client.duplicate_adaptor',
            '2FA mechanism scan: more than one class is annotated '
                '@TomClient2FAAdaptor("${annotation.type}"): '
                '$claimed and $candidate',
            autoLog: true,
          );
        }
        claims[annotation.type] = candidate;

        // Not instantiated at all when the key is already held: the mechanism
        // would be discarded, and constructing something only to throw it away
        // runs whatever its constructor does for no reason.
        if (explicit.containsKey(annotation.type)) continue;

        Object? mechanism;
        try {
          mechanism = candidate.newInstance('', []);
        } catch (error, stack) {
          throw Tom2FAClientException(
            'two_factor_client.adaptor_instantiation_failed',
            '2FA mechanism scan: failed to instantiate $candidate for '
                'mechanism "${annotation.type}"',
            rootException: error,
            stack: stack,
            autoLog: true,
          );
        }
        if (mechanism is! Tom2FAClientMechanism) {
          throw Tom2FAClientException(
            'two_factor_client.adaptor_does_not_implement_mechanism',
            '2FA mechanism scan: $candidate is annotated @TomClient2FAAdaptor('
                '"${annotation.type}") but does not implement '
                'Tom2FAClientMechanism',
            autoLog: true,
          );
        }
        if (mechanism.type != annotation.type) {
          throw Tom2FAClientException(
            'two_factor_client.adaptor_type_mismatch',
            '2FA mechanism scan: $candidate is annotated @TomClient2FAAdaptor('
                '"${annotation.type}") but answers for "${mechanism.type}"',
            autoLog: true,
          );
        }
        register(mechanism);
      }
    } catch (_) {
      _mechanisms
        ..clear()
        ..addAll(explicit);
      rethrow;
    }
  }
}
