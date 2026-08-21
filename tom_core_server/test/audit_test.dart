import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureSecretRecord, FixtureTaskRecord, FixtureUnauditedRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// CE-LG audit-trail tests, verified without a database or a server.
///
/// The audit module is deliberately layered so that everything except the two
/// chokepoint call sites is pure or file-local: the record and its JSON form,
/// the hash chain and its verification, the sinks, the policy resolution, and
/// the `before`/`after` diff. That surface is what these tests exercise. The
/// chokepoints themselves — repository mutations produce records with no
/// per-caller opt-in — are covered against a live database in
/// `audit_db_test.dart`.

/// A sink that always fails, to assert the fail-closed contract: an action
/// whose record cannot be stored must not be able to report success.
class _FailingSink implements TomAuditSink {
  int attempts = 0;

  @override
  String get headHash => tomAuditGenesisHash;

  @override
  int get entryCount => 0;

  @override
  Future<TomAuditEntry> write(TomAuditRecord record) async {
    attempts++;
    throw TomAuditException('test.sink.always_fails', 'storage is unavailable');
  }

  @override
  void close() {}

  @override
  Future<void> flushAndClose() async => close();
}

TomAuditRecord _record(
  String id, {
  TomAuditAction action = TomAuditAction.update,
  String target = 'Widget',
  String? targetKey,
  TomAuditOutcome outcome = TomAuditOutcome.succeeded,
  TomAuditActor? actor,
  Map<String, Object?> before = const {},
  Map<String, Object?> after = const {},
  String? requestId,
  String? detail,
}) => TomAuditRecord(
  id: id,
  timestamp: DateTime.utc(2026, 7, 28, 10, 30),
  actor: actor ?? TomAuditActor.system,
  action: action,
  target: target,
  targetKey: targetKey,
  outcome: outcome,
  requestId: requestId,
  before: before,
  after: after,
  detail: detail,
);

