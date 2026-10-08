/// Which second factors a user has actually set up — the store behind "*choose
/// a method*".
///
/// ## Why this exists
///
/// [Tom2FARegistry.availableMethods] answers *what could be used here*. It is a
/// property of the deployment, identical for every user. The question a login
/// actually has to answer is narrower and per-user: *what has **this** user set
/// up?* Before this library there was no answer at all — the only enrolment
/// state was [TomTotp2FAService.globalSettingSecretResolver], a single hook that
/// spoke for exactly one mechanism and had no notion of "several", "primary" or
/// "none yet".
///
/// That gap is not cosmetic. "Has this user enrolled a second factor?" is the
/// condition a forced-enrolment flow branches on; "which of the user's factors
/// do we challenge?" is the choice the login offers; and neither is expressible
/// as one nullable secret.
///
/// ## The shape
///
/// - [Tom2FAEnrolment] — one set-up factor: the mechanism, a stable id, a
///   displayable [Tom2FAEnrolment.hint], when it was enrolled, whether it is the
///   user's default, and the mechanism's own opaque
///   [Tom2FAEnrolment.secretData].
/// - [Tom2FAEnrolmentStore] — read/write access to a principal's enrolments;
///   [Tom2FAEnrolmentStore.resolve] finds the installed one (G-DI-3).
/// - [TomMemory2FAEnrolmentStore] — for tests and for a deployment that has not
///   provisioned a database yet.
/// - [TomPersistent2FAEnrolmentStore] over [TomUserTwoFactorEnrolment] — the
///   real one, through the ordinary CRUD repository, with `secret_data`
///   **encrypted at rest**.
///
/// ## Why this is a separate library from `two_factor.dart`
///
/// The two import each other: the adaptor contract needs the store to resolve a
/// user's secret, and an enrolment is described in terms of a
/// [Tom2FAContext]. Dart permits the cycle, and the alternative — a third
/// library holding just the context — would split the 2FA flow across three
/// files to avoid an import graph nobody reads. The split that *is* worth
/// making is the one here: the mechanism contract has no dependency on
/// persistence annotations or a datasource, and this library does, so a
/// deployment that never persists an enrolment does not pay for the
/// repository.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';
import 'two_factor.dart';

// =============================================================================
// VALUE
// =============================================================================

/// One second factor a user has set up.
///
/// A value, not a row: the memory store and the persistent store hand back the
/// same type, so nothing above them can tell which is installed. That is what
/// lets the login flow be tested without a database and run against one
/// unchanged.
class Tom2FAEnrolment {
  /// The mechanism key this enrolment is for — the same value
  /// [Tom2FARegistry.lookup] resolves.
  final String type;

  /// Identifies this enrolment among the user's others, stably across logins.
  ///
  /// Chosen by whatever performed the enrolment (a device id, a uuid), not by
  /// the store: the client that offers "remove this authenticator" needs a
  /// handle it can quote back, and a surrogate database key would tie that
  /// handle to one storage implementation.
  final String enrolmentId;

  /// A short displayable clue distinguishing this enrolment from the user's
  /// others — a masked phone number, a device name.
  ///
  /// Deliberately **not** resource-keyed, unlike everything on
  /// [Tom2FAMethodDescriptor]: a hint is user *data*, not interface text. There
  /// is no locale in which `'iPhone 14'` or `'•••• 4417'` should read
  /// differently, and routing it through a resource bundle would only invite a
  /// missing-key placeholder where the user expects to recognise their own
  /// device.
  final String hint;

  /// When the user set this factor up (UTC).
  final DateTime enrolledAt;

  /// Whether this is the factor to challenge when the user expresses no choice.
  ///
  /// At most one of a user's enrolments should carry it; the store does not
  /// enforce that, because the flow's fallback — first enrolment in the list —
  /// is well-defined either way, and a uniqueness rule that can be violated by
  /// a concurrent write would fail a login rather than merely pick oddly.
  final bool isPrimary;

  /// The mechanism's own state for this enrolment: a TOTP shared secret, a
  /// phone number, a credential id. Opaque to everything but the adaptor that
  /// wrote it.
  ///
  /// Treated as **secret in full**, not per key: the store encrypts the whole
  /// map, because a mechanism added later must not be able to leak by filing
  /// something sensitive under a key the store had not been told about.
  final Map<String, Object?> secretData;

  /// Records one enrolled factor.
  ///
  /// [enrolledAt] defaults to now and is normalised to UTC — the value crosses
  /// a database boundary, and a local-time timestamp read back on a server in
  /// another zone is silently wrong.
  Tom2FAEnrolment({
    required this.type,
    required this.enrolmentId,
    this.hint = '',
    DateTime? enrolledAt,
    this.isPrimary = false,
    Map<String, Object?> secretData = const {},
  }) : enrolledAt = (enrolledAt ?? DateTime.now()).toUtc(),
       secretData = Map.unmodifiable(secretData);

