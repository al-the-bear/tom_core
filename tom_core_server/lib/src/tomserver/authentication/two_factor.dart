/// The server-side second-factor (2FA) subsystem: the adaptor contract, the
/// mechanism registry, and the built-in TOTP adaptor.
///
/// ## The shape of the flow
///
/// A login runs in two passes. Pass 1 checks the primary credential and
/// produces a [TomPrincipal]; if that principal declares
/// [TomPrincipal.requires2FA], the server asks the adaptor registered for the
/// principal's [TomPrincipal.twoFactorType] to **issue a challenge**, and
/// answers with an interim token carrying it. Pass 2 hands the submitted factor
/// back to the same adaptor to **verify**, and on success re-issues the token
/// pair without the challenge.
///
/// ## Why mechanisms are adaptors
///
/// The framework must not know the mechanism set — a deployment may want TOTP,
/// SMS, e-mail codes, push approval or a hardware key, and adding one must not
/// touch `tom_core_server`. So the framework only knows two things: how to find
/// the adaptor for a mechanism key (reflection over [Tom2FAAdaptor]), and how
/// to move two opaque blobs between the passes:
///
/// - [Tom2FAChallengeSpec.clientData] — travels in the interim token's *public*
///   claims, for the mechanism's own client-side UI;
/// - [Tom2FAChallengeSpec.verificationData] — travels in the *encrypted*
///   section, for the adaptor's own use on pass 2.
///
/// Neither is interpreted by the framework. Expiry, the attempt counter and the
/// dispatch are generic and handled once, in [TomAuthenticationServer]; the
/// adaptor answers only the question it alone can answer — *is this submission
/// the right one?*
///
/// Expiry, the attempt counter and the dispatch are generic and handled once by
/// `TomAuthenticationServer`, which owns both passes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'two_factor_enrolment.dart';

// =============================================================================
// ANNOTATION
// =============================================================================

/// Marks a class as a server-side two-factor (2FA) adaptor for a given [type].
///
/// The annotated class must implement [Tom2FAService] and expose a no-argument
/// constructor — [Tom2FARegistry] discovers it by reflection and instantiates it
/// once. The [type] is the mechanism key that a principal's
/// [TomPrincipal.twoFactorType] names, and that the issued challenge carries so
/// pass 2 dispatches back to the same adaptor.
///
/// ```dart
/// @tomReflector
/// @Tom2FAAdaptor('sms')
/// class SmsAdaptor implements Tom2FAService { ... }
/// ```
@tomReflector
class Tom2FAAdaptor {
  /// The 2FA mechanism this adaptor implements (e.g. `'totp'`, `'sms'`).
  final String type;

  /// Tags the annotated class as a 2FA adaptor for [type].
  const Tom2FAAdaptor(this.type);
}

// =============================================================================
// EXCEPTION
// =============================================================================

/// Raised for 2FA *configuration* faults — a duplicate or unusable adaptor
/// registration, or a mechanism that cannot be constructed.
///
/// Distinct from [LoginException]: a login that fails because the user typed
/// the wrong code is an expected outcome and yields a failed
/// [TomAuthenticationResult]; a deployment whose adaptors are wired wrongly is a
/// fault that must surface loudly. Not client-throwable — an authentication
/// misconfiguration must never be described to the caller.
class Tom2FAException extends TomServerException {
  /// Creates a 2FA configuration failure.
  Tom2FAException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  }) : super(clientThrow: false);
}

// =============================================================================
// ADAPTOR CONTRACT
// =============================================================================

/// Everything an adaptor is told about the login it is challenging.
///
/// Deliberately narrow: the identity being authenticated plus the tenant and
/// locale coordinates of the attempt. An adaptor that needs more (a device
/// registry, an SMS gateway) resolves it from its own configuration — the
/// framework does not carry mechanism-specific state.
class Tom2FAContext {
  /// The principal produced by the first pass. Not yet an authenticated
  /// session: it is exactly this principal's second factor that is in question.
  final TomPrincipal principal;

