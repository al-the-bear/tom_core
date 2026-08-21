import 'dart:convert';
import 'dart:io';

import 'package:pointycastle/asymmetric/api.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// External-anchoring tests: what the hash chain alone cannot prove.
///
/// The chain proves internal consistency, and internal consistency is a
/// property a forger can restore — recompute every hash from the edit onward
/// and the trail verifies perfectly. These tests are therefore built around the
/// three things only an anchor sees:
///
///  * a **wholesale rewrite**, which produces a chain that passes
///    `verifyAuditChain` and fails `verifyAgainstAnchor`;
///  * a **truncation**, which is invisible to a hash chain because lopping
///    entries off the end leaves a valid chain; and
///  * a **retained suffix**, which must read as a suffix rather than as damage,
///    since a check that cries tampering after every retention pass is one an
///    operator learns to ignore.
///
/// RSA signing is exercised with a small key: these tests assert the wiring
/// (payload coverage, key id attribution, rejection of a tampered anchor), not
/// the strength of the primitive, which is `tom_crypto`'s business.

TomAuditRecord _record(String id, {Map<String, Object?> after = const {}}) =>
    TomAuditRecord(
      id: id,
      timestamp: DateTime.utc(2026, 7, 28, 10, 30),
      actor: TomAuditActor.system,
      action: TomAuditAction.update,
      target: 'Widget',
      outcome: TomAuditOutcome.succeeded,
      after: after,
    );

/// Builds a chain of [count] entries starting at [startIndex] from [startHash].
List<TomAuditEntry> _chain(
  int count, {
  int startIndex = 0,
  String startHash = tomAuditGenesisHash,
}) {
  final entries = <TomAuditEntry>[];
  var previous = startHash;
  for (var i = 0; i < count; i++) {
    final entry = TomAuditEntry.chain(
      _record('r${startIndex + i}'),
      previous,
      index: startIndex + i,
    );
    entries.add(entry);
    previous = entry.hash;
  }
  return entries;
}

TomAuditAnchor _anchorAt(
  List<TomAuditEntry> entries, {
  String writer = 'node-a',
}) => TomAuditAnchor(
  writer: writer,
  entryCount: entries.isEmpty ? 0 : entries.last.index + 1,
  headHash: entries.isEmpty ? tomAuditGenesisHash : entries.last.hash,
  createdAt: DateTime.utc(2026, 7, 28, 11),
);

/// A signer that is trivially forgeable, to exercise the seam without the cost
/// of RSA key generation in tests that are not about RSA.
class _FakeSigner implements TomAuditAnchorSigner {
  @override
  final String keyId;
  const _FakeSigner(this.keyId);

  @override
  String sign(String payload) =>
      base64Encode(utf8.encode('$keyId::${payload.length}::$payload'));
}

class _FakeVerifier implements TomAuditAnchorVerifier {
  final Set<String> trustedKeys;
  const _FakeVerifier(this.trustedKeys);

  @override
  bool verify(TomAuditAnchor anchor) {
    final keyId = anchor.keyId;
    final signature = anchor.signature;
    if (keyId == null || signature == null) return false;
    if (!trustedKeys.contains(keyId)) return false;
    return signature == _FakeSigner(keyId).sign(anchor.signedPayload);
  }
}