  /// This enrolment with selected fields replaced.
  Tom2FAEnrolment copyWith({
    String? type,
    String? enrolmentId,
    String? hint,
    DateTime? enrolledAt,
    bool? isPrimary,
    Map<String, Object?>? secretData,
  }) => Tom2FAEnrolment(
    type: type ?? this.type,
    enrolmentId: enrolmentId ?? this.enrolmentId,
    hint: hint ?? this.hint,
    enrolledAt: enrolledAt ?? this.enrolledAt,
    isPrimary: isPrimary ?? this.isPrimary,
    secretData: secretData ?? this.secretData,
  );

  /// Names the enrolment without ever printing [secretData] — this value ends
  /// up in log lines, and a `toString` that helpfully dumped its fields would
  /// put a TOTP secret in the log the first time anyone debugged a login.
  @override
  String toString() =>
      'Tom2FAEnrolment($type/$enrolmentId'
      '${hint.isEmpty ? '' : ' "$hint"'}${isPrimary ? ', primary' : ''})';
}

/// What an adaptor produces when asked to *begin* setting a factor up — the
/// enrolment counterpart of [Tom2FAChallengeSpec].
///
/// The same split, for the same reason: [clientData] is what the user must be
/// given (for TOTP the base32 secret and the `otpauth://` URI behind the QR
/// code, for SMS the number a code was sent to), [enrolmentData] is what only
/// the server may see. Confirmation checks the typed code against
/// [enrolmentData], never against [clientData] — the latter travels in public
/// claims, and a confirmation that trusted it would let a client enrol a secret
/// of its own choosing and call it confirmed.
///
/// For TOTP the secret appears in *both*, deliberately: in [clientData] because
/// handing it to the user is the entire point of enrolment, and in
/// [enrolmentData] because the server must confirm against a copy the user's
/// browser could not have edited on the way past.
///
/// Carried between [Tom2FAEnrolmentSupport.beginEnrolment] and
/// [Tom2FAEnrolmentSupport.confirmEnrolment] in the interim token — see
/// [Tom2FAEnrolmentClaims] — so enrolment is as stateless as verification and
/// any instance can finish what another started. Nothing is written to the
/// [Tom2FAEnrolmentStore] until confirmation succeeds.
class Tom2FAEnrolmentOffer {
  /// The mechanism key this offer is for — the same value
  /// [Tom2FARegistry.lookup] resolves.
  final String type;

  /// A short displayable clue for the factor being set up, carried through to
  /// [Tom2FAEnrolment.hint] on confirmation. Empty when the mechanism has
  /// nothing worth showing.
  final String hint;

  /// The mechanism's client-visible enrolment payload; carried in the interim
  /// token's public claims and interpreted only by the mechanism's own client
  /// code.
  final Map<String, Object?> clientData;

  /// The mechanism's server-only enrolment payload; carried in the interim
  /// token's encrypted section and handed back to
  /// [Tom2FAEnrolmentSupport.confirmEnrolment].
  final Map<String, Object?> enrolmentData;

  /// How many confirmation attempts this offer tolerates before it is burned.
  final int attemptsAllowed;

  /// How long the offer stays confirmable.
  ///
  /// Bounded, not open-ended: an unconfirmed secret sitting in a token forever
  /// is a credential nobody is watching, and the user who abandoned the setup
  /// has no way to revoke it.
  final Duration validity;

  /// Describes a freshly begun enrolment.
  const Tom2FAEnrolmentOffer({
    required this.type,
    this.hint = '',
    this.clientData = const {},
    this.enrolmentData = const {},
    this.attemptsAllowed = 3,
    this.validity = const Duration(minutes: 10),
  });

  /// The offer as a JSON-safe map, for [Tom2FAEnrolmentClaims.offerData].
  ///
  /// Whole, including [enrolmentData]: the claim it goes into is the encrypted
  /// one, and an offer that round-tripped without its server section could not
  /// be confirmed by the instance that received it.
  Map<String, Object?> toClaim() => {
    _claimType: type,
    _claimHint: hint,
    _claimClientData: clientData,
    _claimEnrolmentData: enrolmentData,
    _claimAttemptsAllowed: attemptsAllowed,
    _claimValiditySeconds: validity.inSeconds,
  };