void main() {
  tearDown(() {
    TomAuditTrail.uninstall();
    TomAuditTrail.resetPolicyCache();
  });

  group('TomAuditActor (attribution)', () {
    test('an absent principal is attributed to SYSTEM, never to null', () {
      final actor = TomAuditActor.fromPrincipal(null);
      expect(actor.username, TomAuditActor.systemUsername);
      expect(actor.userId, isNull);
      expect(actor.authenticated, isFalse);
    });

    test('a principal is carried across in full', () {
      final principal = TomPrincipal(
        user: TomUser(id: 42, username: 'ada'),
        authenticated: true,
        organizationId: 7,
        applicationId: 3,
      );
      final actor = TomAuditActor.fromPrincipal(principal);
      expect(actor.username, 'ada');
      expect(actor.userId, 42);
      expect(actor.authenticated, isTrue);
      expect(actor.organizationId, 7);
      expect(actor.applicationId, 3);
      expect(actor.toString(), 'ada#42');
    });

    test("TomPrincipal's -1 'unset' sentinel becomes null, not user -1", () {
      // A guest principal leaves all three ids at -1.
      final actor = TomAuditActor.fromPrincipal(TomPrincipal());
      expect(actor.userId, isNull);
      expect(actor.organizationId, isNull);
      expect(actor.applicationId, isNull);
      expect(actor.toJson().containsKey('userId'), isFalse);
    });

    test('the zone principal is picked up without being passed in', () async {
      final principal = TomPrincipal(
        user: TomUser(id: 5, username: 'grace'),
        authenticated: true,
      );
      final actor = await runZoned(
        () async => TomAuditActor.fromCurrentZone(),
        zoneValues: {TomPrincipal: principal},
      );
      expect(actor.username, 'grace');
      expect(actor.userId, 5);
    });

    test('outside a zone the actor falls back to SYSTEM', () {
      expect(
        TomAuditActor.fromCurrentZone().username,
        TomAuditActor.systemUsername,
      );
    });

    test('round-trips through JSON', () {
      const actor = TomAuditActor(
        username: 'ada',
        userId: 1,
        authenticated: true,
        organizationId: 2,
        applicationId: 3,
      );
      final back = TomAuditActor.fromJson(actor.toJson());
      expect(back.username, actor.username);
      expect(back.userId, actor.userId);
      expect(back.authenticated, actor.authenticated);
      expect(back.organizationId, actor.organizationId);
      expect(back.applicationId, actor.applicationId);
    });
  });

  group('TomAuditRecord', () {
    test('a local timestamp is coerced to UTC', () {
      final record = TomAuditRecord(
        id: 'r1',
        timestamp: DateTime(2026, 7, 28, 10, 30),
        actor: TomAuditActor.system,
        action: TomAuditAction.create,
        target: 'Widget',
        outcome: TomAuditOutcome.succeeded,
      );
      expect(record.timestamp.isUtc, isTrue);
    });

    test('before/after are unmodifiable once recorded', () {
      final record = _record('r1', before: {'a': 1});
      expect(() => record.before['a'] = 2, throwsUnsupportedError);
      expect(() => record.after['b'] = 2, throwsUnsupportedError);
    });

    test('toJson omits empty collections and null fields', () {
      final json = _record('r1').toJson();
      expect(json.containsKey('before'), isFalse);
      expect(json.containsKey('after'), isFalse);
      expect(json.containsKey('targetKey'), isFalse);
      expect(json.containsKey('requestId'), isFalse);
      expect(json.containsKey('detail'), isFalse);
    });

    test('toJson key order is canonical, so the hash is stable', () {
      // The sink hashes this encoding; an order that varied between two
      // encodings of the same record would break the chain for no reason.
      final json = _record(
        'r1',
        targetKey: '7',
        requestId: 'req-1',
        before: {'a': 1},
        after: {'a': 2},
        detail: 'note',
      ).toJson();
      expect(json.keys.toList(), [
        'id',
        'timestamp',
        'actor',
        'action',
        'target',
        'targetKey',
        'outcome',
        'requestId',
        'before',
        'after',
        'detail',
      ]);
    });

    test('round-trips through JSON with every field populated', () {
      final record = _record(
        'r1',
        action: TomAuditAction.delete,
        targetKey: '7',
        outcome: TomAuditOutcome.denied,
        actor: const TomAuditActor(username: 'ada', userId: 1),
        before: {'title': 'old'},
        after: {'title': 'new'},
        requestId: 'req-1',
        detail: 'because',
      );
      final back = TomAuditRecord.fromJson(
        (jsonDecode(jsonEncode(record.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(back.id, record.id);
      expect(back.timestamp, record.timestamp);
      expect(back.actor.username, 'ada');
      expect(back.action, TomAuditAction.delete);
      expect(back.target, 'Widget');
      expect(back.targetKey, '7');
      expect(back.outcome, TomAuditOutcome.denied);
      expect(back.requestId, 'req-1');
      expect(back.before, {'title': 'old'});
      expect(back.after, {'title': 'new'});
      expect(back.detail, 'because');
    });

    // Bug §75. `before`/`after` are filled straight from an entity's fields, so
    // whatever a column holds arrives here — and the record is JSON-encoded
    // three times over (the chain hash, the file sink's line, the SQL sink's
    // column). A value `jsonEncode` cannot represent therefore did not merely
    // spoil the record: `_audit` is deliberately uncaught, so the *mutation*
    // raised. An audited entity with a `DateTime` column could not be updated
    // or deleted at all.
    group('non-encodable values in before/after (bug §75)', () {
      test('a DateTime is normalised to its ISO-8601 form', () {
        final at = DateTime.utc(2026, 8, 2, 5);
        final record = _record('r1', before: {'createdAt': at});
        expect(record.before['createdAt'], at.toIso8601String());
        // The same encoding `timestamp` uses, so one record does not spell a
        // moment two ways.
        expect(() => jsonEncode(record.toJson()), returnsNormally);
      });

      test('a local DateTime is normalised as UTC', () {
        final local = DateTime(2026, 8, 2, 5);
        final record = _record('r1', after: {'dueAt': local});
        expect(record.after['dueAt'], local.toUtc().toIso8601String());
      });

      test('an enum is normalised to its name', () {
        final record = _record('r1', before: {'action': TomAuditAction.delete});
        expect(record.before['action'], 'delete');
      });

      test('nested lists and maps are normalised through', () {
        final at = DateTime.utc(2026, 8, 2);
        final record = _record(
          'r1',
          after: {
            'tags': ['a', at],
            'meta': {'seen': at},
          },
        );
        expect(record.after['tags'], ['a', at.toIso8601String()]);
        expect(record.after['meta'], {'seen': at.toIso8601String()});
        expect(() => jsonEncode(record.toJson()), returnsNormally);
      });

      test(
        'an arbitrary object falls back to toString rather than raising',
        () {
          // Recording an approximation of a changed field beats refusing the
          // mutation: the trail's job is to say *that* the field changed, and a
          // throw here would make the framework delete the operation instead.
          final record = _record(
            'r1',
            before: {'zone': TomZonedDate(year: 2026, month: 8, day: 2)},
          );
          expect(record.before['zone'], isA<String>());
          expect(() => jsonEncode(record.toJson()), returnsNormally);
        },
      );

      test('encodable values are left exactly as they are', () {
        // The normalisation must stay a conversion of the values `jsonEncode`
        // rejects, not a blanket stringification of every audited field.
        final record = _record(
          'r1',
          before: {'n': 1, 'x': 1.5, 'b': true, 's': 'v', 'z': null},
        );
        expect(record.before, {
          'n': 1,
          'x': 1.5,
          'b': true,
          's': 'v',
          'z': null,
        });
      });

      test('normalising is idempotent, so a re-read record is unchanged', () {
        // `fromJson` builds through the same constructor, so a record read back
        // out of an archive is normalised a second time. It must be a no-op —
        // otherwise a stored trail's hashes would not survive being re-read.
        final record = _record('r1', before: {'createdAt': DateTime.utc(2026)});
        final back = TomAuditRecord.fromJson(
          (jsonDecode(jsonEncode(record.toJson())) as Map)
              .cast<String, Object?>(),
        );
        expect(back.before, record.before);
        expect(
          TomAuditEntry.hashOf(back, 'x'),
          TomAuditEntry.hashOf(record, 'x'),
        );
      });
    });

    test('an unknown enum name does not make an old archive unreadable', () {
      final json = _record('r1').toJson();
      json['action'] = 'teleport';
      json['outcome'] = 'exploded';
      final back = TomAuditRecord.fromJson(json);
      expect(back.action, TomAuditAction.execute);
      expect(back.outcome, TomAuditOutcome.failed);
    });
  });

  group('auditDiff', () {
    test('keeps only the fields that actually changed', () {
      final diff = auditDiff(
        {'title': 'old', 'priority': 1, 'done': false},
        {'title': 'new', 'priority': 1, 'done': false},
      );
      expect(diff.before, {'title': 'old'});
      expect(diff.after, {'title': 'new'});
    });

    test('an identical pair produces no entry content at all', () {
      final diff = auditDiff({'a': 1}, {'a': 1});
      expect(diff.before, isEmpty);
      expect(diff.after, isEmpty);
    });

    test('a key present on only one side counts as changed', () {
      final diff = auditDiff({'gone': 1}, {'added': 2});
      expect(diff.before, {'gone': 1});
      expect(diff.after, {'added': 2});
    });

    test('null-to-value and value-to-null are both changes', () {
      final diff = auditDiff({'a': null, 'b': 1}, {'a': 1, 'b': null});
      expect(diff.before, {'a': null, 'b': 1});
      expect(diff.after, {'a': 1, 'b': null});
    });
  });

  group('TomAuditPolicy (the declared-versus-automatic split)', () {
    test('the default policy audits mutations but not reads', () {
      const policy = TomAuditPolicy.defaultPolicy;
      expect(policy.audits(TomAuditAction.create), isTrue);
      expect(policy.audits(TomAuditAction.update), isTrue);
      expect(policy.audits(TomAuditAction.delete), isTrue);
      expect(policy.audits(TomAuditAction.execute), isTrue);
      expect(policy.audits(TomAuditAction.read), isFalse);
    });

    test('no policy audits reads, whatever the annotation declares', () {
      // There is no read opt-in, and the point of the test is that there is no
      // way to construct one. `enabled: true` is the most permissive policy
      // the annotation can express; it still refuses reads.
      final policies = <TomAuditPolicy>[
        TomAuditPolicy.defaultPolicy,
        TomAuditPolicy.disabled,
        TomAuditPolicy.from(const TomAudited()),
        TomAuditPolicy.from(const TomAudited(enabled: true)),
        TomAuditPolicy.from(const TomAudited(enabled: false)),
        TomAuditPolicy.from(const TomAudited(redact: ['x'])),
        const TomAuditPolicy(enabled: true, redact: {}),
      ];
      for (final policy in policies) {
        expect(policy.audits(TomAuditAction.read), isFalse);
      }
      // Non-vacuity: the same permissive policies do audit a mutation, so the
      // loop above is refusing reads specifically and not refusing everything.
      expect(
        TomAuditPolicy.from(const TomAudited()).audits(TomAuditAction.update),
        isTrue,
      );
    });

    test('enabled: false is the declared opt-out, and covers everything', () {
      final policy = TomAuditPolicy.from(const TomAudited(enabled: false));
      for (final action in TomAuditAction.values) {
        expect(policy.audits(action), isFalse, reason: action.name);
      }
    });

    test('redaction replaces values but keeps the field visible', () {
      final policy = TomAuditPolicy.from(
        const TomAudited(redact: ['password', 'token']),
      );
      final masked = policy.applyRedaction({
        'password': 'hunter2',
        'token': 'abc',
        'title': 'ok',
      });
      // "changed, and you may not see to what" must stay distinguishable from
      // "did not change", so the key survives.
      expect(masked['password'], tomAuditRedactedPlaceholder);
      expect(masked['token'], tomAuditRedactedPlaceholder);
      expect(masked['title'], 'ok');
    });

    test('redacting nothing costs no copy', () {
      const values = {'a': 1};
      expect(
        identical(TomAuditPolicy.defaultPolicy.applyRedaction(values), values),
        isTrue,
      );
    });

    test('a type with no annotation resolves to the default policy', () {
      // String is reflectable-by-nothing; the lookup must not throw, and being
      // unreflectable must not be a way out of the trail.
      final policy = TomAuditTrail.policyFor(String);
      expect(policy.enabled, isTrue);
      expect(policy.audits(TomAuditAction.read), isFalse);
    });
  });

  group('policyFor (resolution through the reflector)', () {
    setUpAll(initializeReflection);

    test('a reflected entity with no @TomAudited is audited anyway', () {
      // The heart of "no per-entity opt-in": FixtureTaskRecord declares
      // nothing about auditing and is audited for mutations regardless.
      final policy = TomAuditTrail.policyFor(FixtureTaskRecord);
      expect(policy.enabled, isTrue);
      expect(policy.audits(TomAuditAction.update), isTrue);
      expect(policy.audits(TomAuditAction.read), isFalse);
      expect(policy.redact, isEmpty);
    });

    test('a declared redaction list is read off the annotation', () {
      final policy = TomAuditTrail.policyFor(FixtureSecretRecord);
      expect(policy.enabled, isTrue);
      expect(policy.redact, {'secret'});
      expect(policy.applyRedaction({'label': 'x', 'secret': 'hunter2'}), {
        'label': 'x',
        'secret': tomAuditRedactedPlaceholder,
      });
    });

    test('a declared opt-out is read off the annotation', () {
      final policy = TomAuditTrail.policyFor(FixtureUnauditedRecord);
      expect(policy.enabled, isFalse);
      expect(policy.audits(TomAuditAction.delete), isFalse);
    });

    test('the resolved policy is cached per type', () {
      final first = TomAuditTrail.policyFor(FixtureSecretRecord);
      expect(
        identical(TomAuditTrail.policyFor(FixtureSecretRecord), first),
        isTrue,
      );
      TomAuditTrail.resetPolicyCache();
      expect(TomAuditTrail.policyFor(FixtureSecretRecord).redact, {'secret'});
    });
  });

  group('TomAuditEntry and the hash chain', () {
    test('an entry hashes its record and its link together', () {
      final entry = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      expect(entry.previousHash, tomAuditGenesisHash);
      expect(entry.hash.length, 64);
      expect(entry.isSelfConsistent, isTrue);
    });

    test('the same record on a different link gets a different hash', () {
      final record = _record('r1');
      final a = TomAuditEntry.chain(record, tomAuditGenesisHash, index: 0);
      final b = TomAuditEntry.chain(record, a.hash, index: 1);
      expect(a.hash, isNot(b.hash));
    });

    test('the index is outside the hash, so numbering cannot forge one', () {
      final record = _record('r1');
      final a = TomAuditEntry.chain(record, tomAuditGenesisHash, index: 0);
      final b = TomAuditEntry.chain(record, tomAuditGenesisHash, index: 77);
      expect(a.hash, b.hash);
      expect(b.isSelfConsistent, isTrue);
    });

    test('an unbroken chain verifies', () {
      final a = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final b = TomAuditEntry.chain(_record('r2'), a.hash, index: 1);
      final c = TomAuditEntry.chain(_record('r3'), b.hash, index: 2);
      final result = verifyAuditChain([a, b, c]);
      expect(result.isValid, isTrue);
      expect(result.entryCount, 3);
      expect(result.brokenAtIndex, isNull);
    });

    test('editing an entry after the fact is detected as a content change', () {
      final a = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final b = TomAuditEntry.chain(
        _record('r2', after: {'x': 1}),
        a.hash,
        index: 1,
      );
      // Rewrite b's record, keeping its claimed hashes — a targeted forgery.
      final forged = TomAuditEntry(
        record: _record('r2', after: {'x': 999}),
        previousHash: b.previousHash,
        hash: b.hash,
        index: b.index,
      );
      final result = verifyAuditChain([a, forged]);
      expect(result.isValid, isFalse);
      expect(result.brokenAtIndex, 1);
      expect(result.detail, contains('content changed'));
    });

    test('removing an entry is detected as a broken link', () {
      final a = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final b = TomAuditEntry.chain(_record('r2'), a.hash, index: 1);
      final c = TomAuditEntry.chain(_record('r3'), b.hash, index: 2);
      // Drop b and hope nobody notices.
      final result = verifyAuditChain([a, c]);
      expect(result.isValid, isFalse);
      expect(result.brokenAtIndex, 1);
      expect(result.detail, contains('link mismatch'));
    });

    test('renumbering an otherwise intact chain is detected', () {
      // The index is not hashed, so it is the one field that can be rewritten
      // without breaking a digest. Left unchecked it would slide the window an
      // anchor is compared against.
      final a = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final b = TomAuditEntry.chain(_record('r2'), a.hash, index: 1);
      final renumbered = TomAuditEntry(
        record: b.record,
        previousHash: b.previousHash,
        hash: b.hash,
        index: 9,
      );
      final result = verifyAuditChain([a, renumbered]);
      expect(result.isValid, isFalse);
      expect(result.brokenAtIndex, 1);
      expect(result.detail, contains('renumbered'));
    });

    test('reordering two entries is detected', () {
      final a = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final b = TomAuditEntry.chain(_record('r2'), a.hash, index: 1);
      expect(verifyAuditChain([b, a]).isValid, isFalse);
    });

    test('entries round-trip through their JSON line', () {
      final entry = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 4,
      );
      final line = entry.toJsonLine();
      expect(line, isNot(contains('\n')));
      final back = TomAuditEntry.fromJson(
        (jsonDecode(line) as Map).cast<String, Object?>(),
      );
      expect(back.hash, entry.hash);
      expect(back.previousHash, entry.previousHash);
      expect(back.index, 4);
      expect(back.record.id, 'r1');
      expect(back.isSelfConsistent, isTrue);
    });

    test('parseAuditLines skips blanks and rejects damage', () {
      final entry = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      expect(parseAuditLines([entry.toJsonLine(), '', '  ']), hasLength(1));
      // A malformed line is itself a finding; swallowing it would hide the
      // damage the chain exists to reveal.
      expect(
        () => parseAuditLines(['{not json']),
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.parse.malformed_line',
          ),
        ),
      );
    });

    test('a damaged line is reported by its number in the file', () {
      // Which line is the whole value of the message: the operator's next step
      // is to look at the storage, and "somewhere in this trail" is not a
      // starting point. Blanks are skipped but still counted, so the number
      // matches what an editor shows.
      final good = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      ).toJsonLine();
      expect(
        () => parseAuditLines([good, '', '{not json']),
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('line 3'),
          ),
        ),
      );
    });

    test('an entry with no chain index is rejected rather than defaulted', () {
      // Defaulting the index would mean guessing the entry's position, and a
      // guessed position is exactly what anchor verification is built on: it
      // would turn a truncated trail into a merely short one, which is the one
      // damage the chain exists to make visible.
      final complete =
          jsonDecode(
                TomAuditEntry.chain(
                  _record('r1'),
                  tomAuditGenesisHash,
                  index: 7,
                ).toJsonLine(),
              )
              as Map;

      for (final broken in <Object?>[null, '7', 7.5]) {
        final json = complete.cast<String, Object?>();
        json['index'] = broken;
        expect(
          () => TomAuditEntry.fromJson(json),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.entry.missing_index',
            ),
          ),
          reason: 'index: $broken',
        );
      }
    });

    test('a line whose entry has no index is a malformed line', () {
      // The two guards compose: the entry-level refusal reaches the caller
      // wrapped as the parse failure, so a trail read never has to distinguish
      // "unreadable JSON" from "readable JSON that is not an entry".
      expect(
        () => parseAuditLines(['{"record":{},"hash":"h"}']),
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.parse.malformed_line',
          ),
        ),
      );
    });

    // The same reasoning the index guard is built on, applied to the two
    // fields the chain is actually made of. A default here does not produce a
    // vague entry — it produces a *specific accusation* about a record nobody
    // touched, which is worse than refusing to read the line at all.
    group('the chain fields are required, not defaulted', () {
      /// [entry]'s JSON with [field] removed, as a damaged line would arrive.
      Map<String, Object?> without(TomAuditEntry entry, String field) =>
          (jsonDecode(entry.toJsonLine()) as Map).cast<String, Object?>()
            ..remove(field);

      TomAuditEntry first(String id) =>
          TomAuditEntry.chain(_record(id), tomAuditGenesisHash, index: 0);

      test('an entry with no hash is rejected rather than read as edited', () {
        // Defaulted to '', the entry reads back as one whose stored hash does
        // not match its contents — which `verifyAuditChain` reports as
        // "content changed after writing". An investigation that starts from
        // "this record was edited" goes somewhere else entirely.
        for (final broken in <Object?>[null, '', 42]) {
          final json = without(first('r1'), 'hash');
          if (broken != null) json['hash'] = broken;
          expect(
            () => TomAuditEntry.fromJson(json),
            throwsA(
              isA<TomAuditException>().having(
                (e) => e.key,
                'key',
                'audit.entry.missing_hash',
              ),
            ),
            reason: 'hash: $broken',
          );
        }
      });

      test(
        'an entry with no previous hash is rejected, not read as genesis',
        () {
          // Defaulting to genesis claims the entry began a chain. Mid-chain that
          // is a link mismatch — "an entry was removed or reordered here" — and
          // at the head it is not a finding at all; see the next test.
          for (final broken in <Object?>[null, '', 42]) {
            final json = without(first('r1'), 'previousHash');
            if (broken != null) json['previousHash'] = broken;
            expect(
              () => TomAuditEntry.fromJson(json),
              throwsA(
                isA<TomAuditException>().having(
                  (e) => e.key,
                  'key',
                  'audit.entry.missing_previous_hash',
                ),
              ),
              reason: 'previousHash: $broken',
            );
          }
        },
      );

      test('a lone damaged entry no longer verifies as a healthy first', () {
        // The silent direction, and the one that costs the guarantee rather
        // than merely misdirecting an investigation. A single entry that lost
        // its link defaulted to genesis, was self-consistent against that
        // genesis link — the hash covers the link, and the link it was hashed
        // with was the one supplied — and so passed verification outright.
        // Damage read back as health.
        expect(
          () => TomAuditEntry.fromJson(without(first('r1'), 'previousHash')),
          throwsA(isA<TomAuditException>()),
        );
      });

      test('a hashless line is a malformed line', () {
        // The point of the whole change: `parseAuditLines` promises that
        // anything it cannot read is reported, and until the guards existed a
        // line that parsed as JSON but was not an entry slipped past it.
        for (final field in ['hash', 'previousHash']) {
          expect(
            () => parseAuditLines([jsonEncode(without(first('r1'), field))]),
            throwsA(
              isA<TomAuditException>().having(
                (e) => e.key,
                'key',
                'audit.parse.malformed_line',
              ),
            ),
            reason: 'missing $field',
          );
        }
      });

      test('an entry with no record is refused the same way', () {
        // Not a defaulting defect — an absent record already failed — but it
        // failed as a `TypeError`, so one field of four left the factory by a
        // different door. `parseAuditLines` catches everything and hid the
        // difference; a direct caller saw it.
        expect(
          () => TomAuditEntry.fromJson(without(first('r1'), 'record')),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.entry.missing_record',
            ),
          ),
        );
      });
    });
  });

  group('TomMemoryAuditSink', () {
    test('writes are chained in order and verify', () async {
      final sink = TomMemoryAuditSink();
      await sink.write(_record('r1'));
      await sink.write(_record('r2'));
      await sink.write(_record('r3'));
      expect(sink.records.map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(sink.headHash, sink.entries.last.hash);
      expect(sink.verify().isValid, isTrue);
    });

    test('bounded retention drops the oldest and says so', () async {
      final sink = TomMemoryAuditSink(maxEntries: 2);
      for (var i = 1; i <= 5; i++) {
        await sink.write(_record('r$i'));
      }
      expect(sink.entries, hasLength(2));
      expect(sink.records.map((r) => r.id), ['r4', 'r5']);
      expect(sink.droppedCount, 3);
      // A suffix cannot start from genesis, so verification starts from the
      // oldest surviving link rather than reporting a false break.
      expect(sink.verify().isValid, isTrue);
    });

    test('clear resets the chain back to genesis', () async {
      final sink = TomMemoryAuditSink();
      await sink.write(_record('r1'));
      sink.clear();
      expect(sink.entries, isEmpty);
      expect(sink.headHash, tomAuditGenesisHash);
      expect(sink.droppedCount, 0);
    });
  });

  group('TomFileAuditSink', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tom_audit_test_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('creates its directory and starts from genesis', () {
      final nested = Directory('${dir.path}/a/b');
      final sink = TomFileAuditSink(directory: nested);
      addTearDown(sink.close);
      expect(nested.existsSync(), isTrue);
      expect(sink.headHash, tomAuditGenesisHash);
    });

    test('appends one JSON line per record', () async {
      final sink = TomFileAuditSink(directory: dir);
      addTearDown(sink.close);
      await sink.write(_record('r1'));
      await sink.write(_record('r2'));
      expect(sink.files, hasLength(1));
      expect(sink.files.single.readAsLinesSync(), hasLength(2));
      expect(sink.readAll().map((e) => e.record.id), ['r1', 'r2']);
      expect(sink.verify().isValid, isTrue);
    });

    test('rotation moves the file aside and continues the chain', () async {
      // A tiny cap forces a rotation after the first record.
      final sink = TomFileAuditSink(directory: dir, maxFileBytes: 300);
      addTearDown(sink.close);
      for (var i = 1; i <= 4; i++) {
        await sink.write(_record('r$i'));
      }
      expect(sink.files.length, greaterThan(1));
      // Nothing is lost or rewritten by rotation, and the chain spans files.
      final all = sink.readAll();
      expect(all.map((e) => e.record.id), ['r1', 'r2', 'r3', 'r4']);
      expect(sink.verify().isValid, isTrue);
    });

    test(
      'a reopened sink continues the chain instead of starting a new one',
      () async {
        final first = TomFileAuditSink(directory: dir);
        await first.write(_record('r1'));
        final head = first.headHash;
        first.close();

        final second = TomFileAuditSink(directory: dir);
        addTearDown(second.close);
        expect(second.headHash, head);
        await second.write(_record('r2'));
        expect(second.readAll().map((e) => e.record.id), ['r1', 'r2']);
        expect(second.verify().isValid, isTrue);
      },
    );

    test('head recovery never adopts an unreadable final line', () {
      // Recovery reads the newest file's last line, and a line it cannot read
      // sends it to the previous file — deliberately, because a half-written
      // final line is what a crash mid-write leaves behind. A line that parses
      // as JSON but has lost a chain field must take that same path: the
      // alternative, which is what a defaulted hash produced, is a live sink
      // whose head is the empty string, linking every subsequent entry onto a
      // hash no entry has. The break would then sit at the restart boundary
      // and read as tampering.
      final good = TomAuditEntry.chain(
        _record('r1'),
        tomAuditGenesisHash,
        index: 0,
      );
      final next = TomAuditEntry.chain(_record('r2'), good.hash, index: 1);
      File(
        '${dir.path}/audit-2026-07-28-000001.jsonl',
      ).writeAsStringSync('${good.toJsonLine()}\n');

      final live = File('${dir.path}/audit-2026-07-28.jsonl');
      // A truncated line is the control: the two damages must recover alike.
      final damaged = {
        'lost a chain field': jsonEncode(
          (jsonDecode(next.toJsonLine()) as Map).cast<String, Object?>()
            ..remove('hash'),
        ),
        'truncated mid-write': next.toJsonLine().substring(0, 40),
      };
      for (final entry in damaged.entries) {
        live.writeAsStringSync('${entry.value}\n');
        final sink = TomFileAuditSink(directory: dir);
        addTearDown(sink.close);
        expect(sink.headHash, good.hash, reason: entry.key);
        expect(sink.entryCount, 1, reason: entry.key);
      }
    });

    test(
      'count-based retention deletes whole files, keeping a valid suffix',
      () async {
        final sink = TomFileAuditSink(
          directory: dir,
          maxFileBytes: 300,
          maxFiles: 2,
        );
        addTearDown(sink.close);
        for (var i = 1; i <= 6; i++) {
          await sink.write(_record('r$i'));
        }
        expect(sink.files.length, lessThanOrEqualTo(2));
        final surviving = sink.readAll();
        expect(surviving, isNotEmpty);
        // The prefix is gone by policy; what remains still verifies, and the
        // missing head is visible as a non-genesis starting link.
        expect(sink.verify().isValid, isTrue);
        expect(surviving.first.previousHash, isNot(tomAuditGenesisHash));
        expect(surviving.last.record.id, 'r6');
      },
    );

    test('age-based retention removes files older than the window', () async {
      final sink = TomFileAuditSink(
        directory: dir,
        maxFileBytes: 300,
        retention: const Duration(milliseconds: 1),
      );
      addTearDown(sink.close);
      await sink.write(_record('r1'));
      await sink.write(_record('r2'));
      // Make the rotated file look old, then trigger another rotation pass.
      for (final file in sink.files) {
        file.setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 2)),
        );
      }
      await sink.write(_record('r3'));
      await sink.write(_record('r4'));
      expect(sink.readAll().map((e) => e.record.id), isNot(contains('r1')));
    });

    test(
      'a closed sink refuses further records rather than dropping them',
      () async {
        final sink = TomFileAuditSink(directory: dir);
        await sink.write(_record('r1'));
        sink.close();
        expect(
          () => sink.write(_record('r2')),
          throwsA(isA<TomAuditException>()),
        );
      },
    );

    test('concurrent writes still produce a verifiable chain', () async {
      final sink = TomFileAuditSink(directory: dir);
      addTearDown(sink.close);
      await Future.wait([
        for (var i = 1; i <= 20; i++) sink.write(_record('r$i')),
      ]);
      expect(sink.readAll(), hasLength(20));
      expect(sink.verify().isValid, isTrue);
    });

    test('a record still queued when close() runs is refused, not written', () {
      final sink = TomFileAuditSink(directory: dir);
      // Not awaited. The record is enqueued and has not started when close()
      // runs, which is the state `_queue` exists to represent — and the state
      // the enqueue-time `_closed` guard cannot see, because it already let
      // this record through.
      final queued = sink.write(_record('r1'));
      sink.close();

      // Same sink, same closed state, same answer as a write submitted after
      // close returns. Which of the two a caller gets used to depend on where
      // the event loop happened to be, and an audit sink may not answer a
      // question about durability with a coin flip.
      expect(
        queued,
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.sink.closed',
          ),
        ),
      );
    });

    test('close() does not reopen the file to serve a queued record', () async {
      final sink = TomFileAuditSink(directory: dir);
      await sink.write(_record('r1'));
      final queued = sink.write(_record('r2'));
      sink.close();
      await expectLater(queued, throwsA(isA<TomAuditException>()));

      // The refusal is half the claim; the file is the other half. Reaching
      // `_ensureOpen` with `_sink` already nulled used to call `openWrite`
      // again, so the sink reopened the very file it had just closed and
      // appended to it — while the unawaited close of the old handle was still
      // in flight on the same path.
      expect(sink.files, hasLength(1));
      expect(sink.files.single.readAsLinesSync(), hasLength(1));
      expect(sink.readAll().map((e) => e.record.id), ['r1']);
    });

    test('a refused record does not rotate the file on its way out', () async {
      // Cap chosen as in the rotation test above: one record fits, a second
      // does not, so the queued record can only be stored by rotating first.
      final sink = TomFileAuditSink(directory: dir, maxFileBytes: 300);
      await sink.write(_record('r1'));
      final before = sink.files.single.path;

      final queued = sink.write(_record('r2'));
      sink.close();
      await expectLater(queued, throwsA(isA<TomAuditException>()));

      // Refusing has to be free of side effects. Refuse late enough and the
      // record still reaches the rotation logic on its way to being turned
      // away — renaming a file to make room for an entry that was never going
      // to be written. A trail that reshuffles its own files in response to a
      // record it rejected is answering a question nobody asked.
      expect(sink.files.single.path, before);
    });

    test('a close during rotation does not open a new file', () async {
      final sink = TomFileAuditSink(directory: dir, maxFileBytes: 300);
      await sink.write(_record('r1'));

      // Rotation awaits: the outgoing handle is flushed and closed before the
      // replacement is opened. That gap is the only window in which `close()`
      // can land *after* the serialised body has already checked, so it is the
      // window the check at the point of opening exists for.
      final rotating = sink.write(_record('r2'));
      scheduleMicrotask(sink.close);
      await expectLater(rotating, throwsA(isA<TomAuditException>()));

      // One file — the one rotation moved aside. A second would mean the sink
      // created a handle after it was closed, which is the defect in its
      // purest form: not reopening what it closed, but opening something new.
      expect(sink.files, hasLength(1));
      expect(sink.readAll().map((e) => e.record.id), ['r1']);
    });

    test(
      'flushAndClose stores what was queued rather than refusing it',
      () async {
        final sink = TomFileAuditSink(directory: dir);
        final first = sink.write(_record('r1'));
        final queued = sink.write(_record('r2'));

        await sink.flushAndClose();

        // Neither write was awaited before the close, and both are stored. This
        // is what `close()` cannot do: `TomClosable` requires it to return
        // synchronously, and no synchronous method can wait for a queue.
        await expectLater(first, completes);
        await expectLater(queued, completes);
        expect(sink.readAll().map((e) => e.record.id), ['r1', 'r2']);
        expect(sink.verify().isValid, isTrue);
      },
    );

    test('flushAndClose leaves the sink closed', () async {
      final sink = TomFileAuditSink(directory: dir);
      await sink.flushAndClose();
      expect(
        () => sink.write(_record('r1')),
        throwsA(
          isA<TomAuditException>().having(
            (e) => e.key,
            'key',
            'audit.sink.closed',
          ),
        ),
      );
      // Draining is not reopening: an empty sink that was never written to
      // must not have created a file on its way out.
      expect(sink.files, isEmpty);
    });

    test(
      'flushAndClose after close() is a no-op, not a second close',
      () async {
        final sink = TomFileAuditSink(directory: dir);
        await sink.write(_record('r1'));
        sink.close();
        // Shutdown may call both — the registered `TomClosable` and the
        // application's own teardown. The second call must not throw, and must
        // not resurrect anything.
        await sink.flushAndClose();
        expect(sink.readAll().map((e) => e.record.id), ['r1']);
      },
    );
  });

  group('TomAuditTrail', () {
    test('with no sink installed, recording is a silent no-op', () async {
      expect(TomAuditTrail.isEnabled, isFalse);
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'nowhere',
        outcome: TomAuditOutcome.succeeded,
      );
      // No sink, no throw: pretending to audit into nowhere would be worse
      // than plainly not auditing, but so would failing every action.
      expect(TomAuditTrail.sink, isNull);
    });

    test('installing a sink turns auditing on', () {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      expect(TomAuditTrail.isEnabled, isTrue);
      expect(TomAuditTrail.sink, same(sink));
      TomAuditTrail.uninstall();
      expect(TomAuditTrail.isEnabled, isFalse);
    });

    test('recordAction writes an attributed record', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final principal = TomPrincipal(
        user: TomUser(id: 9, username: 'ada'),
        authenticated: true,
      );
      await runZoned(
        () => TomAuditTrail.recordAction(
          action: TomAuditAction.execute,
          target: 'PayrollService.export',
          outcome: TomAuditOutcome.denied,
          detail: 'no grant',
        ),
        zoneValues: {TomPrincipal: principal},
      );
      final record = sink.records.single;
      expect(record.actor.username, 'ada');
      expect(record.actor.userId, 9);
      expect(record.action, TomAuditAction.execute);
      expect(record.target, 'PayrollService.export');
      expect(record.outcome, TomAuditOutcome.denied);
      expect(record.detail, 'no grant');
    });

    test('recordMutation consults the type policy before writing', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      // String has no @TomAudited, so it gets the default policy — but the
      // read below is dropped for a stronger reason than the default: no
      // policy audits reads, so nothing reaching this gate with `read` is ever
      // written. The sanctioned route past it is `recordAction`, which the
      // next test exercises.
      await TomAuditTrail.recordMutation(
        entityType: String,
        action: TomAuditAction.update,
        target: 'Widget',
        targetKey: '7',
        before: {'title': 'old'},
        after: {'title': 'new'},
      );
      await TomAuditTrail.recordMutation(
        entityType: String,
        action: TomAuditAction.read,
        target: 'Widget',
        targetKey: '7',
      );
      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.action, TomAuditAction.update);
      expect(record.targetKey, '7');
      expect(record.before, {'title': 'old'});
      expect(record.after, {'title': 'new'});
    });

    test('recordAction is the way a read reaches the trail', () async {
      // The counterpart to the previous test. `audits(read)` being permanently
      // false closes the automatic path, and the documentation promises this
      // one stays open in exchange — an application that has decided what a
      // read entry should say can still write it, because `recordAction`
      // consults no entity policy at all.
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      await TomAuditTrail.recordAction(
        action: TomAuditAction.read,
        target: 'Patient',
        targetKey: '7',
        outcome: TomAuditOutcome.succeeded,
        detail: 'case review',
      );
      final record = sink.records.single;
      expect(record.action, TomAuditAction.read);
      expect(record.target, 'Patient');
      expect(record.targetKey, '7');
      expect(record.detail, 'case review');
    });

    test('runUnaudited suppresses records inside its body only', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      await TomAuditTrail.runUnaudited(() async {
        expect(TomAuditTrail.isBypassed, isTrue);
        expect(TomAuditTrail.isEnabled, isFalse);
        await TomAuditTrail.recordAction(
          action: TomAuditAction.execute,
          target: 'trail-internal',
          outcome: TomAuditOutcome.succeeded,
        );
      });
      expect(sink.records, isEmpty);
      expect(TomAuditTrail.isBypassed, isFalse);
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'ordinary',
        outcome: TomAuditOutcome.succeeded,
      );
      expect(sink.records, hasLength(1));
    });

    test('fail-closed: a sink that cannot store propagates to the caller', () {
      final sink = _FailingSink();
      TomAuditTrail.install(sink);
      expect(
        () => TomAuditTrail.recordAction(
          action: TomAuditAction.delete,
          target: 'Widget',
          outcome: TomAuditOutcome.succeeded,
        ),
        throwsA(isA<TomAuditException>()),
      );
    });

    test('an audit failure is not client-visible', () {
      final exception = TomAuditException('audit.test', 'internal detail');
      expect(exception.clientThrow, isFalse);
    });

    test('record ids sort in write order', () {
      final ids = [
        for (var i = 0; i < 50; i++) TomAuditTrail.newAuditRecordId(),
      ];
      final sorted = [...ids]..sort();
      expect(sorted, ids);
      expect(ids.toSet(), hasLength(50));
    });

    test('the request id is picked up from the zone', () async {
      expect(TomAuditTrail.currentRequestId(), isNull);
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final requestId = TomRequestId();
      await runZoned(
        () => TomAuditTrail.recordAction(
          action: TomAuditAction.execute,
          target: 'Endpoint',
          outcome: TomAuditOutcome.succeeded,
        ),
        zoneValues: {TomRequestId: requestId},
      );
      // This is what stitches an endpoint denial together with the repository
      // writes of the same request.
      expect(sink.records.single.requestId, requestId.uuid);
    });
  });
}
