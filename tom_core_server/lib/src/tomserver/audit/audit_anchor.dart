/// External anchoring of the audit chain head — what turns tamper-*evidence*
/// into something an attacker with full write access cannot quietly repair.
///
/// ## The gap the chain leaves
///
/// Each entry hashes its predecessor, so editing, removing or reordering *one*
/// entry breaks every link after it and [verifyAuditChain] says so. That
/// defeats accident and casual malice, which is most of what a trail is for.
///
/// It does not defeat an attacker who can rewrite the *whole* trail. Having
/// changed an entry they recompute every hash from that point onward, and the
/// result verifies perfectly — because the chain proves only internal
/// consistency, and internal consistency is a property a forger can restore.
/// The same applies, even more cheaply, to deleting entries from the *end*: a
/// truncated chain is a valid chain.
///
/// The missing ingredient is the standard one. The head hash must be recorded
/// somewhere the attacker does not control, at a moment they cannot revisit.
/// Then a rewrite is no longer invisible: the rewritten chain has a different
/// hash at the anchored position, and the recorded one contradicts it.
///
/// ## What an anchor is
///
/// A [TomAuditAnchor] is a three-part claim — *chain `writer` had `entryCount`
/// entries whose head was `headHash`, at `createdAt`* — optionally signed. It
/// is published on a schedule by [TomAuditAnchorPublisher] into a
/// [TomAuditAnchorStore], and checked later by [verifyAgainstAnchor].
///
/// ## Signing and publication defend against different adversaries
///
/// Neither half is sufficient, and it is worth being exact about which is which
/// rather than letting a signature imply a guarantee it does not give:
///
///  * **Publication** — writing the anchor somewhere the server cannot reach
///    afterwards — is what stops the server from *revising* its own history.
///    Without it, an attacker who owns the server owns the anchors too and
///    rewrites both.
///  * **A signature** is what stops whoever holds the *store* from inventing an
///    anchor the server never issued. Without it, a compromised archive can
///    manufacture a divergence, or launder one away.
///
/// So a signing key held on the same server it attests to adds nothing against
/// server compromise — it defends the store, not the chain. The guarantee this
/// module delivers is exactly: *given an anchor that reached a store the
/// attacker cannot rewrite, a wholesale rewrite or a truncation of the chain is
/// detectable.* Where that store lives is a deployment decision, and the
/// framework deliberately does not pretend to make it — see
/// `doc/audit.md` § "Tamper Evidence, and Tamper Proofing".
///
/// ## Positions, not offsets
///
/// An anchor is a claim about a *position*, so the chain has to be able to
/// state positions that survive retention. That is what [TomAuditEntry.index]
/// is for: once a prefix has been pruned, an entry's offset in what remains is
/// no longer its place in the chain, and a check that confused the two would
/// report tampering on every retention pass.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'audit_sink.dart';

/// A signed-or-unsigned claim about where an audit chain stood at a moment.
///
/// Immutable by construction: an anchor that could be edited would be an
/// anchor that proves nothing.
class TomAuditAnchor {
  /// The chain this anchor describes — [TomSqlAuditSink.writer], or whatever
  /// name the deployment gives a single node's chain.
  final String writer;

  /// How many entries the chain held, counted from genesis.
  ///
  /// With [headHash] this is the whole positional claim, which is why the two
  /// must be captured together: a count belonging to a different head reports a
  /// divergence that never happened, and an operator who sees one false alarm
  /// learns to disregard the next real one.
  final int entryCount;

  /// The hash of the [entryCount]-th entry, or [tomAuditGenesisHash] when the
  /// chain was still empty.
  final String headHash;

  /// When the anchor was taken, in UTC.
  ///
  /// Evidence, not an index: it bounds *when* a later divergence must have
  /// happened. Positions are compared by [entryCount]; time never is.
  final DateTime createdAt;

  /// Which key signed this anchor, or `null` when it is unsigned.
  final String? keyId;

  /// The base64 signature over [signedPayload], or `null` when unsigned.
  final String? signature;

  /// Creates an anchor.
  TomAuditAnchor({
    required this.writer,
    required this.entryCount,
    required this.headHash,
    required DateTime createdAt,
    this.keyId,
    this.signature,
  }) : createdAt = createdAt.toUtc();

