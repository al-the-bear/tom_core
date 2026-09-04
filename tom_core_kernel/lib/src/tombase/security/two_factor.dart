/// The wire shape of a pending second-factor (2FA) challenge.
///
/// The framework's login is a two-pass flow: pass 1 verifies the primary
/// credential, and — when the resolved principal still owes a second factor —
/// answers with a token that is *not yet* an authenticated session but a
/// **challenge carrier**. Pass 2 takes that token plus the submitted second
/// factor and, on success, returns exactly the token pair a 2FA-free login
/// would have produced.
///
/// ## Why the challenge lives in the token
///
/// Bearer verification in this framework is stateless: every server call
/// reconstructs the principal from the presented token and nothing else. A
/// pending challenge is therefore carried the same way — in the interim token's
/// claims — rather than in a server-side "pending login" record. That keeps
/// pass 2 stateless too (any server instance can complete a login started by
/// any other) and needs no new fields on the fixed wire types
/// [TomAuthenticationMessage] / [TomAuthenticationResult].
///
/// ## Public claims vs. encrypted claims
///
/// [Tom2FAChallenge] is the **client-visible** half: which mechanism is in
/// play, a displayable [hint], how many attempts remain, when the challenge
/// lapses, and an opaque [clientData] map the mechanism's own client UI
/// interprets. Whatever the *server* needs to verify a submission (a hashed
/// one-time code, a nonce, …) is deliberately **not** here — it travels in the
/// token's encrypted section under [Tom2FAClaims.verificationData], where the
/// client cannot read it.
///
/// The server never interprets [clientData] or the verification blob; both are
/// produced and consumed by the mechanism's adaptor. That is what keeps the
/// mechanism set out of the framework: adding SMS or WebAuthn needs no change
/// here.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../reflection/reflection.dart';
import 'authentication_authorization.dart';

/// The claim names under which a pending 2FA challenge travels in a token.
///
/// Collected in one place because they are written by the server (when issuing
/// the interim token) and read by the client (to drive the second-factor UI) —
/// two sides that must agree exactly. All but [verificationData] are public
/// claims; [verificationData] is a key in the token's **encrypted** section.
class Tom2FAClaims {
  Tom2FAClaims._();

  /// Public claim: `"true"` while the token still owes a second factor.
  ///
  /// A string rather than a bool because the surrounding payload has always
  /// encoded it that way; changing the encoding would break tokens in flight.
  /// Written as a string by every Tom tier — but **read with [isTrue]**, which
  /// accepts the JSON boolean too. This claim gates `authenticated`, so a
  /// reader that missed the other encoding would fail open.
  static const String requires2FA = 'requires2FA';

  /// Public claim: the mechanism key (e.g. `'totp'`) the challenge belongs to.
  static const String type = 'twoFactorType';

  /// Public claim: a short, displayable hint (e.g. a masked phone number).
  static const String hint = 'twoFactorHint';

  /// Public claim: how many verification attempts have already been consumed.
  static const String attempt = 'twoFactorAttempt';

  /// Public claim: how many attempts the challenge allows in total.
  static const String attemptsAllowed = 'twoFactorAttemptsAllowed';

  /// Public claim: ISO-8601 UTC instant at which the challenge lapses.
  static const String expiresAt = 'twoFactorExpiresAt';

  /// Public claim: the mechanism's opaque, client-interpreted payload.
  static const String clientData = 'twoFactorClientData';

  /// **Encrypted** claim: the mechanism's server-only verification payload.
  ///
  /// Lives in the encrypted section precisely so a client cannot read (or
  /// usefully forge) what it would need to answer its own challenge.
  static const String verificationData = 'twoFactorVerification';