  /// The client (front-end) identifier the login originates from.
  final String client;

  /// The organization being logged into.
  final String organization;

  /// The application being logged into.
  final String application;

  /// The process (sub-context of the application) being logged into.
  final String process;

  /// The client's language code, for localising a delivered message.
  final String language;

  /// The client's country code, for localising a delivered message.
  final String country;

  /// Creates the context handed to an adaptor for one challenge or
  /// verification.
  const Tom2FAContext({
    required this.principal,
    this.client = '',
    this.organization = '',
    this.application = '',
    this.process = '',
    this.language = '',
    this.country = '',
  });
}

/// What an adaptor produces when asked to issue a challenge.
///
/// The split between [clientData] and [verificationData] is the whole point: the
/// first is what the client may see, the second is what only the server may see.
/// For a mailed one-time code, [clientData] might hold the masked address while
/// [verificationData] holds a salted hash of the code — so possession of the
/// interim token never reveals the answer.
class Tom2FAChallengeSpec {
  /// A short, displayable hint (a masked phone number, a device name). Empty
  /// when the mechanism has nothing worth showing.
  final String hint;

  /// The mechanism's client-visible payload; carried in the interim token's
  /// public claims and interpreted only by the mechanism's own client code.
  final Map<String, Object?> clientData;

  /// The mechanism's server-only payload; carried in the interim token's
  /// encrypted section and handed back to [Tom2FAService.verifySubmission].
  ///
  /// Leave empty when the adaptor can re-derive what it needs at verification
  /// time — that is strictly safer, since nothing secret then travels at all.
  final Map<String, Object?> verificationData;

  /// How many submissions this challenge tolerates before it is burned.
  final int attemptsAllowed;

  /// How long the challenge stays answerable.
  final Duration validity;

  /// Describes a freshly issued challenge.
  const Tom2FAChallengeSpec({
    this.hint = '',
    this.clientData = const {},
    this.verificationData = const {},
    this.attemptsAllowed = 3,
    this.validity = const Duration(minutes: 5),
  });
}

/// One answer to a challenge, as presented to the adaptor.
class Tom2FASubmission {
  /// What the user submitted (the typed code, the signed assertion, …).
  final String submitted;

  /// The [Tom2FAChallengeSpec.verificationData] recovered from the interim
  /// token's encrypted section; empty when the adaptor stored none.
  final Map<String, Object?> verificationData;

  /// The challenge being answered, with this attempt already counted — so
  /// `challenge.attemptsRemaining` reads as it will *after* this submission.
  final Tom2FAChallenge challenge;

  /// Bundles a submission with the challenge state it answers.
  const Tom2FASubmission({
    required this.submitted,
    required this.challenge,
    this.verificationData = const {},
  });
}

/// How a mechanism names itself to a user who is being asked to choose one.
///
/// A mechanism *key* (`'totp'`, `'sms'`) is an identifier: it dispatches a
/// challenge back to the right adaptor and it is stable across releases, which
/// is exactly why it must never be shown to anyone. A user offered a choice of
/// second factors needs a label, an explanation and something to render — and
/// all three are user-facing text, so under G-RES-1 they are **resource keys**,
/// resolved against the caller's locale by whichever tier does the rendering.
///
/// The descriptor is therefore three keys and an identifier, and deliberately
/// carries no literal text at all. A descriptor holding `'Authenticator app'`
/// would be a translation defect that no test could distinguish from a correct
/// value, because it *looks* right in the one locale it was written in.
class Tom2FAMethodDescriptor {
  /// The scope every shipped mechanism's keys live under, so a resource bundle
  /// can be searched for "everything the 2FA catalog needs" by prefix.
  static const String resourceScope = 'two_factor';

  /// The mechanism key this descriptor belongs to — the same value
  /// [Tom2FARegistry.lookup] resolves and a challenge dispatches on.
  final String type;