  /// Reads back what [toClaim] wrote, or `null` when [claim] is not a
  /// well-formed offer.
  ///
  /// Nullable rather than throwing because the input is a decoded token: a
  /// truncated, tampered-with or older-release claim is an ordinary thing to
  /// meet, and the caller's response to all three is the same — refuse the
  /// confirmation. Fields other than the type fall back to their defaults, so
  /// an offer written before a field existed still confirms.
  static Tom2FAEnrolmentOffer? fromClaim(Object? claim) {
    if (claim is! Map) return null;
    final type = claim[_claimType];
    if (type is! String || type.isEmpty) return null;
    final validitySeconds = claim[_claimValiditySeconds];
    return Tom2FAEnrolmentOffer(
      type: type,
      hint: claim[_claimHint] is String ? claim[_claimHint] as String : '',
      clientData: _mapOf(claim[_claimClientData]),
      enrolmentData: _mapOf(claim[_claimEnrolmentData]),
      attemptsAllowed: claim[_claimAttemptsAllowed] is int
          ? claim[_claimAttemptsAllowed] as int
          : 3,
      validity: Duration(
        seconds: validitySeconds is int ? validitySeconds : 600,
      ),
    );
  }

  static Map<String, Object?> _mapOf(Object? value) => value is Map
      ? {for (final entry in value.entries) '${entry.key}': entry.value}
      : const {};

  static const String _claimType = 'type';
  static const String _claimHint = 'hint';
  static const String _claimClientData = 'clientData';
  static const String _claimEnrolmentData = 'enrolmentData';
  static const String _claimAttemptsAllowed = 'attemptsAllowed';
  static const String _claimValiditySeconds = 'validitySeconds';

  /// Names the offer without printing either payload — [clientData] carries the
  /// secret being enrolled, and this value reaches log lines.
  @override
  String toString() =>
      'Tom2FAEnrolmentOffer($type${hint.isEmpty ? '' : ' "$hint"'})';
}

/// An enrolment in flight, as carried by an interim login token.
///
/// The counterpart of [Tom2FAChallenge] for the *other* thing a login can owe.
/// Where a challenge says "answer this", a state says "you have no factor yet;
/// here is what you may set up, and here is how far you have got".
///
/// It has two shapes, and the difference is [offer]:
///
/// - **offered** ([offer] is null) — the login has branched into enrolment and
///   the user has been handed [offeredTypes] to choose from. Nothing mechanism-
///   specific exists yet.
/// - **begun** ([offer] is non-null) — a mechanism was chosen, the adaptor
///   generated its material, and the user must now type back a confirmation.
///   [expiresAt] and the attempt counter bound that window.
///
/// [offeredTypes] survives into the begun shape on purpose: a user who scanned
/// nothing and wants a different method must be able to go back without
/// restarting the login, and the list they may go back to is the one the server
/// offered — not one the client remembers.
class Tom2FAEnrolmentState {
  /// The mechanism keys offered, in preference order.
  final List<String> offeredTypes;

  /// Whether the user may decline and complete the login with no factor.
  final bool skippable;

  /// Whether declining spends one of the principal's grace logins.
  ///
  /// False under an `optional` policy, where declining costs nothing; true
  /// under a `required` one that is being softened by grace.
  final bool skipSpendsGrace;

  /// The chosen mechanism's material, or `null` while the user is still
  /// choosing.
  final Tom2FAEnrolmentOffer? offer;

  /// The UTC instant after which [offer] can no longer be confirmed; `null` in
  /// the offered shape, where nothing mechanism-specific is pending.
  final DateTime? expiresAt;

  /// How many confirmation attempts have already been consumed.
  final int attempt;

  /// Records an enrolment in flight. [expiresAt] is normalised to UTC so
  /// comparisons are unambiguous regardless of who constructed it.
  Tom2FAEnrolmentState({
    List<String> offeredTypes = const [],
    this.skippable = false,
    this.skipSpendsGrace = false,
    this.offer,
    DateTime? expiresAt,
    this.attempt = 0,
  }) : offeredTypes = List.unmodifiable(offeredTypes),
       expiresAt = expiresAt?.toUtc();

  /// Whether a mechanism has been chosen and its material generated.
  bool get hasOffer => offer != null;

  /// Whether the confirmation window has closed as of [now] (default: the
  /// current instant).
  ///
  /// A null [expiresAt] means two different things in the two shapes, and the
  /// answer differs accordingly. In the **offered** shape there is no window to
  /// close, so this is false. In the **begun** shape the deadline is the only
  /// thing that stops a generated secret being confirmable forever, so its
  /// absence is not "no limit" but a state that should never have been built —
  /// and the safe reading of a window that was never opened is that no instant
  /// is inside it.
  ///
  /// [fromClaims] rejects such a token outright rather than relying on this, so
  /// in practice a begun state always has a deadline. This is the backstop for
  /// the paths that construct one directly.
  bool isExpired([DateTime? now]) {
    final deadline = expiresAt;
    if (deadline == null) return hasOffer;
    return !(now ?? DateTime.now().toUtc()).toUtc().isBefore(deadline);
  }

