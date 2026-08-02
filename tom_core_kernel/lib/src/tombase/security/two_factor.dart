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
  /// [Tom2FAClaims.requires2FA] is.
  static const String pendingEnrolment = 'pendingEnrolment';

  /// Public claim: the mechanism key (e.g. `'totp'`) being enrolled.
  static const String type = 'enrolmentType';

  /// Public claim: a short, displayable hint for the factor being set up.
  static const String hint = 'enrolmentHint';

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

  /// Creates a challenge. [expiresAt] is normalised to UTC so comparisons are
  /// unambiguous regardless of who constructed it.
  Tom2FAChallenge({
    required this.type,
    required this.expiresAt,
    this.hint = '',
    this.attempt = 0,
    this.attemptsAllowed = 3,
    this.clientData = const {},
  });

  /// Whether the challenge has lapsed as of [now] (defaults to the current
  /// instant). An expired challenge can no longer be answered; the client must
  /// restart at pass 1.
  bool isExpired([DateTime? now]) =>
      !(now ?? DateTime.now().toUtc()).toUtc().isBefore(expiresAt.toUtc());

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
        Tom2FAClaims.expiresAt: expiresAt.toUtc().toIso8601String(),
        Tom2FAClaims.clientData: clientData,
      };

  /// Reads a challenge back from a token's public [payload], or returns `null`
  /// when the payload carries none.
  ///
  /// Tokens arrive from outside the process, so every claim is read
  /// defensively: a payload that says it requires 2FA but carries an unusable
  /// mechanism or expiry yields `null` rather than a half-built challenge — the
  /// caller then treats the token as simply not answerable, which is the safe
  /// reading.
  static Tom2FAChallenge? fromClaims(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload[Tom2FAClaims.requires2FA] != 'true') return null;

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
      expiresAt: expiresAt.toUtc(),
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
  static int counterFor({DateTime? at, Duration period = defaultPeriod}) {
    final step = period.inSeconds;
    if (step <= 0) {
      throw ArgumentError.value(period, 'period', 'must be a positive duration');
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
    final binary = ((mac[offset] & 0x7f) << 24) |
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