  /// Resource key of the mechanism's short label ("Authenticator app").
  final String displayNameKey;

  /// Resource key of the one-sentence explanation shown beside the label.
  final String descriptionKey;

  /// Resource key of the icon to render. A key rather than an asset path
  /// because the two client tiers (Flutter, web) name their assets
  /// differently, and the mechanism must not have to know which one is asking.
  final String iconKey;

  /// Describes a mechanism with explicitly chosen keys.
  ///
  /// Prefer [Tom2FAMethodDescriptor.scoped] unless the mechanism's text really
  /// does live outside the [resourceScope] convention — a deployment adapting a
  /// vendor SDK whose strings already ship under another prefix, say.
  const Tom2FAMethodDescriptor({
    required this.type,
    required this.displayNameKey,
    required this.descriptionKey,
    this.iconKey = '',
  });

  /// Describes a mechanism whose text lives under `two_factor.<type>.*`.
  ///
  /// Derives all three keys from [type], which is what makes the convention
  /// structural rather than a matter of per-mechanism discipline: a mechanism
  /// cannot half-follow it, and adding one cannot silently invent a fourth
  /// naming scheme.
  Tom2FAMethodDescriptor.scoped(this.type)
      : displayNameKey = '$resourceScope.$type.name',
        descriptionKey = '$resourceScope.$type.description',
        iconKey = '$resourceScope.$type.icon';

  @override
  String toString() => 'Tom2FAMethodDescriptor($type -> $displayNameKey)';
}

/// The contract a second-factor mechanism implements.
///
/// Two questions, and only two: *what challenge should this user be given?* and
/// *is this submission correct?* Expiry, attempt counting, dispatch and token
/// issuance are the framework's job, so an adaptor stays small and its logic is
/// unit-testable in isolation.
///
/// Implementations must be stateless between calls — pass 1 and pass 2 may run
/// in different isolates or on different server instances, so anything the
/// adaptor needs to remember belongs in [Tom2FAChallengeSpec.verificationData].
@tomReflector
abstract class Tom2FAService {
  /// How this mechanism presents itself in a list of options.
  ///
  /// On the service rather than on the registry because only the mechanism
  /// knows what it is called: a registry that held the descriptions would have
  /// to be edited every time an adaptor was added, which is precisely the
  /// coupling the adaptor contract exists to remove.
  Tom2FAMethodDescriptor get descriptor;

  /// Issues a challenge for [context], or throws [LoginException] when this
  /// user cannot be challenged at all (no enrolled device, no configured
  /// secret) — a condition the login must fail on rather than paper over.
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context);

  /// Returns whether [submission] correctly answers the challenge.
  ///
  /// Returns `false` for a wrong answer — that is an ordinary outcome, and the
  /// framework turns it into a retry or an exhaustion failure. Throw only when
  /// verification could not be *performed* (an unreachable dependency).
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  );
}

// =============================================================================
// REGISTRY
// =============================================================================

/// Resolves a mechanism key to the adaptor that implements it.
///
/// Populated on first use by scanning the reflection registry for classes
/// annotated [Tom2FAAdaptor]; a deployment can also [register] an adaptor built
/// by hand, which is what tests and non-reflected wirings do. Registration is
/// idempotent per key and rejects a second, different adaptor for the same key —
/// two mechanisms answering to `'totp'` is a wiring bug, and silently picking
/// one would make the failure surface much later and much less clearly.
class Tom2FARegistry {
  Tom2FARegistry._();

  static final Map<String, Tom2FAService> _adaptors = {};
  static bool _scanned = false;

  /// The mechanism keys currently resolvable, scanning if needed.
  ///
  /// Keys, not descriptions: this is what pass-2 dispatch and
  /// [Tom2FADecision.offerableMechanisms] intersect against, and both want the
  /// cheapest possible membership test. [availableMethods] is the presentable
  /// form of the same registration.
  static Set<String> get registeredTypes {
    _ensureScanned();
    return _adaptors.keys.toSet();
  }