  /// Reads a boolean claim that may have crossed the wire in either encoding.
  ///
  /// **The single rule for every boolean claim in both 2FA claim families** —
  /// this one and [Tom2FAEnrolmentClaims] — on both tiers. The two families
  /// disagree about encoding for historical reasons: [requires2FA] and
  /// [Tom2FAEnrolmentClaims.pendingEnrolment] are strings, while
  /// [Tom2FAEnrolmentClaims.skippable] and
  /// [Tom2FAEnrolmentClaims.skipSpendsGrace] are JSON booleans. A deployment
  /// mixing framework versions can plausibly present either, so reading both
  /// costs one comparison and removes an entire class of upgrade report.
  ///
  /// Applying it to the *gates* — the reads that decide whether a token
  /// authenticates, and whether a challenge or enrolment is built at all — is
  /// the point, not a convenience. At every one of them leniency is the
  /// fail-safe direction: reading `true` as well as `"true"` makes more tokens
  /// count as still owing a second factor, and makes more challenges and
  /// enrolments renderable. The strict reading fails the other way, and at
  /// [requires2FA] it fails *open* — a token that says, in the encoding this
  /// reader did not expect, that it has not finished logging in would
  /// otherwise authenticate.
  ///
  /// Deliberately **not** general truthiness: only the two encodings the
  /// framework itself produces are accepted. `'True'`, `1` and `'yes'` are
  /// not, because widening past what any Tom tier writes would start guessing
  /// at other issuers' conventions rather than reconciling our own.
  static bool isTrue(Object? raw) => raw == true || raw == 'true';
}

/// The claim names under which a pending 2FA *enrolment* travels in a token.
///
/// Deliberately a sibling of [Tom2FAClaims] rather than more entries in it: a
/// token can be owed a second factor and be part-way through setting one up,
/// and a single set of names could not express both at once — a forced
/// enrolment is precisely the case where the two overlap.
///
/// The split follows [Tom2FAClaims] exactly. Everything but [offerData] is a
/// public claim the enrolment UI reads; [offerData] is a key in the token's
/// **encrypted** section, because it carries the freshly generated secret and
/// the server must confirm the typed code against *its own* copy rather than
/// against whatever came back from the client.
class Tom2FAEnrolmentClaims {
  Tom2FAEnrolmentClaims._();

  /// Public claim: `"true"` while the token has an enrolment awaiting
  /// confirmation. Encoded as a string for the same reason
  /// [Tom2FAClaims.requires2FA] is, and read with [Tom2FAClaims.isTrue] for
  /// the same reason too.
  static const String pendingEnrolment = 'pendingEnrolment';

  /// Public claim: the mechanism key (e.g. `'totp'`) being enrolled.
  static const String type = 'enrolmentType';

  /// Public claim: a short, displayable hint for the factor being set up.
  static const String hint = 'enrolmentHint';

  /// Public claim: how many confirmation attempts have already been consumed.
  static const String attempt = 'enrolmentAttempt';

  /// Public claim: how many confirmation attempts the offer allows in total.
  static const String attemptsAllowed = 'enrolmentAttemptsAllowed';

  /// Public claim: ISO-8601 UTC instant at which the offer lapses.
  static const String expiresAt = 'enrolmentExpiresAt';

  /// Public claim: the mechanism's client-interpreted enrolment payload — for
  /// TOTP the base32 secret and the `otpauth://` URI the user scans.
  ///
  /// Public because delivering it to the user *is* the enrolment; it is secret
  /// from everyone except the account's owner, who is the party holding this
  /// token.
  static const String clientData = 'enrolmentClientData';

  /// **Encrypted** claim: the whole offer, including the mechanism's server-only
  /// section, so any instance can confirm what another began.
  static const String offerData = 'enrolmentOffer';

  /// Public claim: the mechanism keys this principal was offered, in preference
  /// order.
  ///
  /// Carried rather than recomputed because the offer is what the *server*
  /// permitted at the moment the login branched: a client that came back naming
  /// a mechanism must be checked against the list it was actually given, not
  /// against whatever the policy would answer on a second evaluation.
  static const String offeredTypes = 'enrolmentOfferedTypes';

  /// Public claim: `true` when the user may decline the offer and complete the
  /// login without a second factor. A JSON boolean, unlike the string-encoded
  /// [Tom2FAClaims.requires2FA] — this claim is newer and has no tokens in
  /// flight to stay compatible with. That the two families disagree on
  /// encoding is exactly why both are read with [Tom2FAClaims.isTrue].
  ///
  /// Decided once, on the pass that made the offer, and carried — so the
  /// authority for "may I skip?" is the token the server signed, never a flag
  /// the client sends back.
  static const String skippable = 'enrolmentSkippable';