  /// How many confirmation attempts remain. Never negative.
  int get attemptsRemaining {
    final allowed = offer?.attemptsAllowed ?? 0;
    final remaining = allowed - attempt;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether every allowed confirmation attempt has been consumed.
  bool get isExhausted => hasOffer && attemptsRemaining <= 0;

  /// This state with one more confirmation attempt consumed.
  Tom2FAEnrolmentState withConsumedAttempt() => Tom2FAEnrolmentState(
    offeredTypes: offeredTypes,
    skippable: skippable,
    skipSpendsGrace: skipSpendsGrace,
    offer: offer,
    expiresAt: expiresAt,
    attempt: attempt + 1,
  );

  /// This state advanced to the begun shape with [chosen]'s material.
  ///
  /// The attempt counter restarts: the attempts an offer allows belong to
  /// *that* offer, and choosing a different mechanism is a different offer.
  Tom2FAEnrolmentState withOffer(
    Tom2FAEnrolmentOffer chosen, {
    DateTime? now,
  }) => Tom2FAEnrolmentState(
    offeredTypes: offeredTypes,
    skippable: skippable,
    skipSpendsGrace: skipSpendsGrace,
    offer: chosen,
    expiresAt: (now ?? DateTime.now()).toUtc().add(chosen.validity),
  );

  /// Projects this state onto the interim token's **public** claims (see
  /// [Tom2FAEnrolmentClaims]).
  ///
  /// The mechanism-specific claims appear only in the begun shape, so a client
  /// cannot mistake an offer list for a pending confirmation.
  Map<String, Object?> toClaims() {
    final claims = <String, Object?>{
      Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
      Tom2FAEnrolmentClaims.offeredTypes: offeredTypes,
      Tom2FAEnrolmentClaims.skippable: skippable,
      Tom2FAEnrolmentClaims.skipSpendsGrace: skipSpendsGrace,
    };
    final chosen = offer;
    if (chosen == null) return claims;
    return claims..addAll({
      Tom2FAEnrolmentClaims.type: chosen.type,
      Tom2FAEnrolmentClaims.hint: chosen.hint,
      Tom2FAEnrolmentClaims.attempt: attempt,
      Tom2FAEnrolmentClaims.attemptsAllowed: chosen.attemptsAllowed,
      Tom2FAEnrolmentClaims.expiresAt: expiresAt?.toIso8601String(),
      Tom2FAEnrolmentClaims.clientData: chosen.clientData,
    });
  }

  /// The token's **encrypted** claims for this state, or `null` in the offered
  /// shape.
  ///
  /// The whole offer, secret section included — which is precisely why it goes
  /// in the encrypted half: the confirmation must be checked against material
  /// the client could not have edited on the way past.
  Map<String, Object?>? get secretClaims => offer == null
      ? null
      : {Tom2FAEnrolmentClaims.offerData: offer!.toClaim()};

  /// Reads a state back from a token's public [payload] and its decrypted
  /// [secretData], or returns `null` when the token carries no enrolment.
  ///
  /// Defensive throughout, for the reason [Tom2FAChallenge.fromClaims] is: the
  /// input arrived from outside the process. A payload that claims a pending
  /// enrolment but carries an unreadable offer yields the *offered* shape rather
  /// than a half-built confirmation — the user is asked to choose again, which
  /// is the only safe reading.
  ///
  /// An unreadable **expiry** on a *begun* enrolment is the one thing this
  /// method refuses outright, with `login.error.2fa.enrolment-offer-invalid`.
  /// Degrading it the way an unreadable offer degrades is not available: the
  /// offer travels in the token's encrypted half and so is authentic, while the
  /// deadline travels in the public payload, which nothing on the bearer path
  /// verifies. Reading a missing deadline as "no deadline" would therefore let
  /// a client delete one claim and hold a confirmable secret indefinitely, and
  /// inventing one from the offer's own validity would let it renew the window
  /// on every request. Refusing costs an honest user a restarted enrolment;
  /// the alternatives cost a credential nobody is watching.
  ///
  /// Every boolean claim is read with [Tom2FAClaims.isTrue], the same rule the
  /// kernel's [Tom2FAPendingEnrolment.fromClaims] applies. The two decode the
  /// *same claims from the same token* — one to drive the UI, one to authorise
  /// the enrolment passes — so a disagreement about what `skippable` means
  /// would show up as a skip button that the server then refuses. They agree on
  /// the deadline too, by the same argument and with the same effect: the
  /// kernel returns `null` (it has no error channel and only has to decline to
  /// render a panel), this one throws (it must fail the pass).
  ///
  /// Throws [TomLoginException] with `login.error.2fa.enrolment-offer-invalid`
  /// when a begun enrolment's expiry claim is absent or is not a parsable
  /// instant.
  static Tom2FAEnrolmentState? fromClaims(
    Map<String, dynamic>? payload, [
    Map<String, dynamic>? secretData,
  ]) {
    if (payload == null) return null;
    if (!Tom2FAClaims.isTrue(payload[Tom2FAEnrolmentClaims.pendingEnrolment])) {
      return null;
    }

    final offeredRaw = payload[Tom2FAEnrolmentClaims.offeredTypes];
    final offeredTypes = offeredRaw is List
        ? offeredRaw.whereType<String>().toList()
        : const <String>[];
    final skippable = Tom2FAClaims.isTrue(
      payload[Tom2FAEnrolmentClaims.skippable],
    );
    final skipSpendsGrace = Tom2FAClaims.isTrue(
      payload[Tom2FAEnrolmentClaims.skipSpendsGrace],
    );

    final offer = Tom2FAEnrolmentOffer.fromClaim(
      secretData?[Tom2FAEnrolmentClaims.offerData],
    );
    if (offer == null) {
      return Tom2FAEnrolmentState(
        offeredTypes: offeredTypes,
        skippable: skippable,
        skipSpendsGrace: skipSpendsGrace,
      );
    }

    final expiresAtRaw = payload[Tom2FAEnrolmentClaims.expiresAt];
    final expiresAt = expiresAtRaw is String
        ? DateTime.tryParse(expiresAtRaw)
        : null;
    if (expiresAt == null) {
      throw TomLoginException(
        'login.error.2fa.enrolment-offer-invalid',
        'The pending enrolment carries no usable expiry',
        reason: TomLoginFailure.secondFactorInvalid,
      );
    }

    final attempt = payload[Tom2FAEnrolmentClaims.attempt];
    return Tom2FAEnrolmentState(
      offeredTypes: offeredTypes,
      skippable: skippable,
      skipSpendsGrace: skipSpendsGrace,
      offer: offer,
      expiresAt: expiresAt,
      attempt: attempt is int ? attempt : 0,
    );
  }

  /// Names the state without printing the offer's payloads — they carry the
  /// secret being enrolled, and this value reaches log lines.
  @override
  String toString() =>
      'Tom2FAEnrolmentState(offered: $offeredTypes'
      '${skippable ? ', skippable' : ''}'
      '${offer == null ? '' : ', begun ${offer!.type} $attempt/'
                '${offer!.attemptsAllowed}'})';
}