  /// Captures the current position of [sink] as an anchor for [writer].
  ///
  /// Reads [TomAuditSink.headHash] and [TomAuditSink.entryCount] with no `await`
  /// between them, so a concurrent write cannot slip in and pair a head with the
  /// wrong count.
  factory TomAuditAnchor.of(
    TomAuditSink sink, {
    required String writer,
    DateTime? at,
  }) => TomAuditAnchor(
    writer: writer,
    entryCount: sink.entryCount,
    headHash: sink.headHash,
    createdAt: at ?? DateTime.now().toUtc(),
  );

  /// Whether this anchor carries a signature.
  bool get isSigned => signature != null && keyId != null;

  /// The exact bytes a signature covers, as canonical JSON.
  ///
  /// Fixed key order, `createdAt` as an ISO-8601 UTC string, and the signature
  /// itself excluded. Everything that makes the claim is inside; nothing else
  /// is, so two encoders cannot disagree about what was signed.
  String get signedPayload => jsonEncode({
    'writer': writer,
    'entryCount': entryCount,
    'headHash': headHash,
    'createdAt': createdAt.toIso8601String(),
    'keyId': keyId,
  });

  /// This anchor with [keyId] and a signature from [signer] attached.
  ///
  /// The key id is set *before* the payload is signed, so an anchor cannot be
  /// re-attributed to a different key without invalidating its own signature.
  TomAuditAnchor signedWith(TomAuditAnchorSigner signer) {
    final attributed = TomAuditAnchor(
      writer: writer,
      entryCount: entryCount,
      headHash: headHash,
      createdAt: createdAt,
      keyId: signer.keyId,
    );
    return TomAuditAnchor(
      writer: writer,
      entryCount: entryCount,
      headHash: headHash,
      createdAt: createdAt,
      keyId: signer.keyId,
      signature: signer.sign(attributed.signedPayload),
    );
  }

  /// The anchor as a JSON map.
  Map<String, Object?> toJson() => {
    'writer': writer,
    'entryCount': entryCount,
    'headHash': headHash,
    'createdAt': createdAt.toIso8601String(),
    'keyId': keyId,
    'signature': signature,
  };

  /// Rebuilds an anchor from [json] as written by [toJson].
  factory TomAuditAnchor.fromJson(Map<String, Object?> json) {
    final entryCount = json['entryCount'];
    final headHash = json['headHash'];
    final writer = json['writer'];
    final createdAt = json['createdAt'];
    if (writer is! String ||
        entryCount is! int ||
        headHash is! String ||
        createdAt is! String) {
      throw TomAuditException(
        'audit.anchor.malformed',
        'Audit anchor is missing writer, entryCount, headHash or createdAt.',
      );
    }
    return TomAuditAnchor(
      writer: writer,
      entryCount: entryCount,
      headHash: headHash,
      createdAt: DateTime.parse(createdAt),
      keyId: json['keyId'] as String?,
      signature: json['signature'] as String?,
    );
  }

  /// The anchor as one line of JSON, with no embedded newline.
  String toJsonLine() => jsonEncode(toJson());

  @override
  String toString() =>
      'anchor[$writer @$entryCount ${headHash.substring(0, headHash.length < 8 ? headHash.length : 8)} '
      '${createdAt.toIso8601String()}${isSigned ? " signed:$keyId" : " UNSIGNED"}]';
}

/// Attaches a signature to an anchor's payload.
///
/// An interface rather than a concrete algorithm because the key material is
/// the deployment's, not the framework's: an HSM, a KMS and a PEM file are all
/// legitimate answers, and only the first two are worth much.
abstract class TomAuditAnchorSigner {
  /// Names the key, so a verifier holding several can pick the right one and a
  /// rotation does not orphan the anchors signed before it.
  String get keyId;

  /// Signs [payload], returning the signature base64-encoded.
  String sign(String payload);
}