  /// Public claim: `true` when declining the offer spends one of the
  /// principal's grace logins rather than being free. A JSON boolean, like
  /// [skippable].
  ///
  /// Recorded on the pass that made the offer because that pass is the one that
  /// knows *why* skipping was allowed — an optional policy (free) or a required
  /// one with grace left (charged). Re-deriving it at skip time would ask the
  /// policy a second question whose answer had already been acted on.
  static const String skipSpendsGrace = 'enrolmentSkipSpendsGrace';
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
///
/// ## Why it lives in the kernel
///
/// It is produced by the server's mechanism registry but consumed by a client
/// rendering a choice, and it travels between them inside
/// [TomAuthenticationResult.availableTwoFactorMethods]. That makes it a wire
/// type, and wire types live where both tiers can see them — beside
/// [Tom2FAChallenge], which is client-visible for the same reason.
@tomReflector
class Tom2FAMethodDescriptor {
  /// The scope every shipped mechanism's keys live under, so a resource bundle
  /// can be searched for "everything the 2FA catalog needs" by prefix.
  static const String resourceScope = 'two_factor';

  /// The mechanism key this descriptor belongs to — the same value the
  /// server's registry resolves and a challenge dispatches on.
  String type = '';

  /// Resource key of the mechanism's short label ("Authenticator app").
  String displayNameKey = '';

  /// Resource key of the one-sentence explanation shown beside the label.
  String descriptionKey = '';

  /// Resource key of the icon to render. A key rather than an asset path
  /// because the two client tiers (Flutter, web) name their assets
  /// differently, and the mechanism must not have to know which one is asking.
  String iconKey = '';

