/// The server-side state that turns the two-factor attempt counter into a
/// bound.
///
/// ## What the counter in the token cannot do
///
/// Second-pass verification carries its attempt count inside the interim token
/// and advances it only along the chain of tokens the server hands back. That
/// makes the pass stateless, which is worth having — no pending-login table, no
/// row to clean up, no second trip to the user store — and it means the count
/// bounds a **cooperative** client only.
///
/// An uncooperative one replays an earlier token in the chain. That token is
/// still inside the challenge's validity and still carries its lower count, and
/// a server holding no record of what it has already answered cannot tell the
/// replay from the original presentation. So the attacker asks again, and
/// again, with a fresh allowance each time. What used to bound them was the
/// challenge's own validity — and a six-digit code inside a five-minute window
/// admits as many guesses as they can fit requests into five minutes, which is
/// not a bound on anything.
///
/// ## What closes it
///
/// One fact, recorded once per interim token: *this token has been answered*.
/// Each token in the chain is then answerable exactly once, and since a wrong
/// answer is what mints the next token, the whole chain admits exactly
/// `attemptsAllowed` guesses — however the attacker orders it. That is the hard
/// per-challenge cap, and it needs no challenge id, no pending-login row and no
/// per-user counter: the token's own identity is enough.
///
/// [Tom2FAAttemptStore] is where that fact goes. It is deliberately a seam
/// rather than an implementation detail, because *where* the record lives is a
/// topology question the framework cannot answer: a single process is served by
/// the in-memory default, a load-balanced cluster needs one the nodes share.
/// [Tom2FAMemoryAttemptStore] is installed by default and is honest about being
/// per-process — on three nodes a determined attacker gets three times the
/// allowance, which is still a bound and still finite, where before there was
/// none.
///
/// A deployment that genuinely wants the old stateless behaviour installs a
/// store whose [Tom2FAAttemptStore.spend] always answers `true`. That is the
/// point of a seam: the choice is made by installing something, not by forking
/// the pass.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// One presentation of an interim two-factor token, offered to the store.
///
/// Carries more than the fingerprint the default store keys on, because the
/// seam is also where a deployment would put a per-principal rate limit — the
/// other remedy for the same attack — and such a limiter needs to know whose
/// attempt it is refusing.
class Tom2FAAttempt {
  /// Describes one presentation.
  const Tom2FAAttempt({
    required this.fingerprint,
    required this.username,
    required this.challengeType,
    required this.notAfter,
  });

  /// A stable, opaque identifier for the presented token.
  ///
  /// A digest rather than the token — see [tom2FATokenFingerprint]. An attempt
  /// log is not a place to keep usable bearer credentials, and a store is
  /// exactly the sort of thing a deployment points at shared infrastructure.
  final String fingerprint;

  /// Who the chain belongs to, as the token's subject names them.
  final String username;

  /// The mechanism the challenge belongs to (`'totp'`, `'sms'`, …).
  final String challengeType;

  /// When the challenge lapses.
  ///
  /// After it, every token in the chain is refused for being expired, so a
  /// record older than this bounds nothing and a store may drop it.
  final DateTime notAfter;

  @override
  String toString() =>
      'Tom2FAAttempt($username/$challengeType, expires $notAfter)';
}

/// Records which interim two-factor tokens have already been answered.
///
/// Resolved through [resolve], so a deployment installs one as a bean the way
/// it installs a `Tom2FAEnrolmentStore` (G-DI-3). Unlike that one, a missing
/// installation does not mean "the feature is off": the default is
/// [Tom2FAMemoryAttemptStore], because a bound that has to be opted into is a
/// bound most deployments will not have.
abstract class Tom2FAAttemptStore {
  /// Records [attempt] and reports whether this token had **not** been answered
  /// before.
  ///
  /// `true` lets the verification proceed; `false` refuses it with
  /// `login.error.2fa.challenge-already-answered`. One call rather than a
  /// separate check and write, so that two requests racing on one token cannot
  /// both be told they are the first — an implementation over shared storage
  /// makes this atomic (an insert whose unique key is the fingerprint, and a
  /// duplicate-key error read as `false`).
  ///
  /// Called **before** the mechanism is asked, so a refused replay costs the
  /// attacker a request and buys them no information.
  Future<bool> spend(Tom2FAAttempt attempt);

  /// The installed store, or the process-wide default.
  ///
  /// Never `null`: an absent installation is a single-process deployment, not a
  /// deployment that wants no bound. A deployment that does want none installs
  /// a store that always answers `true`.
  static Tom2FAAttemptStore resolve() {
    final installed = TomBean.getBeanByType(Tom2FAAttemptStore);
    return installed is Tom2FAAttemptStore
        ? installed
        : Tom2FAMemoryAttemptStore.shared;
  }
}

/// The default store: a map in this process.
///
/// **Per process, and says so.** In a load-balanced cluster each node bounds
/// only the answers that reach it, so the effective allowance is the
/// challenge's times the number of nodes. Finite, which is the property that
/// matters, and a deployment that wants the exact cap installs a store its
/// nodes share.
///
/// Entries are pruned as they are written rather than on a timer: a record
/// whose challenge has lapsed bounds nothing — every token in that chain is
/// already refused as expired — so the map cannot grow beyond the tokens
/// answered inside one challenge validity.
class Tom2FAMemoryAttemptStore implements Tom2FAAttemptStore {
  /// The process-wide instance [Tom2FAAttemptStore.resolve] falls back to.
  static final Tom2FAMemoryAttemptStore shared = Tom2FAMemoryAttemptStore();

  final Map<String, DateTime> _answered = {};

  /// How many records are held. Test-support, and a size to assert on.
  int get size => _answered.length;

  @override
  Future<bool> spend(Tom2FAAttempt attempt) async {
    _pruneLapsed();
    if (_answered.containsKey(attempt.fingerprint)) return false;
    // Recorded even when already lapsed, then pruned by the next call: the
    // branch that skipped recording it would be one more thing to get right,
    // and this path costs one map write on a token that was refused anyway.
    _answered[attempt.fingerprint] = attempt.notAfter;
    _pruneLapsed();
    return true;
  }

  /// Discards every record. Test-support only.
  void clear() => _answered.clear();

  void _pruneLapsed() {
    final now = DateTime.now().toUtc();
    _answered.removeWhere((_, notAfter) => !now.isBefore(notAfter));
  }
}

/// A stable, opaque identifier for [tokenString].
///
/// SHA-256 of the encoded token. The digest, not the token: a store is a place
/// a deployment points at shared infrastructure, and an attempt log holding
/// usable bearer credentials would be a worse hazard than the one it closes.
///
/// Two byte-identical tokens have one fingerprint, which is the right reading —
/// they are the same token, and the second presentation of it is the replay
/// this exists to refuse.
String tom2FATokenFingerprint(String tokenString) =>
    sha256.convert(utf8.encode(tokenString)).toString();