/// Checks the signature on an anchor.
abstract class TomAuditAnchorVerifier {
  /// Whether [anchor] carries a valid signature from a key this verifier knows.
  ///
  /// An unsigned anchor, or one signed by an unknown key, is `false`: the
  /// verifier's job is to say whether the anchor can be relied on, and neither
  /// of those can.
  ///
  /// **Implementations must not throw.** The input is an anchor that may have
  /// been tampered with — that is the situation the verifier exists for — so
  /// malformed key ids, signatures and payloads are ordinary traffic, not
  /// programming errors, and the caller's only two useful answers are `true`
  /// and `false`. [verifyAgainstAnchor] enforces this at the seam rather than
  /// trusting it, because implementations legitimately leave the process and an
  /// expired HSM session is not something it can rule out; but an
  /// implementation that relies on being caught reports every one of its own
  /// failures as an unexplained bad signature.
  bool verify(TomAuditAnchor anchor);
}

/// Signs anchors with an RSA private key (SHA-256, PKCS#1 v1.5).
///
/// The key should live where the audited server cannot reach it after signing —
/// see the library docs on why a locally-held key defends the store rather than
/// the chain.
class TomRsaAuditAnchorSigner implements TomAuditAnchorSigner {
  /// The private key that signs.
  final RSAPrivateKey privateKey;

  @override
  final String keyId;

  /// Creates a signer for [privateKey], published under [keyId].
  const TomRsaAuditAnchorSigner({
    required this.privateKey,
    required this.keyId,
  });

  @override
  String sign(String payload) => base64Encode(
    rsaSign(privateKey, Uint8List.fromList(utf8.encode(payload))),
  );
}

/// Verifies anchor signatures against a set of published public keys.
///
/// Several keys, held by id, so verification survives a key rotation: anchors
/// signed by the retired key stay checkable instead of turning into an
/// indistinguishable wall of failures.
class TomRsaAuditAnchorVerifier implements TomAuditAnchorVerifier {
  /// The public keys, by the [TomAuditAnchorSigner.keyId] that names them.
  final Map<String, RSAPublicKey> publicKeys;

  /// Creates a verifier trusting exactly [publicKeys].
  const TomRsaAuditAnchorVerifier(this.publicKeys);

  @override
  bool verify(TomAuditAnchor anchor) {
    final keyId = anchor.keyId;
    final signature = anchor.signature;
    if (keyId == null || signature == null) return false;
    final key = publicKeys[keyId];
    if (key == null) return false;
    try {
      return rsaVerify(
        key,
        Uint8List.fromList(utf8.encode(anchor.signedPayload)),
        base64Decode(signature),
      );
    } catch (_) {
      // Any failure to verify is a failed verification. A signature that is not
      // base64, one that decodes to bytes the cipher rejects, a payload the
      // digest chokes on — all of it is "does not verify", not a crash in the
      // checker, because every byte here came from a store this method exists
      // to distrust.
      //
      // Broad on purpose. As of pointycastle 3.9.1 nothing below actually
      // escapes: `rsaVerify` catches `ArgumentError`, `RSASigner` catches it
      // again around `processBlock`, and every throw in `PKCS1Encoding` and
      // `RSAEngine` is an `ArgumentError`. But that is three layers of other
      // people's internals — one of them commented with the version it was
      // written for — holding up a totality guarantee this class owes its
      // caller. Naming a single exception type here made the guarantee true by
      // coincidence and re-breakable by a dependency bump.
      return false;
    }
  }
}

/// How a chain stands relative to an anchor.
enum TomAuditAnchorStatus {
  /// The chain is intact and ends exactly where the anchor says it did.
  matched,

  /// The chain is intact, agrees with the anchor at the anchored position, and
  /// has grown since. The ordinary state of a live trail.
  extended,

  /// The chain is intact but the anchored position has been pruned away, so
  /// there is nothing left to compare. Inconclusive rather than clean: a
  /// deployment that does *not* prune should treat this as a finding.
  beforeRetention,

  /// The chain is intact but *stops short* of the anchored position: entries
  /// the anchor counted are no longer there.
  ///
  /// Truncation is the attack a hash chain is blind to — lopping entries off
  /// the end leaves a perfectly valid chain — and this status is the only thing
  /// that sees it.
  truncated,

  /// The chain is intact but the entry at the anchored position hashes
  /// differently from what the anchor recorded.
  ///
  /// **The wholesale-rewrite signal, and the point of the whole mechanism.** An
  /// attacker who edited an entry and recomputed every hash after it produces a
  /// chain that verifies and an anchor that does not match.
  diverged,