  /// Describes a mechanism with explicitly chosen keys.
  ///
  /// Prefer [Tom2FAMethodDescriptor.scoped] unless the mechanism's text really
  /// does live outside the [resourceScope] convention — a deployment adapting a
  /// vendor SDK whose strings already ship under another prefix, say.
  ///
  /// Every parameter is optional, and the fields are mutable, because this is a
  /// wire DTO: reflection constructs it empty and fills it in (G-DTO-1/2).
  Tom2FAMethodDescriptor({
    this.type = '',
    this.displayNameKey = '',
    this.descriptionKey = '',
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

/// A second-factor challenge awaiting an answer.
///
/// Produced by the server at the end of pass 1 and carried in the interim
/// token's public claims. Immutable: consuming an attempt yields a new instance
/// via [withConsumedAttempt] rather than mutating in place, so the value can be
/// passed around without anyone wondering who advanced the counter.
class Tom2FAChallenge {
  /// The mechanism this challenge belongs to (e.g. `'totp'`).
  final String type;

  /// A short, displayable hint for the user — e.g. `'***-**-4711'`.
  ///
  /// Free-form and mechanism-specific; empty when the mechanism has nothing
  /// useful to show (an authenticator app, for instance, needs no hint).
  final String hint;

  /// How many verification attempts have already been consumed.
  final int attempt;

  /// How many attempts this challenge allows before it is burned.
  final int attemptsAllowed;

  /// The UTC instant after which this challenge is no longer answerable.
  final DateTime expiresAt;

  /// The mechanism's opaque, client-interpreted payload.
  ///
  /// The framework passes it through untouched; only the mechanism's own client
  /// code knows what is in it.
  final Map<String, Object?> clientData;

  /// Creates a challenge. [expiresAt] is normalised to UTC here, which is the
  /// only place that can make the field's promise good: every other path
  /// reaches the field directly, so a caller that passed a local instant would
  /// otherwise hand its own zone on to whoever renders the countdown.
  Tom2FAChallenge({
    required this.type,
    required DateTime expiresAt,
    this.hint = '',
    this.attempt = 0,
    this.attemptsAllowed = 3,
    this.clientData = const {},
  }) : expiresAt = expiresAt.toUtc();

  /// Whether the challenge has lapsed as of [now] (defaults to the current
  /// instant). An expired challenge can no longer be answered; the client must
  /// restart at pass 1.
  ///
  /// [now] may be in either zone: `isBefore` compares instants, not wall
  /// clocks, so no normalisation is needed on either side.
  bool isExpired([DateTime? now]) =>
      !(now ?? DateTime.now()).isBefore(expiresAt);

  /// How many attempts are still available. Never negative.
  int get attemptsRemaining {
    final remaining = attemptsAllowed - attempt;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether every allowed attempt has been consumed.
  bool get isExhausted => attemptsRemaining <= 0;

  /// This challenge with one more attempt consumed.
  Tom2FAChallenge withConsumedAttempt() => Tom2FAChallenge(
    type: type,
    hint: hint,
    attempt: attempt + 1,
    attemptsAllowed: attemptsAllowed,
    expiresAt: expiresAt,
    clientData: clientData,
  );

  /// Projects this challenge onto the public token claims (see [Tom2FAClaims]).
  ///
  /// Includes [Tom2FAClaims.requires2FA]`: "true"` — a token carrying a
  /// challenge is by definition not yet a completed login.
  Map<String, Object?> toClaims() => {
    Tom2FAClaims.requires2FA: 'true',
    Tom2FAClaims.type: type,
    Tom2FAClaims.hint: hint,
    Tom2FAClaims.attempt: attempt,
    Tom2FAClaims.attemptsAllowed: attemptsAllowed,
    Tom2FAClaims.expiresAt: expiresAt.toIso8601String(),
    Tom2FAClaims.clientData: clientData,
  };

  /// Reads a challenge back from a token's public [payload], or returns `null`
  /// when the payload carries none.
  ///
  /// Tokens arrive from outside the process, so every claim is read
  /// defensively. A payload that says it requires 2FA but carries an unusable
  /// mechanism or expiry yields `null` — the caller then treats the token as
  /// simply not answerable, which is the safe reading.
  ///
  /// "Says it requires 2FA" is decided by [Tom2FAClaims.isTrue], so a payload
  /// carrying either encoding is decoded. Being defensive about *shape* and
  /// lenient about *encoding* point the same way here: both keep a token that
  /// owes a factor from quietly looking like one that does not.
  ///
  /// The remaining claims fall back instead of rejecting, and all but one fall
  /// back to what the constructor would have chosen anyway ([hint] to `''`,
  /// [attempt] to `0`). [attemptsAllowed] is the exception: it falls back to
  /// `0`, *not* to the constructor's `3`, so a challenge whose budget is
  /// unreadable arrives already [isExhausted]. That is deliberate and
  /// fail-closed — a malformed token must not be able to mint attempts. Being
  /// sent back to pass 1 on a challenge that was in fact answerable is a
  /// recoverable annoyance; handing three free guesses to whoever shaped the
  /// payload is not. [Tom2FAPendingEnrolment.fromClaims] does the same.
  static Tom2FAChallenge? fromClaims(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (!Tom2FAClaims.isTrue(payload[Tom2FAClaims.requires2FA])) return null;

    final type = payload[Tom2FAClaims.type];
    if (type is! String || type.isEmpty) return null;

    final expiresAtRaw = payload[Tom2FAClaims.expiresAt];
    if (expiresAtRaw is! String) return null;
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) return null;

    final hint = payload[Tom2FAClaims.hint];
    final attempt = payload[Tom2FAClaims.attempt];
    final attemptsAllowed = payload[Tom2FAClaims.attemptsAllowed];
    final clientData = payload[Tom2FAClaims.clientData];

    return Tom2FAChallenge(
      type: type,
      hint: hint is String ? hint : '',
      attempt: attempt is int ? attempt : 0,
      attemptsAllowed: attemptsAllowed is int ? attemptsAllowed : 0,
      expiresAt: expiresAt,
      clientData: clientData is Map
          ? clientData.cast<String, Object?>()
          : const <String, Object?>{},
    );
  }

  @override
  String toString() =>
      'Tom2FAChallenge $type hint: $hint attempt: $attempt/$attemptsAllowed '
      'expires: ${expiresAt.toIso8601String()}';
}

/// A second-factor **enrolment** awaiting the user's next move — the exact
/// analogue of [Tom2FAChallenge], one step earlier in the story.
///
/// Where a challenge says "prove you hold the factor you already set up", a
/// pending enrolment says "you have none; here are the mechanisms you may set
/// up, and here is the one you picked, half-built". Both ride in an interim
/// token's public claims and both leave the principal unauthenticated, so the
/// client's job is the same shape in each case: read the claims, render the
/// mechanism's panel, post an answer.
///
/// ## Two states, one type
///
/// The flow has two stops and this type covers both, distinguished by
/// [hasOffer]:
///
/// * **Choosing** — [offeredTypes] is populated and [type] is empty. The client
///   renders a chooser (or skips straight past it when only one mechanism is on
///   offer) and posts the chosen key back.
/// * **Confirming** — [type] names the mechanism and [clientData] carries what
///   the user needs to set it up (for TOTP: the `otpauth://` URI and the base32
///   secret). The client renders that mechanism's enrolment panel and posts the
///   confirmation code.
///
/// One type rather than two because a single token claim set carries whichever
/// stop the login is at, and a client that had to pick between two readers
/// before knowing which it held would only be re-deriving [hasOffer].
///
/// ## Why the client gets its own view
///
/// The server has a richer reading of the same token — it can also decrypt
/// [Tom2FAEnrolmentClaims.offerData] and recover the secret it generated. That
/// reading necessarily lives server-side. The client needs, and may have, only
/// the public half; giving it a type of its own means a client tier never
/// imports a server type to read a token it legitimately holds.
class Tom2FAPendingEnrolment {
  /// The mechanism being enrolled, or empty while the user is still choosing.
  final String type;

  /// A short, displayable hint for the factor being set up; empty when the
  /// mechanism has nothing useful to show.
  final String hint;

  /// How many confirmation attempts have already been consumed.
  final int attempt;

  /// How many confirmation attempts this offer allows before it is burned.
  final int attemptsAllowed;

  /// The UTC instant after which this offer is no longer answerable, or `null`
  /// while the user is still choosing.
  ///
  /// Nullable because the deadline belongs to the *mechanism's* offer, not to
  /// the choice: nothing has been generated yet at the choosing stop, so there
  /// is nothing that could go stale. The server projects this claim only once a
  /// mechanism has been picked.
  final DateTime? expiresAt;

  /// The mechanism's opaque, client-interpreted enrolment payload — passed
  /// through untouched by the framework, understood only by the mechanism's own
  /// client code. Empty while the user is still choosing.
  final Map<String, Object?> clientData;

  /// The mechanism keys this principal was offered, in preference order.
  final List<String> offeredTypes;

  /// Whether the user may decline and complete the login without a factor.
  final bool skippable;

  /// Whether declining spends one of the principal's grace logins.
  final bool skipSpendsGrace;

  /// Creates a pending enrolment. [expiresAt] is normalised to UTC for the
  /// same reason [Tom2FAChallenge]'s is — and stays `null` when it was `null`,
  /// since the choosing stop has no deadline to normalise.
  Tom2FAPendingEnrolment({
    DateTime? expiresAt,
    this.type = '',
    this.hint = '',
    this.attempt = 0,
    this.attemptsAllowed = 3,
    this.clientData = const {},
    this.offeredTypes = const [],
    this.skippable = false,
    this.skipSpendsGrace = false,
  }) : expiresAt = expiresAt?.toUtc();

  /// Whether a mechanism has been chosen and its enrolment begun — i.e. whether
  /// the client should render the mechanism's panel rather than the chooser.
  bool get hasOffer => type.isNotEmpty;

  /// Whether the offer has lapsed as of [now] (defaults to the current
  /// instant). A lapsed offer can no longer be answered; the client must
  /// restart at pass 1.
  ///
  /// Always false while the user is still choosing — there is no generated
  /// material to go stale, so a chooser left open is a UX question, not a
  /// security one.
  ///
  /// A *begun* offer with no [expiresAt] is the opposite case and answers true.
  /// [fromClaims] never builds one, so this is the backstop for a directly
  /// constructed value; it answers as the server would, because a panel that
  /// showed a live confirmation form for a state the server refuses is worse
  /// than one that says the offer lapsed.
  ///
  /// [now] may be in either zone: `isBefore` compares instants, not wall
  /// clocks, so no normalisation is needed on either side.
  bool isExpired([DateTime? now]) {
    final deadline = expiresAt;
    if (deadline == null) return hasOffer;
    return !(now ?? DateTime.now()).isBefore(deadline);
  }

  /// How many confirmation attempts are still available. Never negative.
  ///
  /// Zero while the user is still choosing, because the budget belongs to the
  /// *mechanism's* offer and no mechanism has been picked — there is nothing
  /// to attempt, not nothing left. Read [isExhausted] rather than this for the
  /// question "may this still be answered", which accounts for the difference.
  int get attemptsRemaining {
    final remaining = attemptsAllowed - attempt;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether every allowed confirmation attempt has been consumed.
  ///
  /// Always false while the user is still choosing — the same reading
  /// [isExpired] gives the deadline, and for the same reason. The attempt
  /// budget belongs to the *mechanism's* offer, so the choosing stop carries no
  /// budget claim at all, and an absent claim reads back as zero
  /// ([fromClaims]' fail-closed fallback). Without the [hasOffer] guard a
  /// chooser would report attempts burned against a mechanism that was never
  /// generated.
  ///
  /// The guard is transparent to the fail-closed rule it sits next to: on a
  /// *begun* offer [hasOffer] is true, so an unreadable budget still arrives
  /// already exhausted. It matches `Tom2FAEnrolmentState.isExhausted` on the
  /// server, which has to be read the same way or a client would restart a
  /// login the server is still willing to continue.
  bool get isExhausted => hasOffer && attemptsRemaining <= 0;

  /// Reads a pending enrolment back from a token's public [payload], or returns
  /// `null` when the payload carries none.
  ///
  /// Read as defensively as [Tom2FAChallenge.fromClaims], and for the same
  /// reason: the payload came from outside the process. A token that says it
  /// has a pending enrolment but carries neither a chosen mechanism nor an
  /// offer to choose from yields `null` — there is nothing a client could
  /// render, and pretending otherwise would strand the login on a blank panel.
  ///
  /// A *begun* enrolment whose expiry is unreadable is likewise `null`: the
  /// deadline is what stops a generated secret being confirmable forever, so a
  /// panel that could not tell the user when the offer lapses must not be
  /// rendered at all.
  ///
  /// [attemptsAllowed] falls back to `0` rather than to the constructor's `3`,
  /// so an offer whose budget is unreadable arrives already [isExhausted] —
  /// the same fail-closed rule [Tom2FAChallenge.fromClaims] applies, for the
  /// same reason.
  static Tom2FAPendingEnrolment? fromClaims(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (!Tom2FAClaims.isTrue(payload[Tom2FAEnrolmentClaims.pendingEnrolment])) {
      return null;
    }

    final typeRaw = payload[Tom2FAEnrolmentClaims.type];
    final type = typeRaw is String ? typeRaw : '';

    final offeredRaw = payload[Tom2FAEnrolmentClaims.offeredTypes];
    final offeredTypes = offeredRaw is List
        ? offeredRaw.whereType<String>().where((e) => e.isNotEmpty).toList()
        : const <String>[];

    // Neither a mechanism in flight nor a list to choose from: unrenderable.
    if (type.isEmpty && offeredTypes.isEmpty) return null;

    final expiresAtRaw = payload[Tom2FAEnrolmentClaims.expiresAt];
    final expiresAt = expiresAtRaw is String
        ? DateTime.tryParse(expiresAtRaw)
        : null;
    // The choosing stop legitimately carries no deadline; a begun one must.
    if (type.isNotEmpty && expiresAt == null) return null;

    final hint = payload[Tom2FAEnrolmentClaims.hint];
    final attempt = payload[Tom2FAEnrolmentClaims.attempt];
    final attemptsAllowed = payload[Tom2FAEnrolmentClaims.attemptsAllowed];
    final clientData = payload[Tom2FAEnrolmentClaims.clientData];

    return Tom2FAPendingEnrolment(
      type: type,
      hint: hint is String ? hint : '',
      attempt: attempt is int ? attempt : 0,
      attemptsAllowed: attemptsAllowed is int ? attemptsAllowed : 0,
      expiresAt: expiresAt,
      clientData: clientData is Map
          ? clientData.cast<String, Object?>()
          : const <String, Object?>{},
      offeredTypes: offeredTypes,
      skippable: Tom2FAClaims.isTrue(payload[Tom2FAEnrolmentClaims.skippable]),
      skipSpendsGrace: Tom2FAClaims.isTrue(
        payload[Tom2FAEnrolmentClaims.skipSpendsGrace],
      ),
    );
  }

  @override
  String toString() =>
      'Tom2FAPendingEnrolment '
      '${hasOffer ? type : 'choosing from $offeredTypes'} '
      'attempt: $attempt/$attemptsAllowed skippable: $skippable '
      'expires: ${expiresAt?.toIso8601String() ?? '-'}';
}

/// The RFC 4226 (HOTP) / RFC 6238 (TOTP) derivation primitives, and the base32
/// codec authenticator secrets are exchanged in.
///
/// Pure functions of their inputs — no clock, no configuration, no state — so
/// they say nothing about *policy* (how wide a skew window to accept, how many
/// digits to demand). Policy belongs to whoever verifies; this class only
/// answers "what is the code for this secret and this counter?".
///
/// ## Why this lives in the kernel
///
/// Three tiers need the same answer and must not disagree about it: the server
/// verifying a submitted code, enrolment tooling handing a fresh secret to a
/// user, and a client or authenticator producing the code in the first place.
/// A second implementation anywhere would be a second opportunity to be subtly
/// wrong — and a one-digit disagreement here reads as "the user typed it
/// wrong", which is a miserable bug to chase. So the derivation is defined once,
/// in the package every tier already depends on.
class TomTotp {
  TomTotp._();

  /// The RFC 4648 base32 alphabet, which is what authenticator secrets use.
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// The number of digits RFC 6238 defaults to.
  static const int defaultDigits = 6;

  /// The time step RFC 6238 defaults to.
  static const Duration defaultPeriod = Duration(seconds: 30);

  /// The RFC 6238 time-step counter for [at] (default: now) given [period].
  ///
  /// Centralised because the counter is where the two sides of a TOTP exchange
  /// most easily drift apart: it is UTC seconds — not milliseconds, not local
  /// time — divided by the step.
  ///
  /// Throws [ArgumentError] unless [period] is at least one second. The step is
  /// taken as `period.inSeconds`, which truncates, so a sub-second period is
  /// rejected as well as a zero or negative one — it is a positive duration
  /// that would still divide by zero.
  static int counterFor({DateTime? at, Duration period = defaultPeriod}) {
    final step = period.inSeconds;
    if (step <= 0) {
      throw ArgumentError.value(
        period,
        'period',
        'must be at least one second',
      );
    }
    final seconds =
        (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    return seconds ~/ step;
  }

  /// Generates the RFC 4226 HOTP value for [counter] from the raw [key].
  ///
  /// [key] is the *decoded* secret — run a base32 authenticator secret through
  /// [decodeBase32] first. The result is always [digits] characters, zero-padded
  /// on the left, because a code that lost its leading zero would not match.
  static String generateCode(
    List<int> key,
    int counter, [
    int digits = defaultDigits,
  ]) {
    final counterBytes = Uint8List(8);
    var remaining = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = remaining & 0xff;
      remaining = remaining >> 8;
    }
    final mac = Hmac(sha1, key).convert(counterBytes).bytes;
    // Dynamic truncation (RFC 4226 §5.3): the low nibble of the last byte
    // selects which four bytes of the digest become the code.
    final offset = mac[mac.length - 1] & 0x0f;
    final binary =
        ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
    final modulus = pow(10, digits).toInt();
    return (binary % modulus).toString().padLeft(digits, '0');
  }

  /// The TOTP code for the base32 [secret] at [at] (default: now).
  ///
  /// The convenience an authenticator or an enrolment self-check wants: it hides
  /// the decode-and-count step that is the usual source of a mismatch. Returns
  /// an empty string when [secret] is not decodable, so a bad secret shows up as
  /// a code that matches nothing rather than as a thrown exception in a UI.
  static String codeFor(
    String secret, {
    DateTime? at,
    int digits = defaultDigits,
    Duration period = defaultPeriod,
  }) {
    final key = decodeBase32(secret);
    if (key.isEmpty) return '';
    return generateCode(key, counterFor(at: at, period: period), digits);
  }

  /// Decodes an RFC 4648 base32 [secret] into raw bytes.
  ///
  /// Case-insensitive; spaces, `-` separators and `=` padding are ignored,
  /// because authenticator secrets are routinely shown to users in grouped
  /// lowercase. Returns an empty list for input containing a character outside
  /// the alphabet — an unusable secret, which the caller turns into a failed
  /// verification rather than a guess.
  static List<int> decodeBase32(String secret) {
    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final rune in secret.toUpperCase().runes) {
      final char = String.fromCharCode(rune);
      if (char == '=' || char == ' ' || char == '-') continue;
      final value = _base32Alphabet.indexOf(char);
      if (value < 0) return const [];
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 0xff);
      }
    }
    return bytes;
  }

  /// Encodes raw [bytes] as an RFC 4648 base32 secret (no padding).
  ///
  /// The counterpart of [decodeBase32], for enrolment tooling that generates a
  /// secret and must hand the same value to an authenticator app.
  static String encodeBase32(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xff);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_base32Alphabet[(buffer >> bits) & 0x1f]);
      }
    }
    if (bits > 0) out.write(_base32Alphabet[(buffer << (5 - bits)) & 0x1f]);
    return out.toString();
  }
}
