/// DB-backed tests for the CE-LG audit trail's **repository chokepoint**.
///
/// The pure audit surface — records, the hash chain, the sinks, policy
/// resolution — is covered connection-free by `audit_test.dart`. This file
/// exercises the one claim that only a real database can substantiate, and the
/// one the whole design turns on: *auditable actions produce attributable
/// records through the chokepoint without per-handler opt-in*. Every test here
/// therefore calls the ordinary [TomSqlDatasourceRepository] API that
/// application code calls — `save`, `delete`, `deleteById`, `deleteAllById` —
/// and asserts on the trail afterwards. Nothing in these tests asks to be
/// audited.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureSecretRecord,
        FixtureSecretRepository,
        FixtureTaskRecord,
        FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

FixtureTaskRecord _task(String title, int priority, {bool done = false}) =>
    FixtureTaskRecord()
      ..title = title
      ..priority = priority
      ..done = done;

FixtureSecretRecord _secret(String label, String secret) =>
    FixtureSecretRecord()
      ..label = label
      ..secret = secret;

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('audit trail at the repository chokepoint', () {
    late TomDataSourceInfo dsi;
    late FixtureTaskRepository repo;
    late FixtureSecretRepository secrets;
    late TomMemoryAuditSink sink;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureTaskTable(dsi);
      await TestDatabase.ensureFixtureSecretTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureTask(dsi);
      await TestDatabase.truncateFixtureSecret(dsi);
      repo = FixtureTaskRepository();
      secrets = FixtureSecretRepository();
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
    });

    tearDown(() {
      TomAuditTrail.uninstall();
      TomAuditTrail.resetPolicyCache();
    });

    tearDownAll(TestDatabase.reset);

    test(
      'an insert is audited as a create carrying the whole stored row',
      () async {
        final saved = await repo.save(_task('write tests', 3, done: true));

        final record = sink.records.single;
        expect(record.action, TomAuditAction.create);
        expect(record.target, 'FixtureTaskRecord');
        expect(record.targetKey, '${saved.id}');
        expect(record.outcome, TomAuditOutcome.succeeded);
        // A create has no before-image; the whole stored row is the change.
        expect(record.before, isEmpty);
        expect(record.after['title'], 'write tests');
        expect(record.after['priority'], 3);
        expect(record.after['done'], isTrue);
        // The database-assigned key is in the record, so the entry names the row
        // it created rather than describing an anonymous insert.
        expect(record.after['id'], saved.id);
      },
    );

    test('an update records only the fields that actually changed', () async {
      final saved = await repo.save(_task('draft', 1));
      sink.clear();

      saved.title = 'final';
      await repo.save(saved);

      final record = sink.records.single;
      expect(record.action, TomAuditAction.update);
      expect(record.targetKey, '${saved.id}');
      expect(record.before, {'title': 'draft'});
      expect(record.after, {'title': 'final'});
      // priority and done were untouched, so they add nothing an auditor can
      // use and are not stored.
      expect(record.before.containsKey('priority'), isFalse);
    });

    test('a save that changes nothing is still recorded as an action', () async {
      final saved = await repo.save(_task('stable', 2));
      sink.clear();

      await repo.save(saved);

      // The row was written to, so the trail says so — with an empty diff,
      // because nothing moved. Suppressing the entry would make completeness
      // depend on the *data* rather than on the action, which is the one thing
      // a trail may not do: someone rewriting a row with identical values would
      // then leave no trace at all.
      final record = sink.records.single;
      expect(record.action, TomAuditAction.update);
      expect(record.targetKey, '${saved.id}');
      expect(record.before, isEmpty);
      expect(record.after, isEmpty);
    });

    test('delete records the row it destroyed', () async {
      final saved = await repo.save(_task('doomed', 1));
      sink.clear();

      await repo.delete(saved);

      final record = sink.records.single;
      expect(record.action, TomAuditAction.delete);
      expect(record.targetKey, '${saved.id}');
      // The caller handed us the row, so the before-image cost no extra read —
      // and a delete entry without one cannot say what was lost.
      expect(record.before['title'], 'doomed');
      expect(record.after, isEmpty);
    });

    test('deleteById records the key even without a before-image', () async {
      final saved = await repo.save(_task('doomed', 1));
      sink.clear();

      await repo.deleteById(saved.id!);

      final record = sink.records.single;
      expect(record.action, TomAuditAction.delete);
      expect(record.targetKey, '${saved.id}');
      // Reading the row first would put an extra SELECT on every delete; the
      // key alone still attributes the destruction.
      expect(record.before, isEmpty);
    });

    test('deleteAllById records one entry per row, not one per call', () async {
      final a = await repo.save(_task('a', 1));
      final b = await repo.save(_task('b', 2));
      sink.clear();

      await repo.deleteAllById([a.id!, b.id!]);

      expect(sink.records, hasLength(2));
      expect(
        sink.records.map((r) => r.targetKey),
        containsAll(['${a.id}', '${b.id}']),
      );
      expect(
        sink.records.every((r) => r.action == TomAuditAction.delete),
        isTrue,
      );
    });

    test('saveAll audits every row it writes', () async {
      await repo.saveAll([_task('a', 1), _task('b', 2), _task('c', 3)]);
      expect(sink.records, hasLength(3));
      expect(
        sink.records.every((r) => r.action == TomAuditAction.create),
        isTrue,
      );
    });

    test('reads are never audited, annotated entity or not', () async {
      final saved = await repo.save(_task('quiet', 1));
      // FixtureSecretRecord carries @TomAudited(redact: ['secret']) — the
      // entity that most plausibly *would* want a read trail. It gets none
      // either: there is no declaration that turns reads on, so the two
      // repositories below must behave identically.
      final savedSecret = await secrets.save(_secret('label', 'hunter2'));
      sink.clear();

      await repo.findById(saved.id!);
      await repo.findAll();
      await repo.count();
      await secrets.findById(savedSecret.id!);
      await secrets.findAll();
      await secrets.count();

      expect(sink.records, isEmpty);

      // Non-vacuity: the same repositories, same sink, one mutation each —
      // so the emptiness above is the read path staying silent, not the trail
      // being uninstalled.
      await repo.save(_task('loud', 2));
      await secrets.save(_secret('other', 'sesame'));
      expect(sink.records, hasLength(2));
    });

    test('the zone principal attributes the write, with no plumbing', () async {
      final principal = TomPrincipal(
        user: TomUser(id: 42, username: 'ada'),
        authenticated: true,
        organizationId: 7,
      );
      final requestId = TomRequestId();

      await runZoned(
        () => repo.save(_task('attributed', 1)),
        zoneValues: {TomPrincipal: principal, TomRequestId: requestId},
      );

      final record = sink.records.single;
      expect(record.actor.username, 'ada');
      expect(record.actor.userId, 42);
      expect(record.actor.authenticated, isTrue);
      expect(record.actor.organizationId, 7);
      // The request id stitches this write to the rest of the same request.
      expect(record.requestId, requestId.uuid);
    });

    test(
      'a write outside a request is attributed to SYSTEM, never to null',
      () async {
        await repo.save(_task('background job', 1));
        final record = sink.records.single;
        expect(record.actor.username, TomAuditActor.systemUsername);
        expect(record.actor.userId, isNull);
        expect(record.requestId, isNull);
      },
    );

    test('a declared redaction keeps the value out of the trail', () async {
      final saved = await secrets.save(_secret('api key', 'hunter2'));

      var record = sink.records.single;
      expect(record.target, 'FixtureSecretRecord');
      expect(record.after['label'], 'api key');
      // The field is shown as changed; the value is not in the trail at all.
      expect(record.after['secret'], tomAuditRedactedPlaceholder);
      expect(record.after.values, isNot(contains('hunter2')));

      sink.clear();
      saved.secret = 'hunter3';
      await secrets.save(saved);

      record = sink.records.single;
      expect(record.action, TomAuditAction.update);
      // "changed, and you may not see to what" stays distinguishable from
      // "did not change": the key survives on both sides of the diff.
      expect(record.before, {'secret': tomAuditRedactedPlaceholder});
      expect(record.after, {'secret': tomAuditRedactedPlaceholder});
    });

    test('with no sink installed the repository still works', () async {
      TomAuditTrail.uninstall();
      final saved = await repo.save(_task('unaudited', 1));
      expect(saved.id, isNotNull);
      await repo.delete(saved);
      expect(await repo.findById(saved.id!), isNull);
    });

    test(
      'runUnaudited suppresses the chokepoint for the trail itself',
      () async {
        await TomAuditTrail.runUnaudited(() => repo.save(_task('internal', 1)));
        expect(sink.records, isEmpty);
      },
    );

    test('the written entries form a verifiable chain', () async {
      final a = await repo.save(_task('a', 1));
      a.priority = 9;
      await repo.save(a);
      await repo.delete(a);

      expect(sink.records.map((r) => r.action), [
        TomAuditAction.create,
        TomAuditAction.update,
        TomAuditAction.delete,
      ]);
      expect(sink.verify().isValid, isTrue);
    });
  }, skip: skipReason);
}
