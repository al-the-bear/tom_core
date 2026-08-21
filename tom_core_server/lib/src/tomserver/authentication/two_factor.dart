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
/// dispatch are generic and handled once, in [TomAuthenticationServer], which
/// owns both passes; the adaptor answers only the question it alone can
/// answer — *is this submission the right one?*
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

  /// How every registered mechanism that a user can **set up** describes
  /// itself — [availableMethods] narrowed to those implementing
  /// [Tom2FAEnrolmentSupport].
  ///
  /// The distinction is not pedantry. "Which factors does this deployment
  /// verify?" and "which can this user be told to go and enrol?" are different
  /// questions with different answers: a hardware token an administrator hands
  /// out is verifiable here and enrollable nowhere. A forced-enrolment step that
  /// offered [availableMethods] would present the user a choice one of whose
  /// options cannot be acted on.
  ///
  /// Derived by asking the adaptors rather than by a second registration, for
  /// the reason [availableMethods] is derived: a list maintained beside the
  /// registry drifts from it, and an adaptor that gains enrolment support in a
  /// later release would have to be remembered in two places.
  static List<Tom2FAMethodDescriptor> get enrollableMethods {
    _ensureScanned();
    return List.unmodifiable(
      _adaptors.values.whereType<Tom2FAEnrolmentSupport>().map(
        (adaptor) => (adaptor as Tom2FAService).descriptor,
      ),
    );
  }

  /// The enrolment support for [type], or `null` when the mechanism is unknown
  /// here *or* known but not enrollable.
  ///
  /// One null for both, because the caller's response is the same — this
  /// mechanism cannot be offered for set-up — and splitting them would only
  /// invite a caller to distinguish two cases it has no different action for.
  /// The wiring bug (a mechanism the client was offered but that vanished) is
  /// caught by [lookup] returning null on the verification path.
  static Tom2FAEnrolmentSupport? enrolmentSupportFor(String type) {
    final Object? adaptor = lookup(type);
    return adaptor is Tom2FAEnrolmentSupport ? adaptor : null;
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
    _scanSkipLogged = false;
  }

  /// Runs the annotation scan once, on first use.
  ///
  /// "Once" means once *successfully*. A scan that could not run leaves the
  /// registry unarmed, so the next access tries again: the reflector is
  /// initialised by generated code at some point during start-up, and whatever
  /// touches the registry before that point must not decide the question for
  /// the rest of the process. Remembering a failure as though it were a scan
  /// is how a registry ends up permanently and silently empty.
  static void _ensureScanned() {
    // `_scanning` rather than `_scanned` is what makes this re-entrant-safe: an
    // adaptor whose constructor touches the registry sees the partial map and
    // does not start a second scan, but the scan it interrupted is still the
    // one that gets to record success.
    if (_scanned || _scanning) return;

    final Iterable<ClassMirror> candidates;
    try {
      candidates = tomReflector.annotatedClasses;
    } on StateError {
      // No generated reflection *yet*. Annotation discovery is a convenience on
      // top of [register], not a precondition of it, so a deployment that wires
      // its adaptors by hand must keep working — and a *genuinely* missing
      // adaptor still surfaces clearly, as a null [lookup] that the login turns
      // into `login.error.2fa.unsupported-mechanism`.
      //
      // Said out loud, because an empty registry is otherwise indistinguishable
      // from a deployment that meant to register nothing. Informational rather
      // than a warning: hand-wiring is supported, and a reflector that arrives
      // later is picked up by the retry this early return leaves armed. Once
      // per lifetime, because [lookup] runs on every login pass.
      if (!_scanSkipLogged) {
        _scanSkipLogged = true;
        tomLog.info(
          'Tom2FARegistry: the 2FA adaptor scan found no generated reflection '
          'in this program, so annotated adaptors were not discovered. '
          'Adaptors registered by hand still resolve, and the scan is retried '
          'on the next access.',
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
  ///
  /// That holds for the registry a caller can still see afterwards, not only
  /// for the throw: a failed call registers nothing, and leaves registrations
  /// made before it untouched. Both halves matter now that a failed scan is
  /// retried — leftovers from the first attempt would collide with the second
  /// attempt's fresh instances and report a mechanism that was never at fault.
  static void registerAnnotated(Iterable<ClassMirror> candidates) {
    final restore = Map<String, Tom2FAService>.of(_adaptors);
    try {
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
    } catch (_) {
      _adaptors
        ..clear()
        ..addAll(restore);
      rethrow;
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
typedef TomTotpSecretResolver =
    FutureOr<String?> Function(Tom2FAContext context);

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
///
/// ## Enrolment
///
/// The adaptor also implements [Tom2FAEnrolmentSupport], so the framework can
/// *create* an authenticator and not merely verify one that appeared from
/// somewhere else. [beginEnrolment] generates a secret and hands back both the
/// base32 string and an `otpauth://` URI built from **this verifier's own**
/// digits and period, so the app is provisioned with the policy that will be
/// applied to it; [confirmEnrolment] refuses to yield an enrolment until the
/// user has typed back a code derived from that very secret.
@tomReflector
@Tom2FAAdaptor(TomTotp2FAService.mechanismType)
class TomTotp2FAService implements Tom2FAService, Tom2FAEnrolmentSupport {
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

  /// The name the authenticator app files this account under, shown beside the
  /// code — empty means *use the application being logged into*
  /// ([Tom2FAContext.application]).
  ///
  /// A setting rather than a constant because the issuer is what the user reads
  /// to tell one of a dozen six-digit codes from another; a framework that
  /// hardcoded it would put the same word in every deployment's authenticator.
  /// Defaulted from the application rather than left blank because that is
  /// already the deployment's own name for itself, so the common case needs no
  /// configuration and the uncommon one (a suite of applications sharing one
  /// account) sets this once.
  static String globalSettingIssuer = '';

  /// How many bytes of entropy a generated secret carries.
  ///
  /// 20 bytes = 160 bits, RFC 4226 §4 R6's recommendation and the width of the
  /// HMAC-SHA1 key the codes are derived with; more would be truncated into the
  /// same strength by the hash, less would weaken it.
  static int globalSettingSecretBytes = 20;

  /// How many confirmation attempts one enrolment offer tolerates.
  static int globalSettingEnrolmentAttemptsAllowed = 3;

  /// How long an enrolment offer stays confirmable.
  ///
  /// Longer than a challenge, because the user has to install an app and scan a
  /// code in between, and still bounded, because an unconfirmed secret is a
  /// credential nobody is yet watching.
  static Duration globalSettingEnrolmentValidity = const Duration(minutes: 10);

  /// The key the `otpauth://` provisioning URI is filed under in
  /// [Tom2FAEnrolmentOffer.clientData] — what a client renders as a QR code.
  static const String clientDataUriKey = 'otpauthUri';

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
    return _matchesWithinWindow(secret, submission.submitted);
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

  // ---------------------------------------------------------------------------
  // ENROLMENT
  // ---------------------------------------------------------------------------

  @override
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context) async {
    final secret = generateSecret();
    return Tom2FAEnrolmentOffer(
      type: mechanismType,
      clientData: {
        // Both forms, because a client shows the QR code *and* a typed-entry
        // fallback for the user whose camera will not focus.
        secretDataKey: secret,
        clientDataUriKey: provisioningUri(secret, context),
        'digits': globalSettingDigits,
        'periodSeconds': globalSettingPeriod.inSeconds,
      },
      // The server's own copy, in the encrypted section. The confirmation
      // derives the expected code from *this* one and never from the client
      // data, which travels in public claims: a confirmation that trusted the
      // public copy could be told to accept a secret the client chose.
      enrolmentData: {secretDataKey: secret},
      attemptsAllowed: globalSettingEnrolmentAttemptsAllowed,
      validity: globalSettingEnrolmentValidity,
    );
  }

  @override
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  ) async {
    final secret = offer.enrolmentData[secretDataKey];
    if (secret is! String ||
        secret.isEmpty ||
        TomTotp.decodeBase32(secret).isEmpty) {
      throw LoginException(
        'login.error.2fa.enrolment-offer-invalid',
        'This enrolment can no longer be completed; please start again',
      );
    }

    if (!_matchesWithinWindow(secret, submitted)) {
      // Throwing rather than returning a nullable enrolment: the only value this
      // method can return is a *confirmed* one, so a caller cannot accidentally
      // store an unconfirmed secret by forgetting a null check.
      throw LoginException(
        'login.error.2fa.enrolment-code-invalid',
        'That code does not match the authenticator that was just set up',
      );
    }

    return Tom2FAEnrolment(
      type: mechanismType,
      // One authenticator per user, deliberately: [_resolveSecret] answers a
      // challenge with the *first* TOTP enrolment it finds, so a second row
      // would make which secret works depend on storage order. A stable id makes
      // re-enrolment an upsert instead — which is exactly what replacing a lost
      // phone should do.
      enrolmentId: mechanismType,
      hint: offer.hint,
      secretData: {secretDataKey: secret},
    );
  }

  /// A fresh base32 secret, [globalSettingSecretBytes] bytes of cryptographically
  /// secure randomness.
  ///
  /// Drawn from [RsaKeyHelper.getSecureRandom] — the framework's own CSPRNG —
  /// and not from `dart:math`'s `Random()`, whose output is predictable from a
  /// handful of observations. The value being generated is a permanent
  /// credential: a guessable one is worse than no second factor, because it is
  /// trusted.
  static String generateSecret() => TomTotp.encodeBase32(
    RsaKeyHelper.getSecureRandom().nextBytes(globalSettingSecretBytes),
  );

  /// The `otpauth://` provisioning URI for [secret], as an authenticator app
  /// consumes it (the payload behind the QR code).
  ///
  /// Every parameter is taken from this adaptor's own settings, so the app is
  /// provisioned with the policy this verifier will apply — an app told to
  /// produce eight digits every sixty seconds while the server checks six every
  /// thirty is a lockout that only shows up at the next login.
  ///
  /// `algorithm=SHA1` is stated rather than left to the app's default because
  /// [TomTotp] derives with HMAC-SHA1; the default happens to agree, but an
  /// implicit agreement is not one anybody can check.
  static String provisioningUri(String secret, Tom2FAContext context) {
    final issuer = issuerFor(context);
    final account = context.principal.username;
    final label = issuer.isEmpty
        ? Uri.encodeComponent(account)
        : '${Uri.encodeComponent(issuer)}:${Uri.encodeComponent(account)}';
    final parameters = <String, String>{
      'secret': secret,
      if (issuer.isNotEmpty) 'issuer': issuer,
      'algorithm': 'SHA1',
      'digits': '$globalSettingDigits',
      'period': '${globalSettingPeriod.inSeconds}',
    };
    // Assembled by hand rather than through `Uri(queryParameters:)`, which
    // encodes a space as `+`; that is correct for a form body and wrong here,
    // where an issuer of "Acme Corp" must arrive as "Acme%20Corp".
    final query = parameters.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return 'otpauth://totp/$label?$query';
  }

  /// The issuer name to provision, for a login in [context]: the configured
  /// [globalSettingIssuer], else the application being logged into.
  static String issuerFor(Tom2FAContext context) =>
      globalSettingIssuer.isNotEmpty
      ? globalSettingIssuer
      : context.application;

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

  /// Whether [submitted] is the code for [secret] at any time step within
  /// [globalSettingWindowSteps] of now.
  ///
  /// The one place a submitted code is judged. Verification and enrolment
  /// confirmation both come here, expressed through [expectedCode], so the two
  /// cannot drift: a policy change that made an enrolment self-check accept
  /// something the login would refuse is precisely how a user ends up locked out
  /// of an account they just successfully set up. The tolerated skew is shared
  /// for the same reason — a phone's clock is exactly as wrong at enrolment as
  /// it is at the next login.
  static bool _matchesWithinWindow(String secret, String submitted) {
    final code = submitted.trim();
    // Checked before any HMAC: a submission of the wrong width can never match,
    // and rejecting it here keeps a malformed input from costing a hash.
    if (code.length != globalSettingDigits) return false;
    // [TomTotp.counterFor] throws on a non-positive period, and a misconfigured
    // adaptor should fail every code rather than every request.
    if (globalSettingPeriod.inSeconds <= 0) return false;

    final now = DateTime.now();
    for (
      var offset = -globalSettingWindowSteps;
      offset <= globalSettingWindowSteps;
      offset++
    ) {
      final expected = expectedCode(
        secret,
        at: now.add(globalSettingPeriod * offset),
      );
      // Empty means the secret was undecodable; no submission should match it.
      if (expected.isEmpty) return false;
      if (_constantTimeEquals(expected, code)) return true;
    }
    return false;
  }

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