  /// How every registered mechanism describes itself, for a client that must
  /// render a choice.
  ///
  /// The catalog is derived from the registry rather than configured beside it,
  /// so "installed" and "offerable" cannot drift: a mechanism that is not
  /// registered is not describable, and one that is registered describes itself
  /// without anyone having to remember to add it here.
  ///
  /// Every principal sees the same list. Narrowing it to *this* user's permitted
  /// mechanisms is [Tom2FADecision.offerableMechanisms]' job, because that needs
  /// the policy's answer and a registry has no principal to ask about.
  static List<Tom2FAMethodDescriptor> get availableMethods {
    _ensureScanned();
    return List.unmodifiable(
      _adaptors.values.map((adaptor) => adaptor.descriptor),
    );
  }

  /// Registers [service] under [type], replacing nothing.
  ///
  /// Throws [Tom2FAException] if a *different* adaptor is already registered for
  /// [type]. Re-registering the identical instance is a no-op, so a double boot
  /// is harmless.
  static void register(String type, Tom2FAService service) {
    final existing = _adaptors[type];
    if (existing != null && !identical(existing, service)) {
      throw Tom2FAException(
        'authentication.2fa.duplicate_adaptor',
        'More than one 2FA adaptor is registered for "$type": '
            '$existing and $service',
        autoLog: true,
      );
    }
    _adaptors[type] = service;
  }

  /// The adaptor for [type], or `null` when the mechanism is unknown here.
  static Tom2FAService? lookup(String type) {
    _ensureScanned();
    return _adaptors[type];
  }

  /// Drops every registration and forces a re-scan on next use.
  ///
  /// For tests, which need to install their own adaptors without leaking them
  /// into the next test.
  static void reset() {
    _adaptors.clear();
    _scanned = false;
  }

  static void _ensureScanned() {
    if (_scanned) return;
    // Set before scanning: an adaptor whose construction itself touches the
    // registry must not re-enter the scan.
    _scanned = true;

    final Iterable<ClassMirror> candidates;
    try {
      candidates = tomReflector.annotatedClasses;
    } on StateError {
      // No generated reflection in this program. Annotation discovery is a
      // convenience on top of [register], not a precondition of it, so a
      // deployment that wires its adaptors by hand must keep working — and a
      // *genuinely* missing adaptor still surfaces clearly, as a null [lookup]
      // that the login turns into `login.error.2fa.unsupported-mechanism`.
      return;
    }
    registerAnnotated(candidates);
  }

  /// Registers every class in [candidates] that carries a [Tom2FAAdaptor]
  /// annotation.
  ///
  /// The automatic scan hands this the reflection registry's own class list.
  /// It is separate from that scan because a candidate set is not always the
  /// whole program: a deployment that composes its adaptors from a chosen set
  /// of libraries supplies its own, and the tests for the two malformed cases
  /// below must supply theirs — a class annotated `@Tom2FAAdaptor` but unusable
  /// cannot live in a reflected library, because the automatic scan would then
  /// reach it from every other test in the process.
  ///
  /// Throws [Tom2FAException] on the first unusable candidate, naming it. A
  /// half-registered registry is not offered as an alternative: an adaptor set
  /// that is wrong is wrong at start-up, not at the login that happens to need
  /// the missing mechanism.
  static void registerAnnotated(Iterable<ClassMirror> candidates) {
    for (var candidate in candidates) {
      final annotations = candidate.metadata.whereType<Tom2FAAdaptor>();
      if (annotations.isEmpty) continue;
      final annotation = annotations.first;

      Object? adaptor;
      try {
        adaptor = candidate.newInstance('', []);
      } catch (error, stack) {
        throw Tom2FAException(
          'authentication.2fa.adaptor_instantiation_failed',
          '2FA adaptor scan: failed to instantiate $candidate for '
              'mechanism "${annotation.type}"',
          rootException: error,
          stack: stack,
          autoLog: true,
        );
      }
      if (adaptor is! Tom2FAService) {
        throw Tom2FAException(
          'authentication.2fa.adaptor_does_not_implement_service',
          '2FA adaptor scan: $candidate is annotated @Tom2FAAdaptor('
              '"${annotation.type}") but does not implement Tom2FAService',
          autoLog: true,
        );
      }
      register(annotation.type, adaptor);
    }
  }
}