  /// The chain fails its own verification, so the anchor was not consulted.
  /// A partial edit — what the chain alone already catches.
  chainBroken,

  /// The anchor's signature is missing, unknown or wrong, so the anchor itself
  /// cannot be relied on and nothing was concluded from it.
  signatureInvalid,

  /// The anchor describes a different chain than the entries do.
  writerMismatch,
}

/// The outcome of checking a chain against an anchor.
class TomAuditAnchorVerification {
  /// What was concluded.
  final TomAuditAnchorStatus status;

  /// The anchor that was checked against.
  final TomAuditAnchor anchor;

  /// The chain's own verification, always performed and always reported.
  final TomAuditChainVerification chain;

  /// A one-line explanation, suitable for an operator alert.
  final String detail;

  /// Creates a result.
  const TomAuditAnchorVerification({
    required this.status,
    required this.anchor,
    required this.chain,
    required this.detail,
  });

  /// Whether the chain is consistent with the anchor.
  bool get isMatch =>
      status == TomAuditAnchorStatus.matched ||
      status == TomAuditAnchorStatus.extended;

  /// Whether this result is a finding an operator must act on.
  ///
  /// [TomAuditAnchorStatus.signatureInvalid] counts. A forged anchor and a
  /// misconfigured key are indistinguishable from here, and treating the
  /// ambiguity as "fine" would mean the check silently stopped checking — which
  /// is the failure mode anchoring exists to prevent.
  bool get indicatesTampering =>
      status == TomAuditAnchorStatus.diverged ||
      status == TomAuditAnchorStatus.truncated ||
      status == TomAuditAnchorStatus.chainBroken ||
      status == TomAuditAnchorStatus.signatureInvalid;

  /// Whether nothing could be concluded — the anchored position is gone, or the
  /// anchor belongs to another chain.
  bool get isInconclusive => !isMatch && !indicatesTampering;

  @override
  String toString() => '${status.name}: $detail';
}