void main() {
  group('TomAuditAnchor', () {
    test('captures head and count from a sink as one observation', () async {
      final sink = TomMemoryAuditSink();
      await sink.write(_record('r0'));
      await sink.write(_record('r1'));

      final anchor = TomAuditAnchor.of(sink, writer: 'node-a');
      expect(anchor.entryCount, 2);
      expect(anchor.headHash, sink.headHash);
      expect(anchor.createdAt.isUtc, isTrue);
      expect(anchor.isSigned, isFalse);
      sink.close();
    });

    test('an empty chain anchors at genesis rather than at nothing', () {
      final sink = TomMemoryAuditSink();
      final anchor = TomAuditAnchor.of(sink, writer: 'node-a');
      expect(anchor.entryCount, 0);
      expect(anchor.headHash, tomAuditGenesisHash);
    });

    test('round-trips through JSON, signature and all', () {
      final anchor = _anchorAt(_chain(3)).signedWith(const _FakeSigner('k1'));
      final back = TomAuditAnchor.fromJson(
        (jsonDecode(anchor.toJsonLine()) as Map).cast<String, Object?>(),
      );
      expect(back.writer, anchor.writer);
      expect(back.entryCount, anchor.entryCount);
      expect(back.headHash, anchor.headHash);
      expect(back.createdAt, anchor.createdAt);
      expect(back.keyId, 'k1');
      expect(back.signature, anchor.signature);
      expect(const _FakeVerifier({'k1'}).verify(back), isTrue);
    });

    test('a malformed anchor is rejected rather than defaulted', () {
      expect(
        () => TomAuditAnchor.fromJson({'writer': 'node-a'}),
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.anchor.malformed',
          ),
        ),
      );
    });

    test('every load-bearing anchor field is required, one at a time', () {
      // An anchor is the external witness the trail is checked against, so a
      // defaulted field here does not degrade a check — it fabricates one. Each
      // field is dropped on its own, because a guard that only fires when the
      // whole object is absent is not a guard on the field.
      final complete =
          jsonDecode(_anchorAt(_chain(2)).toJsonLine()) as Map<String, Object?>;

      for (final field in const [
        'writer',
        'entryCount',
        'headHash',
        'createdAt',
      ]) {
        expect(
          () => TomAuditAnchor.fromJson(
            Map<String, Object?>.from(complete)..remove(field),
          ),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.anchor.malformed',
            ),
          ),
          reason: 'without $field',
        );
      }
    });

    test('an entry count that is not a count is refused, not coerced', () {
      // JSON has one number type, so a producer that wrote 2.0 — or the string
      // "2" — is close enough to look right and wrong enough to make the
      // comparison against a real chain length meaningless.
      for (final wrong in <Object?>['2', 2.5]) {
        expect(
          () => TomAuditAnchor.fromJson(
            Map<String, Object?>.from(
              jsonDecode(_anchorAt(_chain(2)).toJsonLine()) as Map,
            )..['entryCount'] = wrong,
          ),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.anchor.malformed',
            ),
          ),
          reason: 'entryCount: $wrong',
        );
      }
    });

    test('the key id is inside what the signature covers', () {
      // Re-attributing a signed anchor to another key must not survive: the
      // payload names the key, so a swapped keyId invalidates the signature.
      final signed = _anchorAt(_chain(2)).signedWith(const _FakeSigner('k1'));
      final reattributed = TomAuditAnchor(
        writer: signed.writer,
        entryCount: signed.entryCount,
        headHash: signed.headHash,
        createdAt: signed.createdAt,
        keyId: 'k2',
        signature: signed.signature,
      );
      expect(const _FakeVerifier({'k1', 'k2'}).verify(reattributed), isFalse);
    });

    test('the head hash is inside what the signature covers', () {
      final signed = _anchorAt(_chain(2)).signedWith(const _FakeSigner('k1'));
      final edited = TomAuditAnchor(
        writer: signed.writer,
        entryCount: signed.entryCount,
        headHash: tomAuditGenesisHash,
        createdAt: signed.createdAt,
        keyId: signed.keyId,
        signature: signed.signature,
      );
      expect(const _FakeVerifier({'k1'}).verify(edited), isFalse);
    });
  });

  group('verifyAgainstAnchor', () {
    test('a normal chain matches its own anchor', () {
      final entries = _chain(4);
      final result = verifyAgainstAnchor(entries, _anchorAt(entries));
      expect(result.status, TomAuditAnchorStatus.matched);
      expect(result.isMatch, isTrue);
      expect(result.indicatesTampering, isFalse);
      expect(result.chain.isValid, isTrue);
    });

    test(
      'entries appended since the anchor read as extended, not diverged',
      () {
        final entries = _chain(6);
        final anchor = _anchorAt(entries.sublist(0, 3));
        final result = verifyAgainstAnchor(entries, anchor);
        expect(result.status, TomAuditAnchorStatus.extended);
        expect(result.isMatch, isTrue);
        expect(result.detail, contains('3 more since'));
      },
    );

    test('an empty chain matches an empty anchor', () {
      final result = verifyAgainstAnchor(const [], _anchorAt(const []));
      expect(result.status, TomAuditAnchorStatus.matched);
    });

    test(
      'a wholesale rewrite verifies as a chain and FAILS against the anchor',
      () {
        // The attack the chain alone cannot see: edit entry 1, then recompute
        // every hash after it. The result is internally perfect.
        final original = _chain(5);
        final anchor = _anchorAt(original);

        final forged = <TomAuditEntry>[original.first];
        var previous = original.first.hash;
        for (var i = 1; i < original.length; i++) {
          final record = i == 1
              ? _record('r1', after: {'amount': 1000000})
              : original[i].record;
          final entry = TomAuditEntry.chain(record, previous, index: i);
          forged.add(entry);
          previous = entry.hash;
        }

        // Precondition: the forgery is undetectable by the chain itself.
        expect(verifyAuditChain(forged).isValid, isTrue);

        final result = verifyAgainstAnchor(forged, anchor);
        expect(result.status, TomAuditAnchorStatus.diverged);
        expect(result.indicatesTampering, isTrue);
        expect(result.isMatch, isFalse);
        expect(
          result.chain.isValid,
          isTrue,
          reason: 'the chain still verifies',
        );
        expect(result.detail, contains('rewritten'));
      },
    );

    test('truncating the end verifies as a chain and reads as truncated', () {
      // Deleting from the end leaves a valid chain — the other blind spot.
      final original = _chain(5);
      final anchor = _anchorAt(original);
      final truncated = original.sublist(0, 2);

      expect(verifyAuditChain(truncated).isValid, isTrue);

      final result = verifyAgainstAnchor(truncated, anchor);
      expect(result.status, TomAuditAnchorStatus.truncated);
      expect(result.indicatesTampering, isTrue);
      expect(result.detail, contains('3 entries are missing from the end'));
    });

    test('a retained suffix verifies as a suffix, not as a break', () {
      // Retention pruned entries 0..2. The anchor at entry 5 still sits inside
      // the retained window, so it is checkable and must read clean.
      final whole = _chain(6);
      final anchor = _anchorAt(whole);
      final suffix = whole.sublist(3);

      final result = verifyAgainstAnchor(suffix, anchor);
      expect(result.status, TomAuditAnchorStatus.matched);
      expect(result.isMatch, isTrue);
      expect(result.chain.isValid, isTrue);
    });

    test('an anchor pruned away is inconclusive, never a false alarm', () {
      final whole = _chain(8);
      final oldAnchor = _anchorAt(whole.sublist(0, 2));
      final suffix = whole.sublist(5);

      final result = verifyAgainstAnchor(suffix, oldAnchor);
      expect(result.status, TomAuditAnchorStatus.beforeRetention);
      expect(result.isInconclusive, isTrue);
      expect(result.indicatesTampering, isFalse);
    });

    test('the one position retention leaves checkable is still checked', () {
      // The anchored entry is gone but the oldest survivor links to it, so the
      // anchor is confirmed through that link rather than written off.
      final whole = _chain(6);
      final anchor = _anchorAt(whole.sublist(0, 3));
      final suffix = whole.sublist(3);

      final result = verifyAgainstAnchor(suffix, anchor);
      expect(result.status, TomAuditAnchorStatus.extended);
      expect(result.detail, contains('pruned predecessor'));
    });

    test('a rewrite hidden behind retention is caught at the boundary', () {
      final whole = _chain(6);
      final anchor = _anchorAt(whole.sublist(0, 3));
      // The suffix was re-chained onto a different (forged) prefix head.
      final forgedSuffix = _chain(3, startIndex: 3, startHash: 'a' * 64);

      final result = verifyAgainstAnchor(forgedSuffix, anchor);
      expect(result.status, TomAuditAnchorStatus.diverged);
      expect(result.indicatesTampering, isTrue);
      expect(whole.length, 6);
    });

    test('an empty retained window concludes nothing', () {
      final result = verifyAgainstAnchor(const [], _anchorAt(_chain(3)));
      expect(result.status, TomAuditAnchorStatus.beforeRetention);
      expect(result.detail, contains('no entries retained'));
    });

    test('a broken chain short-circuits before the anchor is applied', () {
      final entries = _chain(3);
      final anchor = _anchorAt(entries);
      final damaged = [entries[0], entries[2]];

      final result = verifyAgainstAnchor(damaged, anchor);
      expect(result.status, TomAuditAnchorStatus.chainBroken);
      expect(result.indicatesTampering, isTrue);
      expect(result.chain.isValid, isFalse);
    });

    test('renumbering to hide a truncation is caught as a broken chain', () {
      // Renumbering is how an attacker would try to make a truncated chain look
      // like a pruned one. The index check inside `verifyAuditChain` stops it
      // before the anchor is ever consulted.
      final original = _chain(5);
      final anchor = _anchorAt(original);
      final renumbered = [
        original[0],
        TomAuditEntry(
          record: original[1].record,
          previousHash: original[1].previousHash,
          hash: original[1].hash,
          index: 4,
        ),
      ];
      final result = verifyAgainstAnchor(renumbered, anchor);
      expect(result.status, TomAuditAnchorStatus.chainBroken);
      expect(result.chain.detail, contains('renumbered'));
    });

    test('an anchor for another chain is a mismatch, not a divergence', () {
      final entries = _chain(3);
      final anchor = _anchorAt(entries, writer: 'node-b');
      final result = verifyAgainstAnchor(entries, anchor, writer: 'node-a');
      expect(result.status, TomAuditAnchorStatus.writerMismatch);
      expect(result.isInconclusive, isTrue);
    });

    test('a signed anchor is accepted when the signature verifies', () {
      final entries = _chain(3);
      final anchor = _anchorAt(entries).signedWith(const _FakeSigner('k1'));
      final result = verifyAgainstAnchor(
        entries,
        anchor,
        writer: 'node-a',
        verifier: const _FakeVerifier({'k1'}),
      );
      expect(result.status, TomAuditAnchorStatus.matched);
    });

    test('a forged anchor is rejected before its claim is believed', () {
      // The store was compromised and invented an anchor. Without the signature
      // check this would read as a divergence and send an operator hunting a
      // rewrite that never happened.
      final entries = _chain(3);
      final forgedAnchor = TomAuditAnchor(
        writer: 'node-a',
        entryCount: 3,
        headHash: 'b' * 64,
        createdAt: DateTime.utc(2026, 7, 28, 11),
        keyId: 'k1',
        signature: base64Encode(utf8.encode('nonsense')),
      );
      final result = verifyAgainstAnchor(
        entries,
        forgedAnchor,
        verifier: const _FakeVerifier({'k1'}),
      );
      expect(result.status, TomAuditAnchorStatus.signatureInvalid);
      expect(result.indicatesTampering, isTrue);
    });

    test('an unsigned anchor fails a verifier that was asked for', () {
      final entries = _chain(3);
      final result = verifyAgainstAnchor(
        entries,
        _anchorAt(entries),
        verifier: const _FakeVerifier({'k1'}),
      );
      expect(result.status, TomAuditAnchorStatus.signatureInvalid);
      expect(result.detail, contains('unsigned'));
    });

    test('an anchor signed by an unknown key is not trusted', () {
      final entries = _chain(3);
      final anchor = _anchorAt(
        entries,
      ).signedWith(const _FakeSigner('retired'));
      final result = verifyAgainstAnchor(
        entries,
        anchor,
        verifier: const _FakeVerifier({'current'}),
      );
      expect(result.status, TomAuditAnchorStatus.signatureInvalid);
    });
  });

  group('RSA anchor signing', () {
    late RSAPrivateKey privateKey;
    late RSAPublicKey publicKey;

    setUpAll(() async {
      final pair = await RsaKeyHelper.computeRSAKeyPair(
        RsaKeyHelper.getSecureRandom(),
      );
      privateKey = pair.privateKey as RSAPrivateKey;
      publicKey = pair.publicKey as RSAPublicKey;
    });

    test('a signed anchor verifies with the matching public key', () {
      final signer = TomRsaAuditAnchorSigner(
        privateKey: privateKey,
        keyId: 'audit-2026',
      );
      final entries = _chain(3);
      final anchor = _anchorAt(entries).signedWith(signer);
      expect(anchor.isSigned, isTrue);
      expect(anchor.keyId, 'audit-2026');

      final verifier = TomRsaAuditAnchorVerifier({'audit-2026': publicKey});
      expect(verifier.verify(anchor), isTrue);

      final result = verifyAgainstAnchor(
        entries,
        anchor,
        writer: 'node-a',
        verifier: verifier,
      );
      expect(result.status, TomAuditAnchorStatus.matched);
    });

    test('an edited signed anchor no longer verifies', () {
      final signer = TomRsaAuditAnchorSigner(
        privateKey: privateKey,
        keyId: 'audit-2026',
      );
      final anchor = _anchorAt(_chain(3)).signedWith(signer);
      final edited = TomAuditAnchor(
        writer: anchor.writer,
        entryCount: 99,
        headHash: anchor.headHash,
        createdAt: anchor.createdAt,
        keyId: anchor.keyId,
        signature: anchor.signature,
      );
      expect(
        TomRsaAuditAnchorVerifier({'audit-2026': publicKey}).verify(edited),
        isFalse,
      );
    });

    test('a signature that is not even base64 is a failure, not a crash', () {
      final anchor = TomAuditAnchor(
        writer: 'node-a',
        entryCount: 1,
        headHash: 'c' * 64,
        createdAt: DateTime.utc(2026, 7, 28),
        keyId: 'audit-2026',
        signature: 'not base64 !!!',
      );
      expect(
        TomRsaAuditAnchorVerifier({'audit-2026': publicKey}).verify(anchor),
        isFalse,
      );
    });

    test('an unknown key id is rejected without consulting the signature', () {
      final signer = TomRsaAuditAnchorSigner(
        privateKey: privateKey,
        keyId: 'audit-2026',
      );
      final anchor = _anchorAt(_chain(1)).signedWith(signer);
      expect(
        TomRsaAuditAnchorVerifier({'audit-2027': publicKey}).verify(anchor),
        isFalse,
      );
    });

    test('a rotated key set still verifies anchors from the retired key', () {
      final signer = TomRsaAuditAnchorSigner(
        privateKey: privateKey,
        keyId: 'audit-2025',
      );
      final anchor = _anchorAt(_chain(2)).signedWith(signer);
      final verifier = TomRsaAuditAnchorVerifier({
        'audit-2025': publicKey,
        'audit-2026': publicKey,
      });
      expect(verifier.verify(anchor), isTrue);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('TomMemoryAuditAnchorStore', () {
    test('appends and reads back per writer', () async {
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(_chain(1), writer: 'node-a'));
      await store.append(_anchorAt(_chain(2), writer: 'node-b'));
      await store.append(_anchorAt(_chain(3), writer: 'node-a'));

      expect(await store.read('node-a'), hasLength(2));
      expect(await store.read('node-b'), hasLength(1));
      expect((await store.latest('node-a'))!.entryCount, 3);
      expect(await store.latest('node-c'), isNull);
      store.close();
    });
  });

  group('TomFileAuditAnchorStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('anchor_store_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('anchors survive a restart of the store', () async {
      final store = TomFileAuditAnchorStore(directory: dir);
      await store.append(_anchorAt(_chain(2)));
      await store.append(_anchorAt(_chain(5)));
      store.close();

      final reopened = TomFileAuditAnchorStore(directory: dir);
      final anchors = await reopened.read('node-a');
      expect(anchors, hasLength(2));
      expect(anchors.first.entryCount, 2);
      expect(anchors.last.entryCount, 5);
      expect((await reopened.latest('node-a'))!.entryCount, 5);
    });

    test('each writer gets its own file', () async {
      final store = TomFileAuditAnchorStore(directory: dir);
      await store.append(_anchorAt(_chain(1), writer: 'node-a'));
      await store.append(_anchorAt(_chain(1), writer: 'node-b'));
      expect(store.fileFor('node-a').existsSync(), isTrue);
      expect(store.fileFor('node-b').existsSync(), isTrue);
      expect(await store.read('node-a'), hasLength(1));
    });

    test('a writer name cannot escape the directory', () {
      final store = TomFileAuditAnchorStore(directory: dir);
      final file = store.fileFor('../../etc/passwd');
      expect(
        file.parent.resolveSymbolicLinksSync(),
        dir.resolveSymbolicLinksSync(),
      );
    });

    test('an unknown writer reads as empty, not as an error', () async {
      final store = TomFileAuditAnchorStore(directory: dir);
      expect(await store.read('never-published'), isEmpty);
    });

    test('a damaged anchor line is a finding, not a skipped line', () async {
      final store = TomFileAuditAnchorStore(directory: dir);
      await store.append(_anchorAt(_chain(1)));
      store
          .fileFor('node-a')
          .writeAsStringSync('{ not an anchor\n', mode: FileMode.append);
      expect(() => store.read('node-a'), throwsA(isA<TomAuditException>()));
    });

    // Two writer names that sanitise to one file name. The sanitisation is
    // right and stays — it is what stops a writer called `../../etc` from
    // escaping the directory — but it is lossy, and a lossy name mapping used
    // as if it were injective puts two chains in one file.
    group('writers whose names collide after sanitisation', () {
      test(
        'read returns only the requested writer, as the memory store does',
        () async {
          final store = TomFileAuditAnchorStore(directory: dir);
          expect(
            store.fileFor('node/a').path,
            store.fileFor('node_a').path,
            reason: 'the premise: these two names share one file',
          );

          await store.append(_anchorAt(_chain(1), writer: 'node/a'));
          await store.append(_anchorAt(_chain(9), writer: 'node_a'));
          await store.append(_anchorAt(_chain(2), writer: 'node/a'));

          expect(
            (await store.read('node/a')).map((a) => a.writer),
            everyElement('node/a'),
          );
          expect(await store.read('node/a'), hasLength(2));
          expect(await store.read('node_a'), hasLength(1));

          // The two shipped stores must answer the same question, or `read` means
          // one thing in a test and another in production — which is the way a
          // defect survives a green suite.
          final memory = TomMemoryAuditAnchorStore();
          await memory.append(_anchorAt(_chain(1), writer: 'node/a'));
          await memory.append(_anchorAt(_chain(9), writer: 'node_a'));
          await memory.append(_anchorAt(_chain(2), writer: 'node/a'));
          expect(
            (await store.read('node/a')).map((a) => a.entryCount),
            (await memory.read('node/a')).map((a) => a.entryCount),
          );
        },
      );

      test(
        'latest returns this writer\'s newest anchor, not the file\'s',
        () async {
          final store = TomFileAuditAnchorStore(directory: dir);
          await store.append(_anchorAt(_chain(2), writer: 'node/a'));
          // Appended last, so it is the final line of the shared file — which is
          // what an unfiltered `latest` hands back.
          await store.append(_anchorAt(_chain(99), writer: 'node_a'));

          final latest = await store.latest('node/a');
          expect(latest!.writer, 'node/a');
          expect(latest.entryCount, 2);
        },
      );

      test('a routine check against latest does not raise a false alarm', () async {
        // The damage this does in practice. `latest` feeds the documented
        // routine check, so a foreign anchor is compared against a chain it
        // never described. Both call shapes are asserted because the collision
        // breaks them differently: with `writer:` the check reports
        // `writerMismatch`, and without it the foreign entry count reads as
        // `truncated` — tampering, on a trail nobody touched. Truncation is the
        // one thing a hash chain cannot detect by itself, so it is exactly the
        // finding an operator has been told to trust.
        final entries = _chain(3);
        final store = TomFileAuditAnchorStore(directory: dir);
        await store.append(
          TomAuditAnchor(
            writer: 'node/a',
            entryCount: 3,
            headHash: entries.last.hash,
            createdAt: DateTime.utc(2026, 7, 28, 11),
          ),
        );
        await store.append(_anchorAt(_chain(99), writer: 'node_a'));
        final latest = (await store.latest('node/a'))!;

        final scoped = verifyAgainstAnchor(entries, latest, writer: 'node/a');
        expect(scoped.status, TomAuditAnchorStatus.matched);
        expect(scoped.indicatesTampering, isFalse);

        final unscoped = verifyAgainstAnchor(entries, latest);
        expect(unscoped.status, TomAuditAnchorStatus.matched);
        expect(unscoped.indicatesTampering, isFalse);
      });

      test(
        'a routine check against latest still catches a real rewrite',
        () async {
          // The other direction, and the worse one. A false alarm costs trust;
          // this costs the guarantee. The foreign anchor here pins a position
          // older than the retained window, so the unscoped check reads
          // `beforeRetention` — neither a match nor a finding. The routine check
          // quietly declines to check, and a genuinely rewritten trail passes it
          // with nothing reported.
          final retained = _chain(4, startIndex: 40, startHash: 'pruned-head');
          final store = TomFileAuditAnchorStore(directory: dir);
          await store.append(
            TomAuditAnchor(
              writer: 'node/a',
              entryCount: 44,
              headHash: 'the-head-that-was-published',
              createdAt: DateTime.utc(2026, 7, 28, 11),
            ),
          );
          await store.append(_anchorAt(_chain(3), writer: 'node_a'));
          final latest = (await store.latest('node/a'))!;

          for (final verification in [
            verifyAgainstAnchor(retained, latest, writer: 'node/a'),
            verifyAgainstAnchor(retained, latest),
          ]) {
            expect(verification.status, TomAuditAnchorStatus.diverged);
            expect(verification.indicatesTampering, isTrue);
          }
        },
      );

      test('a damaged line is reported whichever writer wrote it', () async {
        // Filtering must happen *after* parsing, never by matching the writer
        // in the raw text: a line too damaged to parse is a line too damaged to
        // attribute, and skipping it because it does not look like ours would
        // turn the archive's one integrity check into a no-op for exactly the
        // lines that failed it.
        final store = TomFileAuditAnchorStore(directory: dir);
        await store.append(_anchorAt(_chain(1), writer: 'node/a'));
        store
            .fileFor('node_a')
            .writeAsStringSync('{ not an anchor\n', mode: FileMode.append);

        expect(() => store.read('node/a'), throwsA(isA<TomAuditException>()));
      });
    });
  });

  group('TomAuditAnchorPublisher', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('anchor_pub_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('publishes the sink position, signed', () async {
      final sink = TomMemoryAuditSink();
      final store = TomMemoryAuditAnchorStore();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: 'node-a',
        signer: const _FakeSigner('k1'),
      );

      await sink.write(_record('r0'));
      await sink.write(_record('r1'));
      final anchor = await publisher.publishNow();

      expect(anchor.entryCount, 2);
      expect(anchor.headHash, sink.headHash);
      expect(const _FakeVerifier({'k1'}).verify(anchor), isTrue);
      expect(store.anchors, hasLength(1));
      expect(publisher.lastPublished, same(anchor));

      publisher.stop();
      sink.close();
    });

    test('the published anchor is what later proves a rewrite', () async {
      final sink = TomFileAuditSink(directory: dir);
      final store = TomMemoryAuditAnchorStore();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: 'node-a',
      );
      for (var i = 0; i < 4; i++) {
        await sink.write(_record('r$i'));
      }
      await publisher.publishNow();
      publisher.stop();
      sink.close();

      // The attacker rewrites the file entirely: a fresh, internally perfect
      // chain over doctored records.
      final forged = <TomAuditEntry>[];
      var previous = tomAuditGenesisHash;
      for (var i = 0; i < 4; i++) {
        final entry = TomAuditEntry.chain(
          _record('r$i', after: {'tampered': true}),
          previous,
          index: i,
        );
        forged.add(entry);
        previous = entry.hash;
      }
      final file = dir.listSync().whereType<File>().single;
      file.writeAsStringSync(forged.map((e) => '${e.toJsonLine()}\n').join());

      final reopened = TomFileAuditSink(directory: dir);
      expect(reopened.verify().isValid, isTrue, reason: 'the forgery is clean');

      final anchor = (await store.latest('node-a'))!;
      final result = verifyAgainstAnchor(
        reopened.readAll(),
        anchor,
        writer: 'node-a',
      );
      expect(result.status, TomAuditAnchorStatus.diverged);
      reopened.close();
    });

    test('start publishes immediately, before the first interval', () async {
      final sink = TomMemoryAuditSink();
      final store = TomMemoryAuditAnchorStore();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: 'node-a',
        interval: const Duration(hours: 24),
      );
      await publisher.start();
      expect(store.anchors, hasLength(1));
      publisher.stop();
      sink.close();
    });

    test('the schedule keeps publishing, and stop ends it', () async {
      final sink = TomMemoryAuditSink();
      final store = TomMemoryAuditAnchorStore();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: 'node-a',
        interval: const Duration(milliseconds: 20),
      );
      await publisher.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      publisher.stop();
      expect(store.anchors.length, greaterThan(2));

      // The second half is the part that needs the clock. Forgetting the
      // `cancel()` and merely dropping the reference leaves a timer that still
      // fires — and on an open publisher those ticks succeed, so the only
      // symptom is anchors continuing to appear after the caller stopped
      // asking for them. Nothing but elapsed time can see that.
      final stopped = store.anchors.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(store.anchors, hasLength(stopped));
      sink.close();
    });

    // `close()` is `TomClosable`'s method and inherits its synchronous
    // contract, so it cannot wait for a publication — and a publication it
    // starts without waiting is one the shutdown it was called for will not be
    // around to finish. These tests fix the split the way the sink's
    // `close()`/`flushAndClose()` pair already does: the synchronous call makes
    // no promise it cannot keep, and the awaitable sibling makes the one that
    // matters.
    //
    // None of them may use a delay to see their result. A guarantee that needs
    // the test to wait a turn is a guarantee that is not there at the only
    // moment it is claimed for.
    group('closing the publisher', () {
      test('close stops the schedule and publishes nothing', () async {
        final sink = TomMemoryAuditSink();
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
          interval: const Duration(hours: 24),
        );
        await publisher.start();
        await sink.write(_record('r0'));
        publisher.close();

        // Pumped generously: the point is not that the anchor is late, it is
        // that there is no anchor. A `close()` that started one would land it
        // here and still have lost it in a real shutdown.
        await pumpEventQueue();
        expect(store.anchors, hasLength(1));
        expect(store.anchors.single.entryCount, 0);
        sink.close();
      });

      test('publishAndClose anchors the final head, with no delay', () async {
        final sink = TomMemoryAuditSink();
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
          interval: const Duration(hours: 24),
        );
        await publisher.start();
        await sink.write(_record('r0'));
        await publisher.publishAndClose();

        expect(store.anchors, hasLength(2));
        expect(store.anchors.last.entryCount, 1);
        expect(store.anchors.last.headHash, sink.headHash);
        sink.close();
      });

      test('publishAndClose closes: the schedule does not restart', () async {
        final sink = TomMemoryAuditSink();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: TomMemoryAuditAnchorStore(),
          writer: 'node-a',
        );
        await publisher.publishAndClose();

        await expectLater(publisher.start(), throwsA(isA<TomAuditException>()));
        sink.close();
      });

      test('every way of stopping cancels the timer', () async {
        // Refusing later publications is not the same as cancelling the timer,
        // and only the second lets the process exit: a periodic `Timer` holds
        // the isolate alive on its own. A close that marked itself closed but
        // left the timer armed would fire forever into the guard that refuses
        // it — an error logged every interval, and a shutdown that never
        // completes — while every anchor count in this file stayed exactly as
        // expected, because a refused tick appends nothing. Counting anchors
        // cannot see this; `isScheduled` is what tells the two apart.
        final sink = TomMemoryAuditSink();
        addTearDown(sink.close);

        Future<TomAuditAnchorPublisher> armed() async {
          final publisher = TomAuditAnchorPublisher(
            sink: sink,
            store: TomMemoryAuditAnchorStore(),
            writer: 'node-a',
          );
          await publisher.start();
          expect(publisher.isScheduled, isTrue, reason: 'start arms the timer');
          return publisher;
        }

        expect(
          (await armed()
                ..stop())
              .isScheduled,
          isFalse,
          reason: 'stop',
        );
        expect(
          (await armed()
                ..close())
              .isScheduled,
          isFalse,
          reason: 'close',
        );

        final closing = await armed();
        await closing.publishAndClose();
        expect(closing.isScheduled, isFalse, reason: 'publishAndClose');
      });

      test('publishAndClose is idempotent', () async {
        // Shutdown paths run twice more often than anyone plans for — a signal
        // handler and a `finally`, say — and a second final anchor would be a
        // second claim about the same head from a publisher that had already
        // said goodbye.
        final sink = TomMemoryAuditSink();
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
        );
        await publisher.publishAndClose();
        await publisher.publishAndClose();

        expect(store.anchors, hasLength(1));
        sink.close();
      });

      test('publishAndClose after close publishes nothing', () async {
        // The caller already took the synchronous exit. Publishing now would
        // be a closed publisher writing to the store, which is exactly what
        // the guard on `publishNow` refuses.
        final sink = TomMemoryAuditSink();
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
        );
        publisher.close();
        await publisher.publishAndClose();

        expect(store.anchors, isEmpty);
        sink.close();
      });

      test('a store outage fails publishAndClose but still closes', () async {
        // Two claims, and they pull in opposite directions. The caller asked
        // for a publication, so they are entitled to learn it did not happen —
        // unlike the scheduled tick, which only logs. But the publisher must
        // end up closed regardless: a shutdown that leaves the timer running
        // because the store was down is a process that will not exit.
        final sink = TomMemoryAuditSink();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: _BrokenStore(),
          writer: 'node-a',
        );

        await expectLater(
          publisher.publishAndClose(),
          throwsA(isA<TomAuditException>()),
        );
        await expectLater(
          publisher.start(),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.anchor.publisher_closed',
            ),
          ),
        );
        sink.close();
      });
    });

    test('a store outage is logged, not thrown into the timer', () async {
      final sink = TomMemoryAuditSink();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: _BrokenStore(),
        writer: 'node-a',
        interval: const Duration(milliseconds: 20),
      );
      // start() awaits the first publication directly, so the caller does learn
      // about it; only the scheduled path swallows.
      await expectLater(publisher.start(), throwsA(isA<TomAuditException>()));
      publisher.stop();
      sink.close();
    });

    test('publishing after close is refused, by either route', () async {
      // Both routes, because a caller reaching a closed publisher does not
      // know which one they hold: `start()` is the scheduled entry point and
      // `publishNow()` the direct one, and a guard on only the first leaves
      // the second appending to the store on behalf of an object that has
      // already announced it stopped.
      final sink = TomMemoryAuditSink();
      final store = TomMemoryAuditAnchorStore();
      final publisher = TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: 'node-a',
      );
      publisher.close();

      const closed = 'audit.anchor.publisher_closed';
      await expectLater(
        publisher.start(),
        throwsA(isA<TomAuditException>().having((e) => e.key, 'key', closed)),
      );
      await expectLater(
        publisher.publishNow(),
        throwsA(isA<TomAuditException>().having((e) => e.key, 'key', closed)),
      );
      expect(store.anchors, isEmpty);
      sink.close();
    });
  });
}

class _BrokenStore extends TomAuditAnchorStore {
  @override
  Future<void> append(TomAuditAnchor anchor) async =>
      throw TomAuditException('test.store.down', 'anchor store is unreachable');

  @override
  Future<List<TomAuditAnchor>> read(String writer) async => const [];
}