// =============================================================================
// TOTP ADAPTOR
// =============================================================================

/// Resolves the shared TOTP secret for the user being challenged, or `null`
/// when that user has no authenticator enrolled.
///
/// The returned secret is the base32 string an authenticator app was
/// provisioned with.
typedef TomTotpSecretResolver = FutureOr<String?> Function(
  Tom2FAContext context,
);

/// The built-in RFC 6238 time-based one-time-password adaptor.
///
/// Chosen as the first concrete mechanism because it needs no delivery channel:
/// the code is derived from a shared secret and the clock, so the whole path —
/// challenge, submission, verification, retry — can be exercised without an SMS
/// gateway or a mail server standing behind it.
///
/// Expiry, attempt counting and dispatch are the framework's; the derivation
/// itself is [TomTotp]'s, in the kernel, so the code this verifier expects and
/// the code an enrolment tool or authenticator produces come from one
/// implementation. What is left here is only *policy*: which secret, how many
/// digits, how much skew to tolerate, how many attempts.
///
/// ## Where the secret comes from
///
/// From the installed [Tom2FAEnrolmentStore] — the user's own `'totp'`
/// enrolment, whose [Tom2FAEnrolment.secretData] carries the base32 secret under
/// [secretDataKey] — falling back to [globalSettingSecretResolver] when no store
/// is installed or the store holds no TOTP enrolment for this user.
///
/// It is deliberately *not* read from [TomUser.attributes]: those are projected
/// into the token's **public** claims, so a secret parked there would be
/// readable by anyone holding the token. For the same reason this adaptor
/// stores nothing in
/// [Tom2FAChallengeSpec.verificationData] — it re-resolves the secret on pass 2,
/// so the secret never travels at all.
@tomReflector
@Tom2FAAdaptor(TomTotp2FAService.mechanismType)
class TomTotp2FAService implements Tom2FAService {
  /// The mechanism key this adaptor answers to.
  static const String mechanismType = 'totp';

  /// The key this adaptor's base32 secret is filed under in
  /// [Tom2FAEnrolment.secretData].
  ///
  /// Named rather than inlined because an enrolment tool writes the map this
  /// adaptor reads, and a typo on either side would present as *not enrolled* —
  /// the one failure mode indistinguishable from the ordinary case.
  static const String secretDataKey = 'secret';

  /// How TOTP names itself in a list of options: resource keys under
  /// `two_factor.totp.*`, no literal text (G-RES-1).
  static final Tom2FAMethodDescriptor _descriptor =
      Tom2FAMethodDescriptor.scoped(mechanismType);

  /// Resolves a user's base32 TOTP secret when no [Tom2FAEnrolmentStore] is
  /// installed.
  ///
  /// The store is the primary source; this hook is the fallback for a deployment
  /// that keeps its secrets somewhere the framework does not own (an LDAP
  /// attribute, a vault). With neither wired, every TOTP challenge fails with
  /// `login.error.2fa.not-enrolled`.
  static TomTotpSecretResolver? globalSettingSecretResolver;

  /// Number of digits in a generated code (RFC 6238 default: 6).
  static int globalSettingDigits = TomTotp.defaultDigits;

  /// Length of one time step (RFC 6238 default: 30 s).
  static Duration globalSettingPeriod = TomTotp.defaultPeriod;

  /// How many time steps either side of "now" are accepted, to tolerate clock
  /// skew between the server and the authenticator. One step each way is the
  /// usual compromise between usability and the size of the accepted window.
  static int globalSettingWindowSteps = 1;