/// Checks that [entries] are consistent with [anchor].
///
/// [entries] may be a *suffix* — retention prunes from the front — which is why
/// every comparison goes through [TomAuditEntry.index] rather than through an
/// entry's offset in the list.
///
/// The checks run in a fixed order — **writer, then signature, then chain
/// validity, then position** — and that order is *most specific answer first*.
/// Several of these conditions usually fail together: compare a window against
/// an anchor for a different chain and the chain check fails too, because the
/// hashes were never meant to line up. Reporting the most specific one names
/// the mistake the caller actually made. A caller told `chainBroken` when the
/// real problem is that they passed the wrong writer goes looking for tampering
/// in a trail that is intact.
///
/// The chain verification itself is computed up front, before any of these
/// checks, and is reported on [TomAuditAnchorVerification.chain] whichever one
/// answers — so short-circuiting on a more specific status never costs the
/// caller the chain result, only its precedence.
///
/// Pass [writer] to assert the entries really are the chain the anchor names;
/// pass [verifier] to require the anchor's signature. Omitting [verifier] checks
/// the *position* only, which is the honest thing to do for an unsigned anchor
/// taken from a store that is itself trusted.
TomAuditAnchorVerification verifyAgainstAnchor(
  Iterable<TomAuditEntry> entries,
  TomAuditAnchor anchor, {
  String? writer,
  TomAuditAnchorVerifier? verifier,
}) {
  final list = entries.toList(growable: false);
  final chain = verifyAuditChain(
    list,
    startHash: list.isEmpty ? tomAuditGenesisHash : list.first.previousHash,
  );

  TomAuditAnchorVerification result(
    TomAuditAnchorStatus status,
    String detail,
  ) => TomAuditAnchorVerification(
    status: status,
    anchor: anchor,
    chain: chain,
    detail: detail,
  );

  if (writer != null && writer != anchor.writer) {
    return result(
      TomAuditAnchorStatus.writerMismatch,
      'anchor describes chain "${anchor.writer}" but the entries are '
      'chain "$writer"',
    );
  }
  if (verifier != null) {
    // [TomAuditAnchorVerifier.verify] is required not to throw, and this
    // enforces it rather than trusting it. The interface exists so a deployment
    // can put an HSM or a KMS behind it, and those fail in ways no pure-Dart
    // verifier does — expired sessions, timeouts, unparseable key material. A
    // function documented as returning one of eight statuses may not hand the
    // caller a stack trace instead because the key store was briefly away.
    //
    // The fail-safe answer is `signatureInvalid`, for the reason the unsigned
    // case already uses: a verifier that could not answer and an anchor that is
    // genuinely forged are indistinguishable from here, and calling the
    // ambiguity "fine" is how a check silently stops checking. The exception
    // goes into [TomAuditAnchorVerification.detail] so the operator sees an
    // infrastructure fault for what it is instead of hunting a forgery.
    final bool verified;
    try {
      verified = verifier.verify(anchor);
    } catch (error) {
      return result(
        TomAuditAnchorStatus.signatureInvalid,
        'the verifier threw instead of answering, so the anchor could not be '
        'authenticated: $error',
      );
    }
    if (!verified) {
      return result(
        TomAuditAnchorStatus.signatureInvalid,
        anchor.isSigned
            ? 'anchor signature from key "${anchor.keyId}" does not verify'
            : 'anchor is unsigned but a signature was required',
      );
    }
  }
  if (!chain.isValid) {
    return result(
      TomAuditAnchorStatus.chainBroken,
      'chain is broken before the anchor could be applied: ${chain.detail}',
    );
  }

  // The position the anchor pins: the index of the last entry it counted.
  // Minus one when the chain was still empty, which then compares against the
  // first retained entry's own link — genesis — and needs no special case.
  final anchoredIndex = anchor.entryCount - 1;

  if (list.isEmpty) {
    if (anchor.entryCount == 0) {
      return result(
        TomAuditAnchorStatus.matched,
        'anchor and chain are both empty',
      );
    }
    // Nothing is retained, so a wholesale deletion and a completed retention
    // sweep look identical from here. Deliberately not guessed: see
    // [TomAuditAnchorStatus.beforeRetention].
    return result(
      TomAuditAnchorStatus.beforeRetention,
      'no entries retained, so the anchored position '
      '${anchor.entryCount} cannot be checked',
    );
  }

  final firstIndex = list.first.index;
  final lastIndex = list.last.index;

  if (anchoredIndex == firstIndex - 1) {
    // The anchored entry itself is gone, but the oldest surviving entry still
    // *links* to it — so the one position retention leaves checkable is checked.
    return list.first.previousHash == anchor.headHash
        ? result(
            TomAuditAnchorStatus.extended,
            'anchored head is the pruned predecessor of the retained window '
            'and matches',
          )
        : result(
            TomAuditAnchorStatus.diverged,
            'entry $anchoredIndex was rewritten: the retained window links to '
            '${list.first.previousHash}, the anchor recorded ${anchor.headHash}',
          );
  }
  if (anchoredIndex < firstIndex) {
    return result(
      TomAuditAnchorStatus.beforeRetention,
      'anchored position $anchoredIndex was pruned; the retained window starts '
      'at $firstIndex',
    );
  }
  if (anchoredIndex > lastIndex) {
    return result(
      TomAuditAnchorStatus.truncated,
      'anchor recorded ${anchor.entryCount} entries but the chain ends at '
      'index $lastIndex: ${anchoredIndex - lastIndex} entries are missing from '
      'the end',
    );
  }

  // Indices are contiguous — `verifyAuditChain` proved it above — so the
  // anchored entry is at exactly this offset.
  final anchored = list[anchoredIndex - firstIndex];
  if (anchored.hash != anchor.headHash) {
    return result(
      TomAuditAnchorStatus.diverged,
      'entry $anchoredIndex hashes to ${anchored.hash} but the anchor recorded '
      '${anchor.headHash}: the chain was rewritten at or before this point',
    );
  }
  return anchoredIndex == lastIndex
      ? result(
          TomAuditAnchorStatus.matched,
          'chain matches the anchor at ${anchor.entryCount} entries',
        )
      : result(
          TomAuditAnchorStatus.extended,
          'chain matches the anchor at ${anchor.entryCount} entries and has '
          '${lastIndex - anchoredIndex} more since',
        );
}