// =============================================================================
// CONTRACT
// =============================================================================

/// Where a principal's set-up second factors live.
///
/// Reads and writes only. Deciding *whether* a factor is owed is
/// [Tom2FAPolicy]'s, issuing and verifying one is [Tom2FAService]'s; a store
/// that also decided would make the two answerable in two places.
///
/// Every method takes a [Tom2FAContext] rather than a bare principal id for the
/// same reason the adaptors do: a deployment writing its own store sees the
/// whole attempt — client, organization, locale — and one handed only an id
/// could not. What the *shipped* stores actually file rows under is narrower,
/// and is [principalKeyOf]'s to state.
abstract class Tom2FAEnrolmentStore {
  /// Every factor this principal has set up, in no guaranteed order beyond
  /// what the implementation offers.
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context);

  /// Records [enrolment], replacing any existing one with the same
  /// [Tom2FAEnrolment.enrolmentId] for this principal.
  ///
  /// Upsert rather than insert: re-running an enrolment is how a user replaces
  /// a lost authenticator, and making that path an error would leave the user
  /// with a factor they cannot use and cannot overwrite.
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment);

  /// Removes this principal's enrolment with [enrolmentId]; removing one that
  /// is not there is a no-op, not an error.
  Future<void> remove(Tom2FAContext context, String enrolmentId);

  /// The store this deployment installed, or `null`.
  ///
  /// Nullable with **no** default, unlike [Tom2FAPolicy.resolve]: a policy has
  /// a meaningful "challenge the mechanism" fallback, whereas a fallback store
  /// would
  /// be an empty one — and an empty store is indistinguishable from *this user
  /// has enrolled nothing*, which is exactly the answer callers must not be
  /// given wrongly. `null` says "no store here, ask the legacy hook"; an empty
  /// list says "asked, and this user has none".
  ///
  /// Uses [TomBean.getBeanByType] because *not installed* is an ordinary case;
  /// the resolving handle would throw.
  static Tom2FAEnrolmentStore? resolve() {
    final installed = TomBean.getBeanByType(Tom2FAEnrolmentStore);
    return installed is Tom2FAEnrolmentStore ? installed : null;
  }

  /// The storage key for the principal in [context] — the principal id, and
  /// nothing else.
  ///
  /// One place, so the memory store and the persistent store agree on what
  /// "this user" means and a test written against one is meaningful for the
  /// other.
  ///
  /// **The organization is deliberately not part of it.** [TomPrincipal.id] is
  /// unique across the deployment rather than within a tenant, so it already
  /// names one person; adding the organization would split that person's
  /// factors across the tenants they log into, so the same authenticator would
  /// have to be enrolled once per organization. Every framework table that
  /// files rows per principal rests on the same premise and carries no tenant
  /// column — `tom_principal_resource_grant`, `tom_external_identity`, and this
  /// module's own `tom_user_two_factor_enrolment`, keyed
  /// `(principal_id, enrolment_id)`.
  ///
  /// A deployment that allocates principal ids *per tenant* has broken that
  /// premise framework-wide and not merely here; its answer is its own
  /// [Tom2FAEnrolmentStore], which is handed the whole context and may key rows
  /// however it needs. That is also why this being `static` costs nothing: it
  /// is the key the two shipped stores share, not a hook the contract imposes
  /// on an implementation.
  static String principalKeyOf(Tom2FAContext context) =>
      context.principal.id.toString();
}