  /// How many submissions one challenge tolerates.
  static int globalSettingAttemptsAllowed = 3;

  /// How long a challenge stays answerable. Longer than one code's lifetime, so
  /// a user who starts typing just before a rollover is not punished for it.
  static Duration globalSettingChallengeValidity = const Duration(minutes: 5);

  /// Creates the adaptor. No-argument so the registry can reflect it into life.
  TomTotp2FAService();

  @override
  Tom2FAMethodDescriptor get descriptor => _descriptor;

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    // Resolve now, not at verification time only: a user with no enrolled
    // authenticator must fail the login here rather than be shown a code prompt
    // that can never be satisfied.
    final secret = await _resolveSecret(context);
    if (secret == null) {
      throw LoginException(
        'login.error.2fa.not-enrolled',
        'No authenticator is enrolled for this account',
      );
    }
    return Tom2FAChallengeSpec(
      // Nothing to deliver and nothing to show: the code is already on the
      // user's device. The client data names the code shape so a UI can size
      // its input field without hard-coding this mechanism's defaults.
      clientData: {
        'digits': globalSettingDigits,
        'periodSeconds': globalSettingPeriod.inSeconds,
      },
      attemptsAllowed: globalSettingAttemptsAllowed,
      validity: globalSettingChallengeValidity,
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async {
    final secret = await _resolveSecret(context);
    if (secret == null) return false;

    final key = TomTotp.decodeBase32(secret);
    if (key.isEmpty) return false;

    final submitted = submission.submitted.trim();
    // Checked before any HMAC: a submission of the wrong width can never match,
    // and rejecting it here keeps a malformed input from costing a hash.
    if (submitted.length != globalSettingDigits) return false;

    if (globalSettingPeriod.inSeconds <= 0) return false;
    final counter = TomTotp.counterFor(period: globalSettingPeriod);

    for (var offset = -globalSettingWindowSteps;
        offset <= globalSettingWindowSteps;
        offset++) {
      final expected =
          TomTotp.generateCode(key, counter + offset, globalSettingDigits);
      if (_constantTimeEquals(expected, submitted)) return true;
    }
    return false;
  }

  /// The base32 secret for the user being challenged, or `null` when this user
  /// has no authenticator.
  ///
  /// The enrolment store is asked first and the hook is the fallback, not the
  /// other way round: a deployment that has migrated to the store must not have
  /// a stale resolver silently keep answering, and one that never installed a
  /// store keeps exactly the behaviour it had. When both are present but the
  /// store holds no TOTP enrolment for *this* user, the hook still answers —
  /// which is what makes migrating a user at a time possible.
  Future<String?> _resolveSecret(Tom2FAContext context) async {
    final store = Tom2FAEnrolmentStore.resolve();
    if (store != null) {
      final enrolments = await store.enrolmentsFor(context);
      for (final enrolment in enrolments) {
        if (enrolment.type != mechanismType) continue;
        final secret = enrolment.secretData[secretDataKey];
        // A non-string, or an empty one, is a malformed enrolment rather than a
        // second candidate: keep looking, so one broken row cannot lock out a
        // user who also holds a good one.
        if (secret is String && secret.isNotEmpty) return secret;
      }
    }
    final resolver = globalSettingSecretResolver;
    if (resolver == null) return null;
    return await resolver(context);
  }

  /// The code this verifier expects right now, for the base32 [secret] — the
  /// adaptor's own policy (digits, period) applied to [TomTotp].
  ///
  /// For enrolment self-checks and for tests, so neither has to restate the
  /// policy and then drift out of agreement with the verifier.
  static String expectedCode(String secret, {DateTime? at}) => TomTotp.codeFor(
        secret,
        at: at,
        digits: globalSettingDigits,
        period: globalSettingPeriod,
      );

  /// Compares two codes without leaking, through timing, how much of the
  /// submission was right.
  static bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}
