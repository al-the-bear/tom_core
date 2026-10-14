/// DB-backed tests for the relational audit sink.
///
/// The schema, the DDL/migration drift check and the write-once *reporting*
/// are asserted connection-free in `audit_sql_test.dart`. Everything here is a
/// claim about behaviour that only a real server can substantiate: that the
/// sink appends, that it continues its chain across a reopen, that concurrent
/// writes do not fork it, that retention removes a prefix and nothing else,
/// that verification notices an edit, and — the claim the whole design rests on
/// — that a credential holding only `INSERT` and `SELECT` is what makes the
/// table write-once.
///
/// That last group provisions a restricted MariaDB user and connects a second
/// data source as it. Documenting the grant would have been cheaper; proving it
/// is the point, because the documentation is exactly the part a deployment can
/// get wrong.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A record with a controlled id and instant, so a test can assert on order and
/// on which side of a retention cutoff an entry falls.
TomAuditRecord _record(int index, {DateTime? at, String target = 'Invoice'}) =>
    TomAuditRecord(
      id: 'entry-$index',
      timestamp: at ?? DateTime.utc(2026, 3, 1, 12, 0, index),
      actor: const TomAuditActor(username: 'ada', userId: '42'),
      action: TomAuditAction.update,
      target: target,
      targetKey: '$index',
      outcome: TomAuditOutcome.succeeded,
      after: {'amount': index},
    );

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('the relational audit sink', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() => TestDatabase.dropAuditTrailTable(dsi));

    tearDownAll(TestDatabase.reset);

    TomSqlAuditSink sinkFor(String writer, {bool requireWriteOnce = false}) =>
        TomSqlAuditSink(
          dsi.datasource,
          writer: writer,
          requireWriteOnce: requireWriteOnce,
        );

    group('appending', () {
      test(
        'an entry becomes a row, and the row reads back as the entry',
        () async {
          final sink = sinkFor('node-a');
          final written = await sink.write(_record(1));

          final read = await sink.readAll();
          expect(read, hasLength(1));
          // The stored record is the one that was hashed, not a re-encoding of
          // it: a round-trip that lost a field would leave a row that cannot
          // verify against its own hash.
          expect(read.single.hash, written.hash);
          expect(read.single.previousHash, tomAuditGenesisHash);
          expect(read.single.record.id, 'entry-1');
          expect(read.single.record.target, 'Invoice');
          expect(read.single.record.after['amount'], 1);
          expect(read.single.isSelfConsistent, isTrue);
          await sink.close();
        },
      );

      test('entries chain in insertion order', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 5; i++) {
          await sink.write(_record(i));
        }

        final read = await sink.readAll();
        expect(read.map((e) => e.record.id), [
          'entry-1',
          'entry-2',
          'entry-3',
          'entry-4',
          'entry-5',
        ]);
        expect((await sink.verify()).isValid, isTrue);
        expect(sink.headHash, read.last.hash);
        await sink.close();
      });

      test('the table creates itself on first use', () async {
        // The table was dropped in setUp, so this write has nowhere to go
        // unless `createSchema` did its job.
        final sink = sinkFor('node-a');
        await sink.write(_record(1));
        expect(await sink.readAll(), hasLength(1));
        await sink.close();
      });

      test('a closed sink refuses further records', () async {
        final sink = sinkFor('node-a');
        await sink.write(_record(1));
        await sink.close();
        expect(
          () => sink.write(_record(2)),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.sink.closed',
            ),
          ),
        );
      });

      test('close stores what was queued before it', () async {
        final sink = sinkFor('node-a');
        final first = sink.write(_record(1));
        final queued = sink.write(_record(2));

        await sink.close();

        // Stored by the time the close completes, not merely at some point
        // after it: the close drains the queue before it returns.
        expect(sink.entryCount, 2);
        await expectLater(first, completes);
        await expectLater(queued, completes);
        expect((await sink.readAll()).map((e) => e.record.id), [
          'entry-1',
          'entry-2',
        ]);
        expect((await sink.verify()).isValid, isTrue);
      });

      test('a write during the close is refused', () async {
        final sink = sinkFor('node-a');
        final queued = sink.write(_record(1));
        final closing = sink.close();
        await expectLater(
          sink.write(_record(2)),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.sink.closed',
            ),
          ),
        );
        await closing;
        await expectLater(queued, completes);

        // The refusal is only half the claim; the table is the other half.
        final reader = sinkFor('node-a');
        expect((await reader.readAll()).map((e) => e.record.id), ['entry-1']);
        await reader.close();
      });

      test('a refused record does not provision the schema', () async {
        // Never opened: the table was dropped in setUp and this sink has not
        // written yet, so the refused record would be the one to create it.
        final sink = sinkFor('node-a');
        final closing = sink.close();
        await expectLater(
          sink.write(_record(1)),
          throwsA(isA<TomAuditException>()),
        );
        await closing;

        // Refusing has to be free of side effects: a closed sink creating a
        // table, probing the deployment and recovering a chain head for an
        // entry it had already decided not to store.
        expect(sink.writeOnceCheck, isNull);
      });

      test('a close during open() waits for the queued row', () async {
        final sink = sinkFor('node-a');
        final queued = sink.write(_record(1));
        // `open()` is a real round trip — provisioning, probing and head
        // recovery — and the queued record is suspended inside it. The close
        // lands in that window and still waits for the row.
        final closed = Completer<void>();
        scheduleMicrotask(() => closed.complete(sink.close()));
        await expectLater(queued, completes);
        await closed.future;

        final reader = sinkFor('node-a');
        expect((await reader.readAll()).map((e) => e.record.id), ['entry-1']);
        await reader.close();
      });

      test('close leaves the sink closed', () async {
        final sink = sinkFor('node-a');
        await sink.close();
        expect(
          () => sink.write(_record(1)),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.sink.closed',
            ),
          ),
        );
      });

      test('every close is handed the same close', () async {
        final sink = sinkFor('node-a');
        final queued = sink.write(_record(1));
        // Shutdown may close a sink twice — the registered TomClosable and the
        // application's own teardown. Both wait for the one drain.
        final first = sink.close();
        final second = sink.close();

        expect(identical(first, second), isTrue);
        await second;
        await expectLater(queued, completes);
        final reader = sinkFor('node-a');
        expect((await reader.readAll()).map((e) => e.record.id), ['entry-1']);
        await reader.close();
      });
    });

    group('reopening', () {
      test(
        'a new sink continues the chain rather than starting a second one',
        () async {
          final first = sinkFor('node-a');
          await first.write(_record(1));
          final last = await first.write(_record(2));
          await first.close();

          final second = sinkFor('node-a');
          await second.open();
          // Recovered, not reset: a fresh chain would present every pre-restart
          // entry as unverifiable, which is indistinguishable from tampering.
          expect(second.headHash, last.hash);

          final continued = await second.write(_record(3));
          expect(continued.previousHash, last.hash);

          final verification = await second.verify();
          expect(verification.isValid, isTrue);
          expect(verification.entryCount, 3);
          await second.close();
        },
      );

      test('an empty table opens at the genesis hash', () async {
        final sink = sinkFor('node-a');
        await sink.open();
        expect(sink.headHash, tomAuditGenesisHash);
        expect((await sink.verify()).entryCount, 0);
        await sink.close();
      });

      test('a failed open is retried rather than remembered', () async {
        // A database blip during start-up must not wedge the trail for the life
        // of the process, so the open memo is cleared on failure.
        final sink = TomSqlAuditSink(
          dsi.datasource,
          writer: 'node-a',
          createSchema: false,
        );
        await expectLater(sink.open(), throwsA(isA<Object>()));

        await dsi.datasource.executeCommand(
          auditTrailTableDdl(defaultAuditTrailTable),
        );

        await sink.open();
        await sink.write(_record(1));
        expect(await sink.readAll(), hasLength(1));
        await sink.close();
      });
    });

    group('concurrency', () {
      test('writes issued together still form one chain', () async {
        final sink = sinkFor('node-a');
        // No `await` between them: every write is in flight before the first
        // insert returns, which is exactly the race the write queue exists for.
        final written = await Future.wait([
          for (var i = 1; i <= 20; i++) sink.write(_record(i)),
        ]);

        expect(written, hasLength(20));
        final read = await sink.readAll();
        expect(read, hasLength(20));
        // Submission order is the stored order — the queue is FIFO, so the
        // chain a reader walks is the order the calls were made in.
        expect(read.map((e) => e.record.id), [
          for (var i = 1; i <= 20; i++) 'entry-$i',
        ]);
        expect((await sink.verify()).isValid, isTrue);
        await sink.close();
      });

      test('two sinks on one chain cannot fork it', () async {
        // Both open on an empty table, so both believe the head is genesis.
        final a = sinkFor('node-a');
        final b = sinkFor('node-a');
        await a.open();
        await b.open();

        await a.write(_record(1));

        // `b` would now write a second entry claiming genesis as its
        // predecessor. The unique key on (writer, previous_hash) makes that a
        // duplicate-key error at insert time instead of a fork discovered at
        // the next verification.
        await expectLater(
          b.write(_record(2)),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.sink.write_failed',
            ),
          ),
        );
        expect((await a.verify()).isValid, isTrue);
        await a.close();
        await b.close();
      });

      test('a failed write does not wedge the sink', () async {
        final a = sinkFor('node-a');
        final b = sinkFor('node-a');
        await a.open();
        await b.open();
        await a.write(_record(1));
        await expectLater(
          b.write(_record(2)),
          throwsA(isA<TomAuditException>()),
        );

        // `b`'s queue survived the failure; it is still wrong about the head,
        // so it recovers only after a reopen — but the sink itself accepts work
        // again rather than being permanently poisoned.
        await expectLater(
          b.write(_record(3)),
          throwsA(isA<TomAuditException>()),
        );
        await a.write(_record(4));
        expect((await a.verify()).isValid, isTrue);
        await a.close();
        await b.close();
      });
    });

    group('writer scoping', () {
      test('two writers share a table without sharing a chain', () async {
        final a = sinkFor('node-a');
        final b = sinkFor('node-b');
        await a.write(_record(1));
        await b.write(_record(2));
        await a.write(_record(3));
        await b.write(_record(4));

        expect((await a.readAll()).map((e) => e.record.id), [
          'entry-1',
          'entry-3',
        ]);
        expect((await b.readAll()).map((e) => e.record.id), [
          'entry-2',
          'entry-4',
        ]);
        // Interleaved rows, two independent chains, both verifiable — which is
        // the whole reason `writer` is a required argument.
        expect((await a.verify()).isValid, isTrue);
        expect((await b.verify()).isValid, isTrue);
        await a.close();
        await b.close();
      });
    });

    group('querying pushes the filter into the table', () {
      /// A record whose actor and target are given, so a query has something
      /// to narrow on other than the shared defaults above.
      TomAuditRecord about({
        required int index,
        required String actor,
        String target = 'Invoice',
        TomAuditAction action = TomAuditAction.update,
        TomAuditOutcome outcome = TomAuditOutcome.succeeded,
        DateTime? at,
      }) => TomAuditRecord(
        id: 'entry-$index',
        timestamp: at ?? DateTime.utc(2026, 3, 1, 12, 0, index),
        actor: TomAuditActor(username: actor),
        action: action,
        target: target,
        targetKey: '$index',
        outcome: outcome,
      );

      test('an actor query answers with that actor and nobody else', () async {
        final sink = sinkFor('node-a');
        await sink.write(about(index: 1, actor: 'ada'));
        await sink.write(about(index: 2, actor: 'grace'));
        await sink.write(about(index: 3, actor: 'ada'));

        final result = await sink.query(const TomAuditQuery(actor: 'ada'));

        // Newest first by default, which is the order an auditor reads in.
        expect(result.entries.map((e) => e.record.id), ['entry-3', 'entry-1']);
        expect(result.examined, 2);
        expect(result.rejectedByProjection, isZero);
        expect(result.hasMore, isFalse);
        await sink.close();
      });

      test('an actor too long for its column is still found', () async {
        // The defect the whole design exists to prevent. `actor` is
        // VARCHAR(160) and the writer trims to fit, so a query comparing the
        // full 200-character username against the stored value would match no
        // row and report it as "this actor did nothing" — a false negative, in
        // the one kind of query where a silent omission is the worst outcome.
        final long = '${'u' * 199}1';
        final sink = sinkFor('node-a');
        await sink.write(about(index: 1, actor: long));

        final result = await sink.query(TomAuditQuery(actor: long));

        expect(result.entries, hasLength(1));
        expect(
          result.entries.single.record.actor.username,
          long,
          reason:
              'the record is authoritative and is never truncated, so what '
              'comes back is the full name even though the column holds 160 '
              'characters of it',
        );
        await sink.close();
      });

      test(
        'two actors sharing a prefix are told apart by the record',
        () async {
          // The other half: the cut that avoids the false negative admits rows
          // that merely share the first 160 characters. Those are the index's
          // false positives, and the record decides against them.
          final shared = 'u' * 160;
          final sink = sinkFor('node-a');
          await sink.write(about(index: 1, actor: '${shared}alice'));
          await sink.write(about(index: 2, actor: '${shared}bob'));

          final result = await sink.query(
            TomAuditQuery(actor: '${shared}alice'),
          );

          expect(result.entries.map((e) => e.record.id), ['entry-1']);
          expect(
            result.examined,
            2,
            reason: 'both rows matched the truncated column',
          );
          expect(
            result.rejectedByProjection,
            1,
            reason:
                'the lossy index is counted rather than hidden — an operator '
                'who sees this number knows the projection is doing its job',
          );
          await sink.close();
        },
      );

      test(
        'a time window takes its lower bound and leaves its upper',
        () async {
          final sink = sinkFor('node-a');
          for (var i = 1; i <= 4; i++) {
            await sink.write(
              about(
                index: i,
                actor: 'ada',
                at: DateTime.utc(2026, 3, 1, 12, 0, i),
              ),
            );
          }

          final result = await sink.query(
            TomAuditQuery(
              from: DateTime.utc(2026, 3, 1, 12, 0, 2),
              to: DateTime.utc(2026, 3, 1, 12, 0, 4),
              newestFirst: false,
            ),
          );

          expect(result.entries.map((e) => e.record.id), [
            'entry-2',
            'entry-3',
          ]);
          await sink.close();
        },
      );

      test('the fields combine as an and', () async {
        final sink = sinkFor('node-a');
        await sink.write(
          about(index: 1, actor: 'ada', action: TomAuditAction.delete),
        );
        await sink.write(
          about(index: 2, actor: 'ada', action: TomAuditAction.update),
        );
        await sink.write(
          about(index: 3, actor: 'grace', action: TomAuditAction.delete),
        );

        final result = await sink.query(
          const TomAuditQuery(actor: 'ada', action: TomAuditAction.delete),
        );

        expect(result.entries.map((e) => e.record.id), ['entry-1']);
        await sink.close();
      });

      test('a denied outcome is findable on its own', () async {
        // "What was refused" is one of the four questions the trail exists to
        // answer, and the only one whose rows are the interesting minority.
        final sink = sinkFor('node-a');
        await sink.write(about(index: 1, actor: 'ada'));
        await sink.write(
          about(index: 2, actor: 'ada', outcome: TomAuditOutcome.denied),
        );

        final result = await sink.query(
          const TomAuditQuery(outcome: TomAuditOutcome.denied),
        );

        expect(result.entries.map((e) => e.record.id), ['entry-2']);
        await sink.close();
      });

      test(
        'the limit bounds the answer and the result says there is more',
        () async {
          final sink = sinkFor('node-a');
          for (var i = 1; i <= 5; i++) {
            await sink.write(about(index: i, actor: 'ada'));
          }

          final result = await sink.query(const TomAuditQuery(limit: 2));

          expect(result.entries.map((e) => e.record.id), [
            'entry-5',
            'entry-4',
          ]);
          expect(result.hasMore, isTrue);
          expect(
            result.examined,
            2,
            reason:
                'the row beyond the limit is read to learn that it exists and '
                'is not judged, so it does not appear in the count of what was',
          );
          await sink.close();
        },
      );

      test('the last page does not claim there is more', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 3; i++) {
          await sink.write(about(index: i, actor: 'ada'));
        }

        final result = await sink.query(const TomAuditQuery(limit: 3));

        expect(result.entries, hasLength(3));
        expect(result.hasMore, isFalse);
        await sink.close();
      });

      test('a query answers for its own writer only', () async {
        // Same scoping as readAll and both purges: a sink is one chain's
        // handle on a shared table.
        final a = sinkFor('node-a');
        final b = sinkFor('node-b');
        await a.write(about(index: 1, actor: 'ada'));
        await b.write(about(index: 2, actor: 'ada'));

        expect(
          (await a.query(
            const TomAuditQuery(actor: 'ada'),
          )).entries.map((e) => e.record.id),
          ['entry-1'],
        );
        expect(
          (await b.query(
            const TomAuditQuery(actor: 'ada'),
          )).entries.map((e) => e.record.id),
          ['entry-2'],
        );
        await a.close();
        await b.close();
      });

      test('a question nothing answers is an empty result', () async {
        final sink = sinkFor('node-a');
        await sink.write(about(index: 1, actor: 'ada'));

        final result = await sink.query(
          const TomAuditQuery(actor: 'nobody-here'),
        );

        expect(result.entries, isEmpty);
        expect(result.hasMore, isFalse);
        await sink.close();
      });
    });

    group('retention removes a prefix and nothing else', () {
      test('purgeToMaxEntries keeps the newest entries', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 10; i++) {
          await sink.write(_record(i));
        }

        expect(await sink.purgeToMaxEntries(3), 7);
        final read = await sink.readAll();
        expect(read.map((e) => e.record.id), [
          'entry-8',
          'entry-9',
          'entry-10',
        ]);
        // The retained rows are a suffix, so they still verify — against their
        // own oldest link rather than against genesis.
        expect((await sink.verify()).isValid, isTrue);
        await sink.close();
      });

      test(
        'purgeToMaxEntries is a no-op when the chain is already short',
        () async {
          final sink = sinkFor('node-a');
          await sink.write(_record(1));
          expect(await sink.purgeToMaxEntries(5), 0);
          expect(await sink.readAll(), hasLength(1));
          await sink.close();
        },
      );

      test('purgeToMaxEntries(0) empties the chain', () async {
        final sink = sinkFor('node-a');
        await sink.write(_record(1));
        await sink.write(_record(2));
        expect(await sink.purgeToMaxEntries(0), 2);
        expect(await sink.readAll(), isEmpty);
        await sink.close();
      });

      test('a negative limit is refused rather than interpreted', () async {
        final sink = sinkFor('node-a');
        await expectLater(
          sink.purgeToMaxEntries(-1),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.retention.negative_limit',
            ),
          ),
        );
        await sink.close();
      });

      test(
        'purgeBefore trims by the sequence boundary the cutoff resolves to',
        () async {
          final sink = sinkFor('node-a');
          final base = DateTime.utc(2026, 3, 1, 12);
          for (var i = 0; i < 5; i++) {
            await sink.write(_record(i, at: base.add(Duration(hours: i))));
          }

          expect(await sink.purgeBefore(base.add(const Duration(hours: 2))), 2);
          final read = await sink.readAll();
          expect(read.map((e) => e.record.id), [
            'entry-2',
            'entry-3',
            'entry-4',
          ]);
          expect((await sink.verify()).isValid, isTrue);
          await sink.close();
        },
      );

      test('a cutoff after every entry removes the whole chain', () async {
        final sink = sinkFor('node-a');
        final base = DateTime.utc(2026, 3, 1, 12);
        await sink.write(_record(1, at: base));
        await sink.write(_record(2, at: base.add(const Duration(hours: 1))));

        expect(await sink.purgeBefore(base.add(const Duration(days: 1))), 2);
        expect(await sink.readAll(), isEmpty);
        await sink.close();
      });

      test('a cutoff before every entry removes nothing', () async {
        final sink = sinkFor('node-a');
        final base = DateTime.utc(2026, 3, 1, 12);
        await sink.write(_record(1, at: base));
        expect(
          await sink.purgeBefore(base.subtract(const Duration(days: 1))),
          0,
        );
        expect(await sink.readAll(), hasLength(1));
        await sink.close();
      });

      test('retention leaves the chain able to continue', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 4; i++) {
          await sink.write(_record(i));
        }
        await sink.purgeToMaxEntries(2);

        // The head lives in memory, not in the trimmed table, so a purge does
        // not break the link the next entry attaches to.
        await sink.write(_record(5));
        final read = await sink.readAll();
        expect(read.map((e) => e.record.id), ['entry-3', 'entry-4', 'entry-5']);
        expect((await sink.verify()).isValid, isTrue);
        await sink.close();
      });
    });

    group('verification notices what the chain exists to notice', () {
      test('an edited record no longer matches its own hash', () async {
        final sink = sinkFor('node-a');
        await sink.write(_record(1));
        await sink.write(_record(2, target: 'Invoice'));
        await sink.write(_record(3));

        // The row's stored text is what was hashed, so changing it — exactly
        // what an attacker with UPDATE would do — cannot go unnoticed.
        await dsi.datasource.executeCommand(
          'UPDATE $defaultAuditTrailTable '
          "SET record = REPLACE(record, '\"target\":\"Invoice\"', "
          "'\"target\":\"Receipt\"') "
          'WHERE entry_id = :id',
          {'id': 'entry-2'},
        );

        final verification = await sink.verify();
        expect(verification.isValid, isFalse);
        expect(verification.brokenAtIndex, 1);
        expect(verification.detail, contains('content changed'));
        await sink.close();
      });

      test('a removed interior row breaks the link, not the content', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 3; i++) {
          await sink.write(_record(i));
        }

        await dsi.datasource.executeCommand(
          'DELETE FROM $defaultAuditTrailTable WHERE entry_id = :id',
          {'id': 'entry-2'},
        );

        final verification = await sink.verify();
        expect(verification.isValid, isFalse);
        // The surviving entries are individually intact; what is gone is the
        // link between them — which is why the two failures are reported
        // differently.
        expect(verification.brokenAtIndex, 1);
        expect(verification.detail, contains('link mismatch'));
        await sink.close();
      });

      test('an unreadable record is a finding, not a skipped row', () async {
        final sink = sinkFor('node-a');
        await sink.write(_record(1));
        await dsi.datasource.executeCommand(
          'UPDATE $defaultAuditTrailTable SET record = :junk',
          {'junk': 'not json at all'},
        );

        await expectLater(
          sink.readAll(),
          throwsA(
            isA<TomAuditException>().having(
              (e) => e.key,
              'key',
              'audit.sql.malformed_record',
            ),
          ),
        );
        await sink.close();
      });
    });

    group('an anchor catches what the chain cannot', () {
      test('a wholesale rewrite still verifies but fails its anchor', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 4; i++) {
          await sink.write(_record(i));
        }
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
        );
        final anchor = await publisher.publishNow();
        expect(anchor.entryCount, 4);

        // The attacker holds UPDATE. They edit entry-2 and — unlike the test in
        // the group above — do the work properly, recomputing every hash from
        // there on. Re-chaining is done in Dart because that is precisely what
        // an attacker with the algorithm would do.
        final original = await sink.readAll();
        var previous = original.first.previousHash;
        for (final entry in original) {
          final record = entry.record.id == 'entry-2'
              ? _record(2, target: 'Receipt')
              : entry.record;
          final forged = TomAuditEntry.chain(
            record,
            previous,
            index: entry.index,
          );
          await dsi.datasource.executeCommand(
            'UPDATE $defaultAuditTrailTable SET record = :record, '
            'previous_hash = :previousHash, hash = :hash '
            'WHERE writer = :writer AND entry_index = :index',
            {
              'record': jsonEncode(forged.record.toJson()),
              'previousHash': forged.previousHash,
              'hash': forged.hash,
              'writer': 'node-a',
              'index': forged.index,
            },
          );
          previous = forged.hash;
        }

        // The trail is internally perfect — this is the whole problem.
        expect((await sink.verify()).isValid, isTrue);

        final result = verifyAgainstAnchor(
          await sink.readAll(),
          anchor,
          writer: 'node-a',
        );
        expect(result.status, TomAuditAnchorStatus.diverged);
        expect(result.indicatesTampering, isTrue);
        publisher.stop();
        await sink.close();
      });

      test('deleting the newest rows reads as a truncation', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 5; i++) {
          await sink.write(_record(i));
        }
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
        );
        await publisher.publishNow();

        // Lopping entries off the end leaves a chain that verifies. Only the
        // anchor's count sees it.
        await dsi.datasource.executeCommand(
          'DELETE FROM $defaultAuditTrailTable WHERE entry_index >= :from',
          {'from': 3},
        );
        expect((await sink.verify()).isValid, isTrue);

        final result = verifyAgainstAnchor(
          await sink.readAll(),
          (await store.latest('node-a'))!,
          writer: 'node-a',
        );
        expect(result.status, TomAuditAnchorStatus.truncated);
        publisher.stop();
        await sink.close();
      });

      test('retention leaves a suffix that still matches the anchor', () async {
        final sink = sinkFor('node-a');
        for (var i = 1; i <= 8; i++) {
          await sink.write(_record(i));
        }
        final store = TomMemoryAuditAnchorStore();
        final publisher = TomAuditAnchorPublisher(
          sink: sink,
          store: store,
          writer: 'node-a',
        );
        await publisher.publishNow();

        expect(await sink.purgeToMaxEntries(3), 5);

        // The stored index is what makes this work: the surviving rows still
        // know they are entries 5..7, so the anchored position is inside the
        // retained window and reads clean instead of as a rewrite.
        final result = verifyAgainstAnchor(
          await sink.readAll(),
          (await store.latest('node-a'))!,
          writer: 'node-a',
        );
        expect(result.status, TomAuditAnchorStatus.matched);
        expect(result.indicatesTampering, isFalse);
        publisher.stop();
        await sink.close();
      });

      test(
        'a reopened sink continues the count, so anchors keep lining up',
        () async {
          final first = sinkFor('node-a');
          for (var i = 1; i <= 3; i++) {
            await first.write(_record(i));
          }
          await first.close();

          final second = sinkFor('node-a');
          await second.write(_record(4));
          expect(second.entryCount, 4);

          final anchor = TomAuditAnchor.of(second, writer: 'node-a');
          final result = verifyAgainstAnchor(
            await second.readAll(),
            anchor,
            writer: 'node-a',
          );
          expect(result.status, TomAuditAnchorStatus.matched);
          await second.close();
        },
      );
    });

    group('the write-once probe reports the deployment it is in', () {
      test(
        'a fully privileged connection is reported as not write-once',
        () async {
          final sink = sinkFor('node-a');
          await sink.open();

          final check = sink.writeOnceCheck!;
          expect(check.grantsUpdate, isTrue);
          expect(check.grantsDelete, isTrue);
          expect(check.isAppendOnly, isFalse);
          expect(check.summary, contains('UPDATE PERMITTED'));
          await sink.close();
        },
      );

      test(
        'requireWriteOnce refuses to start against a mutable table',
        () async {
          final sink = sinkFor('node-a', requireWriteOnce: true);
          await expectLater(
            sink.open(),
            throwsA(
              isA<TomAuditException>().having(
                (e) => e.key,
                'key',
                'audit.sql.not_write_once',
              ),
            ),
          );
          await sink.close();
        },
      );

      test(
        'a guard trigger is seen even though it blocks no probe statement',
        () async {
          // The probe's UPDATE matches no rows and so fires no FOR EACH ROW
          // trigger. Without the information_schema read, a trigger-protected
          // table would be reported as perfectly mutable.
          final sink = sinkFor('node-a');
          await sink.open();
          await dsi.datasource.executeCommand(
            auditTrailNoUpdateTriggerDdl(defaultAuditTrailTable),
          );

          final check = await sink.verifyWriteOnce();
          expect(check.grantsUpdate, isTrue);
          expect(
            check.updateGuardTrigger,
            auditTrailNoUpdateTriggerName(defaultAuditTrailTable),
          );
          expect(check.updatesBlocked, isTrue);
          expect(check.isAppendOnly, isFalse, reason: 'DELETE is still open');
          await sink.close();
        },
      );

      test('both guards installed make the table append-only', () async {
        final sink = sinkFor('node-a');
        await sink.open();
        await dsi.datasource.executeCommand(
          auditTrailNoUpdateTriggerDdl(defaultAuditTrailTable),
        );
        await dsi.datasource.executeCommand(
          auditTrailNoDeleteTriggerDdl(defaultAuditTrailTable),
        );

        expect((await sink.verifyWriteOnce()).isAppendOnly, isTrue);
        await sink.close();
      });

      test(
        'the guards reject the statements they guard, and let inserts pass',
        () async {
          final sink = sinkFor('node-a');
          await sink.write(_record(1));
          await dsi.datasource.executeCommand(
            auditTrailNoUpdateTriggerDdl(defaultAuditTrailTable),
          );
          await dsi.datasource.executeCommand(
            auditTrailNoDeleteTriggerDdl(defaultAuditTrailTable),
          );

          // A SIGNAL, not a silent no-op: an attacker's UPDATE fails loudly.
          await expectLater(
            dsi.datasource.executeCommand(
              'UPDATE $defaultAuditTrailTable SET actor = :actor',
              {'actor': 'mallory'},
            ),
            throwsA(isA<Object>()),
          );
          await expectLater(
            dsi.datasource.executeCommand(
              'DELETE FROM $defaultAuditTrailTable',
            ),
            throwsA(isA<Object>()),
          );

          // Appending is untouched, which is the point of guarding only the two
          // destructive statements.
          await sink.write(_record(2));
          expect(await sink.readAll(), hasLength(2));
          await sink.close();
        },
      );
    });

    group('the grant is the guarantee', () {
      const restrictedDatasource = 'tom_core_server_audit_restricted';
      const restrictedUser = 'tom_audit_writer';
      const restrictedPassword = 'audit_writer_password';

      /// Provisions an INSERT+SELECT-only user and registers a data source that
      /// connects as it, or returns `null` when the test credential is not
      /// privileged enough to create one.
      Future<TomDataSource?> restrictedDatasourceOrNull() async {
        final db = TestDatabase.databaseName;
        try {
          await dsi.datasource.executeCommand(
            "DROP USER IF EXISTS '$restrictedUser'@'%'",
          );
          await dsi.datasource.executeCommand(
            "CREATE USER '$restrictedUser'@'%' "
            "IDENTIFIED BY '$restrictedPassword'",
          );
          // The whole write-once story, in one statement: the serving user may
          // add rows and read them back, and has no way to change or remove
          // one.
          await dsi.datasource.executeCommand(
            'GRANT INSERT, SELECT ON $db.$defaultAuditTrailTable '
            "TO '$restrictedUser'@'%'",
          );
        } catch (e) {
          // Only a *privilege* failure means "this deployment cannot show the
          // story"; anything else is a broken test and must surface as one.
          if (!'$e'.toLowerCase().contains('denied')) rethrow;
          return null;
        }
        await TomDataSourceInfo.initializeDatasourceInfo({
          restrictedDatasource: {
            'type': 'mariadb',
            'username': restrictedUser,
            'password': restrictedPassword,
            'host': TestDatabase.host,
            'port': TestDatabase.port,
            'databaseName': db,
          },
        });
        return TomDataSourceInfo.getDataSourceInfo(
          restrictedDatasource,
        )!.datasource;
      }

      tearDown(() async {
        final registered = TomDataSourceInfo.datasources.remove(
          restrictedDatasource,
        );
        await registered?.datasource.close();
        await dsi.datasource.executeCommand(
          "DROP USER IF EXISTS '$restrictedUser'@'%'",
        );
      });

      test('an INSERT+SELECT credential makes the table append-only', () async {
        // The table is owned by the privileged credential; the serving one is
        // deliberately not given DDL rights, which is why `createSchema` is off
        // below.
        await dsi.datasource.executeCommand(
          auditTrailTableDdl(defaultAuditTrailTable),
        );

        final restricted = await restrictedDatasourceOrNull();
        if (restricted == null) {
          markTestSkipped(
            'The test credential cannot CREATE USER, so the restricted-grant '
            'story cannot be exercised here.',
          );
          return;
        }

        final sink = TomSqlAuditSink(
          restricted,
          writer: 'node-a',
          createSchema: false,
          // The deployment made the arrangement, so a silently mis-granted
          // credential must be a start-up failure rather than a warning.
          requireWriteOnce: true,
        );
        await sink.open();

        final check = sink.writeOnceCheck!;
        expect(check.grantsUpdate, isFalse);
        expect(check.grantsDelete, isFalse);
        expect(check.isAppendOnly, isTrue);
        expect(check.summary, contains('UPDATE not granted'));

        // Appending — the one thing the sink actually needs — still works.
        await sink.write(_record(1));
        await sink.write(_record(2));
        expect(await sink.readAll(), hasLength(2));
        expect((await sink.verify()).isValid, isTrue);
        await sink.close();
      });

      test(
        'the restricted credential cannot rewrite or remove an entry',
        () async {
          await dsi.datasource.executeCommand(
            auditTrailTableDdl(defaultAuditTrailTable),
          );

          final restricted = await restrictedDatasourceOrNull();
          if (restricted == null) {
            markTestSkipped(
              'The test credential cannot CREATE USER, so the restricted-grant '
              'story cannot be exercised here.',
            );
            return;
          }

          final sink = TomSqlAuditSink(
            restricted,
            writer: 'node-a',
            createSchema: false,
          );
          await sink.write(_record(1));

          // Not "the code refuses" — the *server* refuses, to a connection that
          // has no other option. This is the guarantee the code cannot provide.
          await expectLater(
            restricted.executeCommand(
              'UPDATE $defaultAuditTrailTable SET actor = :actor',
              {'actor': 'mallory'},
            ),
            throwsA(isA<Object>()),
          );
          await expectLater(
            restricted.executeCommand('DELETE FROM $defaultAuditTrailTable'),
            throwsA(isA<Object>()),
          );

          expect(await sink.readAll(), hasLength(1));
          expect((await sink.readAll()).single.record.actor.username, 'ada');
          await sink.close();
        },
      );

      test(
        'retention needs a credential the serving one does not have',
        () async {
          await dsi.datasource.executeCommand(
            auditTrailTableDdl(defaultAuditTrailTable),
          );

          final restricted = await restrictedDatasourceOrNull();
          if (restricted == null) {
            markTestSkipped(
              'The test credential cannot CREATE USER, so the restricted-grant '
              'story cannot be exercised here.',
            );
            return;
          }

          final serving = TomSqlAuditSink(
            restricted,
            writer: 'node-a',
            createSchema: false,
          );
          for (var i = 1; i <= 4; i++) {
            await serving.write(_record(i));
          }

          // The consequence the documentation has to state plainly: pruning is an
          // operator action, performed with a different credential, and a
          // deployment that forgets this discovers it when retention fails.
          await expectLater(
            serving.purgeToMaxEntries(2),
            throwsA(isA<Object>()),
          );

          final operator = sinkFor('node-a');
          expect(await operator.purgeToMaxEntries(2), 2);
          expect((await operator.verify()).isValid, isTrue);
          await serving.close();
          await operator.close();
        },
      );
    });
  }, skip: skipReason);
}