/// What a mechanism implements when a user can *set it up* — the third
/// question, asked only of the mechanisms that have an answer.
///
/// ## Why this is not on [Tom2FAService]
///
/// [Tom2FAService] asks two questions and says so: issue a challenge, verify a
/// submission. Enrolment is a third, and not every mechanism has one — a
/// hardware token an administrator provisions, or a mechanism backed by a
/// corporate directory, is *acquired* entirely outside the framework and has
/// nothing to offer here. Widening the base contract would force those adaptors
/// to implement a method whose only honest body is a throw, and every caller to
/// treat that throw as a normal outcome. A separate interface makes "can this be
/// enrolled?" an `is` check that [Tom2FARegistry.enrollableMethods] answers for
/// the whole registry at once.
///
/// ## Why confirmation is not optional
///
/// The pair is `begin` then `confirm`, and nothing is stored in between. Storing
/// an unconfirmed secret locks the user out of their own account whenever the QR
/// scan silently failed: the server believes a factor is enrolled, the
/// authenticator holds nothing, and the next login demands a code that cannot be
/// produced. Making the user type back a derived code proves the secret arrived
/// before it is allowed to become a login requirement.
///
/// Implementations must be stateless between the two calls, for the same reason
/// [Tom2FAService] must be: they may run on different instances. Everything the
/// confirmation needs travels in the [Tom2FAEnrolmentOffer].
abstract class Tom2FAEnrolmentSupport {
  /// Begins setting this mechanism up for [context]'s principal: generates
  /// whatever the factor needs and returns it as an offer.
  ///
  /// Nothing is persisted. Throws [TomLoginException] when this user cannot
  /// enrol this mechanism at all (no phone number on file, a quota reached).
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context);

  /// Confirms [offer] against what the user typed back, returning the enrolment
  /// to store.
  ///
  /// Returns only on success — the return type is non-nullable precisely so that
  /// "an enrolment came back" cannot mean anything but "confirmed". A wrong
  /// [submitted] throws [TomLoginException]; the caller may re-offer the same
  /// offer until [Tom2FAEnrolmentOffer.attemptsAllowed] is spent.
  ///
  /// Implementations must derive the expected answer from
  /// [Tom2FAEnrolmentOffer.enrolmentData] and never from
  /// [Tom2FAEnrolmentOffer.clientData].
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  );
}

// =============================================================================
// IN-MEMORY IMPLEMENTATION
// =============================================================================

/// A [Tom2FAEnrolmentStore] held in a map, for tests and for a deployment
/// running before its database exists.
///
/// Not a cache in front of anything and not durable: everything it holds is
/// lost with the process. That is the point — a test that must assert on the
/// login flow's branches should not need MariaDB to do it.
class TomMemory2FAEnrolmentStore implements Tom2FAEnrolmentStore {
  final Map<String, Map<String, Tom2FAEnrolment>> _byPrincipal = {};

  /// Creates an empty store.
  TomMemory2FAEnrolmentStore();

  @override
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    // Copied out, so a caller iterating the result cannot be surprised by a
    // concurrent enrolment, and cannot mutate the store by editing the list.
    return List.unmodifiable(_byPrincipal[principal]?.values ?? const []);
  }

  @override
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    (_byPrincipal[principal] ??= {})[enrolment.enrolmentId] = enrolment;
  }

  @override
  Future<void> remove(Tom2FAContext context, String enrolmentId) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    _byPrincipal[principal]?.remove(enrolmentId);
  }

  /// Drops everything, so one test's enrolments cannot reach the next.
  void clear() => _byPrincipal.clear();
}

// =============================================================================
// PERSISTENT IMPLEMENTATION
// =============================================================================

/// The persisted form of one [Tom2FAEnrolment] — a row of
/// `tom_user_two_factor_enrolment`.
///
/// Mapped through the ordinary object-persistence annotations, like every other
/// framework table that has an entity ([TomPrincipalResourceGrant],
/// [TomPrincipalDelegation]): a second persistence path for one table would
/// have to reimplement binding, row mapping and the audit hook, and would drift.
///
/// [secretData] is **not** a column. What is stored is [secretDataCipher] — the
/// JSON of the map, encrypted; see [TomPersistent2FAEnrolmentStore] for the
/// scheme and why.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_user_two_factor_enrolment',
  primaryKeyFields: ['id'],
)
class TomUserTwoFactorEnrolment {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal the factor belongs to (`TomPrincipal.id`, stringified —
  /// matching [TomPrincipalResourceGrant.principalId]).
  @TomDbColumn(columnName: 'principal_id')
  String principalId;

  /// The enrolment's stable client-facing handle
  /// ([Tom2FAEnrolment.enrolmentId]).
  @TomDbColumn(columnName: 'enrolment_id')
  String enrolmentId;

  /// The mechanism key ([Tom2FAEnrolment.type]).
  @TomDbColumn(columnName: 'mechanism')
  String mechanism;

  /// The displayable hint ([Tom2FAEnrolment.hint]).
  @TomDbColumn(columnName: 'hint')
  String hint;

  /// When the factor was set up (UTC).
  @TomDbColumn(columnName: 'enrolled_at')
  DateTime? enrolledAt;

  /// Whether this is the user's default factor.
  @TomDbColumn(columnName: 'is_primary')
  bool isPrimary;

  /// The encrypted [Tom2FAEnrolment.secretData]: base64 of RSA-OAEP over the
  /// map's JSON. Never readable from the row alone.
  @TomDbColumn(columnName: 'secret_data')
  String secretDataCipher;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomUserTwoFactorEnrolment({
    this.id = -1,
    this.principalId = '',
    this.enrolmentId = '',
    this.mechanism = '',
    this.hint = '',
    this.enrolledAt,
    this.isPrimary = false,
    this.secretDataCipher = '',
  });

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration so the two cannot drift — `test/reference_migrations_test.dart`
  /// fails if they do.
  ///
  /// `(principal_id, enrolment_id)` is unique because that pair *is* the
  /// enrolment's identity — the upsert in
  /// [TomPersistent2FAEnrolmentStore.store] relies on there being at most one
  /// row to find, and a duplicate would make which secret answers a login
  /// depend on row order.
  ///
  /// There is no tenant column, and that is a decision rather than an
  /// omission: a principal id names one person across the whole deployment, so
  /// a user's second factors are theirs in every organization they log into.
  /// See [Tom2FAEnrolmentStore.principalKeyOf] for what that premise costs a
  /// deployment that does not share it.
  ///
  /// `enrolled_at` is `DATETIME(6)`, the width the instant convention writes
  /// (`datasources/sql_instant.dart`); a plain `DATETIME` rounds off the
  /// microseconds it always renders.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_user_two_factor_enrolment (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  enrolment_id VARCHAR(255) NOT NULL,
  mechanism VARCHAR(64) NOT NULL,
  hint VARCHAR(255) NOT NULL DEFAULT '',
  enrolled_at DATETIME(6) NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  secret_data TEXT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_two_factor_enrolment (principal_id, enrolment_id),
  KEY idx_tom_user_two_factor_enrolment_principal (principal_id)
);''';
}

/// The repository for [TomUserTwoFactorEnrolment].
///
/// Shipped rather than left to the deployment (as the authorization tables are)
/// because [TomPersistent2FAEnrolmentStore] is itself shipped and would
/// otherwise be unusable without the caller writing this one empty line.
class TomUserTwoFactorEnrolmentRepository
    extends TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int> {}

/// A [Tom2FAEnrolmentStore] over `tom_user_two_factor_enrolment`, with the
/// mechanism's secret encrypted at rest.
///
/// ## The encryption scheme, and why this one
///
/// [Tom2FAEnrolment.secretData] is JSON-encoded and then passed through
/// [TomJwtConfiguration.encrypt] — **RSA-OAEP** (SHA-1 MGF1, PointyCastle's
/// `OAEPEncoding(RSAEngine())`), block-chained so a map of any size is safe,
/// base64-wrapped for a `TEXT` column. Reading it back is the inverse through
/// [TomJwtConfiguration.decrypt], with the RSA private key.
///
/// A TOTP shared secret is a *credential*: anyone holding it can generate the
/// user's codes forever, so a readable `tom_user_two_factor_enrolment` is a
/// complete 2FA bypass and a database backup is a bearer token. Storing it in
/// the clear would make the second factor security theatre against exactly the
/// attacker it exists to stop — the one who already reached the database.
///
/// The scheme is [TomJwtConfiguration]'s and not a new one because that is the
/// framework's existing at-rest/in-transit asymmetric primitive: it is what the
/// authorization token's encrypted claims section already uses, so a deployment
/// that has provisioned real keys has provisioned *these* keys, and one that has
/// not gets the same loud dummy-key warning here as everywhere else. A second,
/// 2FA-only cipher would mean a second key to rotate and a second place to get
/// it wrong.
///
/// [cipher] is a constructor argument so a deployment can hand this store a
/// **different** key pair from its token configuration — enrolment secrets are
/// long-lived where a signing key is rotated often, and a deployment that wants
/// them decoupled should not have to fork the store to get it. Unset, it
/// follows [TomJwtConfiguration.defaultSignConfiguration] at *call* time, so
/// installing production keys after boot is obeyed.
class TomPersistent2FAEnrolmentStore implements Tom2FAEnrolmentStore {
  /// The repository the store reads and writes enrolment rows through.
  final TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int> repository;

  final TomJwtConfiguration? _cipher;

  /// Creates the store over [repository], optionally with its own [cipher].
  const TomPersistent2FAEnrolmentStore(
    this.repository, {
    TomJwtConfiguration? cipher,
  }) : _cipher = cipher;

  /// The configuration used for this call — the injected one, else the current
  /// default. Resolved per call so a late key installation takes effect.
  TomJwtConfiguration get _configuration =>
      _cipher ?? TomJwtConfiguration.defaultSignConfiguration;

  @override
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context) async {
    final rows = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId',
      {'principalId': Tom2FAEnrolmentStore.principalKeyOf(context)},
    );
    return List.unmodifiable(rows.map(_toEnrolment));
  }

  @override
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment) async {
    final principalId = Tom2FAEnrolmentStore.principalKeyOf(context);
    final existing = await _rowFor(principalId, enrolment.enrolmentId);

    // Reuse the found row rather than inserting a second: the repository takes
    // its UPDATE path exactly when the surrogate key is set, so carrying the id
    // over is what makes this an upsert.
    final row = existing ?? TomUserTwoFactorEnrolment();
    row.principalId = principalId;
    row.enrolmentId = enrolment.enrolmentId;
    row.mechanism = enrolment.type;
    row.hint = enrolment.hint;
    row.enrolledAt = enrolment.enrolledAt;
    row.isPrimary = enrolment.isPrimary;
    row.secretDataCipher = _encode(enrolment.secretData);

    await repository.save(row);
  }

  @override
  Future<void> remove(Tom2FAContext context, String enrolmentId) async {
    await repository.deleteByQuerySentence(
      'DELETE BY principal_id = :principalId AND enrolment_id = :enrolmentId',
      {
        'principalId': Tom2FAEnrolmentStore.principalKeyOf(context),
        'enrolmentId': enrolmentId,
      },
    );
  }

  Future<TomUserTwoFactorEnrolment?> _rowFor(
    String principalId,
    String enrolmentId,
  ) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId AND enrolment_id = :enrolmentId',
      {'principalId': principalId, 'enrolmentId': enrolmentId},
    );
    return matches.isEmpty ? null : matches.first;
  }

  Tom2FAEnrolment _toEnrolment(TomUserTwoFactorEnrolment row) =>
      Tom2FAEnrolment(
        type: row.mechanism,
        enrolmentId: row.enrolmentId,
        hint: row.hint,
        enrolledAt: row.enrolledAt,
        isPrimary: row.isPrimary,
        secretData: _decode(row.secretDataCipher),
      );

  /// Encrypts [secretData] for storage; an empty map is stored as an empty
  /// string rather than as ciphertext of `{}`, so a mechanism that keeps no
  /// secret costs no key operation and leaves nothing to decrypt.
  String _encode(Map<String, Object?> secretData) =>
      secretData.isEmpty ? '' : _configuration.encrypt(jsonEncode(secretData));

  /// Decrypts a stored [cipherText] back into the mechanism's map.
  ///
  /// A row that cannot be decrypted — written under a key that has since been
  /// rotated away — yields an **empty** map rather than throwing. The caller is
  /// a login, and the honest reading of "the secret is unrecoverable" is *this
  /// factor cannot answer a challenge*, which an empty map already expresses:
  /// the adaptor finds no secret and the login fails as not-enrolled. Throwing
  /// would instead fail the *whole* login, including the user's other, perfectly
  /// good factors.
  Map<String, Object?> _decode(String cipherText) {
    if (cipherText.isEmpty) return const {};
    try {
      final decoded = jsonDecode(_configuration.decrypt(cipherText));
      return decoded is Map<String, Object?> ? decoded : const {};
    } catch (error) {
      // Logged without the ciphertext and without the error's own message: a
      // decryption failure's detail is about the key, and this line is destined
      // for a log an operator reads.
      tomLog.error(
        'Undecryptable 2FA enrolment secret (${error.runtimeType}); '
        'treating the enrolment as unusable',
      );
      return const {};
    }
  }
}
