import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the transactions module: the [TomTransaction] lifecycle, the
/// commit/rollback drive (including the commit-veto path and participant
/// deduplication), and the ambient [TomTransactionManager] accessors — both in
/// the process-wide fallback scope and inside an explicit
/// [TomTransactionManager.runInTransactionScope]. The module is self-contained
/// (no reflection, no database), so the whole surface is exercised here with a
/// recording fake participant.

/// A participant that records the lifecycle calls made on it.
///
/// [vetoCommit] makes `commit()` return `false` (vetoing the transaction).
/// [endResult] is the value returned by `endTransaction()` — set it `false` to
/// exercise the "an end call failed" branch of the commit/rollback drive. When
/// a [sharedLog] is supplied, every call is also appended to it as `id:call`,
/// so a test spanning several participants can assert cross-participant
/// ordering.
class _RecordingParticipant extends TomTransactionParticipant {
  _RecordingParticipant(
    this.id, {
    this.vetoCommit = false,
    this.endResult = true,
    this.sharedLog,
  });

  final String id;
  final bool vetoCommit;
  final bool endResult;
  final List<String>? sharedLog;
  final List<String> calls = [];

  void _record(String call) {
    calls.add(call);
    sharedLog?.add('$id:$call');
  }

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction() async {
    _record('start');
    return true;
  }

  @override
  Future<bool> commit() async {
    _record('commit');
    return !vetoCommit;
  }

  @override
  Future<void> rollback() async {
    _record('rollback');
  }

  @override
  Future<bool> endTransaction() async {
    _record('end');
    return endResult;
  }
}

/// A participant that enlists itself the way a data source does — through the
/// *ambient* current transaction rather than a handle it was given.
///
/// This is the shape that makes zone scoping load-bearing: the caller never
/// names a transaction, so which one it joins is decided entirely by the scope
/// it runs in. Returns whether it found a transaction to join.
Future<bool> enlistAmbiently(TomTransactionParticipant participant) async {
  final transaction = TomTransactionManager.getCurrentTransaction();
  if (transaction == null) return false;
  await transaction.registerParticipant(participant);
  return true;
}

void main() {
  // Tests outside an explicit scope share the process-wide fallback scope;
  // ensure each starts and ends with no active transaction.
  tearDown(() async {
    await TomTransactionManager.getCurrentTransaction()?.rollbackTransaction();
  });

  group('TomTransactionManager', () {
    test('first startTransaction creates a new transaction', () {
      final (txn, isNew) = TomTransactionManager.startTransaction();
      expect(isNew, isTrue);
      expect(
        identical(TomTransactionManager.getCurrentTransaction(), txn),
        isTrue,
      );
      expect(TomTransactionManager.transactional, isTrue);
    });

    test('a second startTransaction returns the existing one', () {
      final (txn, _) = TomTransactionManager.startTransaction();
      final (txn2, isNew2) = TomTransactionManager.startTransaction();
      expect(isNew2, isFalse);
      expect(identical(txn, txn2), isTrue);
    });

    test('isReadOnly is honoured for a newly created transaction', () {
      final (txn, _) = TomTransactionManager.startTransaction(true);
      expect(txn.isReadOnly, isTrue);
    });

    test('startTransaction defaults to read-write', () {
      final (txn, _) = TomTransactionManager.startTransaction();
      expect(txn.isReadOnly, isFalse);
    });

    test('isReadOnly is ignored when an existing transaction is returned', () {
      final (readWrite, _) = TomTransactionManager.startTransaction();
      // The flag is honoured on creation only, so a nested caller asking for a
      // read-only transaction gets the open one back unchanged. It has to work
      // this way round: a nested request that could flip the flag would
      // retroactively relabel writes the outer caller has already made, and
      // any participant reading `isReadOnly` to decide what it may do would
      // read the answer for somebody else's intent.
      final (joined, isNew) = TomTransactionManager.startTransaction(true);
      expect(isNew, isFalse);
      expect(identical(joined, readWrite), isTrue);
      expect(joined.isReadOnly, isFalse);
    });

    test('transactional is false when no transaction is active', () {
      expect(TomTransactionManager.transactional, isFalse);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('transactional is false once the transaction has concluded', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.commitTransaction();
      // The concluded transaction is cleared, so no transaction is active and
      // transactional reports false even though the handle still exists.
      expect(TomTransactionManager.transactional, isFalse);
      expect(txn.isRunning, isFalse);
    });
  });

  group('commitTransaction', () {
    test(
      'commits then ends every participant and clears the manager',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a');
        await txn.registerParticipant(p);
        final ok = await txn.commitTransaction();
        expect(ok, isTrue);
        expect(p.calls, ['start', 'commit', 'end']);
        expect(txn.isRunning, isFalse);
        expect(TomTransactionManager.getCurrentTransaction(), isNull);
      },
    );

    test('commits then ends all participants in registration order', () async {
      final log = <String>[];
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_RecordingParticipant('a', sharedLog: log));
      await txn.registerParticipant(_RecordingParticipant('b', sharedLog: log));
      final ok = await txn.commitTransaction();
      expect(ok, isTrue);
      // All commits run (in order) before any endTransaction, and both phases
      // follow registration order.
      expect(log, [
        'a:start',
        'b:start',
        'a:commit',
        'b:commit',
        'a:end',
        'b:end',
      ]);
    });

    test('a vetoing participant turns the commit into a rollback', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', vetoCommit: true);
      await txn.registerParticipant(p);
      await txn.commitTransaction();
      expect(p.calls, contains('rollback'));
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test(
      'a later veto also rolls back the participants that already committed',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final committed = _RecordingParticipant('a');
        final vetoer = _RecordingParticipant('b', vetoCommit: true);
        await txn.registerParticipant(committed);
        await txn.registerParticipant(vetoer);
        final ok = await txn.commitTransaction();
        // The veto aborts the commit loop and rolls the whole transaction back,
        // so the participant that already committed successfully is still rolled
        // back and ended.
        expect(ok, isTrue); // rollback's end calls all succeeded
        expect(committed.calls, ['start', 'commit', 'rollback', 'end']);
        expect(vetoer.calls, ['start', 'commit', 'rollback', 'end']);
      },
    );

    test(
      'a failing endTransaction makes a clean commit report false',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a', endResult: false);
        await txn.registerParticipant(p);
        final ok = await txn.commitTransaction();
        // The work committed, but the resource-release step failed, which the
        // return value surfaces.
        expect(ok, isFalse);
        expect(p.calls, ['start', 'commit', 'end']);
        expect(TomTransactionManager.getCurrentTransaction(), isNull);
      },
    );

    test(
      'an end failure does not stop the participants after it being ended',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        // Only the *first* fails, so the two behind it are the ones at risk and
        // the overall result still has to come out false.
        final failing = _RecordingParticipant('a', endResult: false);
        final second = _RecordingParticipant('b');
        final third = _RecordingParticipant('c');
        await txn.registerParticipant(failing);
        await txn.registerParticipant(second);
        await txn.registerParticipant(third);
        final ok = await txn.commitTransaction();
        // `endTransaction()` releases per-transaction resources — for a data
        // source, returning its connection to the pool. Skipping it because
        // somebody *else* reported failure leaks that resource, and the work is
        // already committed, so nothing later comes back to release it.
        expect(failing.calls, ['start', 'commit', 'end']);
        expect(second.calls, ['start', 'commit', 'end']);
        expect(third.calls, ['start', 'commit', 'end']);
        // And the two successes behind it must not erase the failure: the
        // result is the conjunction of every end call, not the last one.
        expect(ok, isFalse);
      },
    );
  });

  group('rollbackTransaction', () {
    test(
      'rolls back then ends every participant and clears the manager',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a');
        await txn.registerParticipant(p);
        final ok = await txn.rollbackTransaction();
        expect(ok, isTrue);
        expect(p.calls, ['start', 'rollback', 'end']);
        expect(txn.isRunning, isFalse);
        expect(TomTransactionManager.getCurrentTransaction(), isNull);
      },
    );

    test(
      'rolls back then ends all participants in registration order',
      () async {
        final log = <String>[];
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(
          _RecordingParticipant('a', sharedLog: log),
        );
        await txn.registerParticipant(
          _RecordingParticipant('b', sharedLog: log),
        );
        final ok = await txn.rollbackTransaction();
        expect(ok, isTrue);
        expect(log, [
          'a:start',
          'b:start',
          'a:rollback',
          'b:rollback',
          'a:end',
          'b:end',
        ]);
      },
    );

    test('a failing endTransaction makes rollback report false', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', endResult: false);
      await txn.registerParticipant(p);
      final ok = await txn.rollbackTransaction();
      expect(ok, isFalse);
      expect(p.calls, ['start', 'rollback', 'end']);
    });

    test(
      'an end failure does not stop the participants after it being ended',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final failing = _RecordingParticipant('a', endResult: false);
        final second = _RecordingParticipant('b');
        final third = _RecordingParticipant('c');
        await txn.registerParticipant(failing);
        await txn.registerParticipant(second);
        await txn.registerParticipant(third);
        final ok = await txn.rollbackTransaction();
        // The rollback path leaks the same way the commit path does, and it is
        // the path a failure arrives on — so a participant whose release is
        // skipped here is being skipped exactly when things are already wrong.
        expect(failing.calls, ['start', 'rollback', 'end']);
        expect(second.calls, ['start', 'rollback', 'end']);
        expect(third.calls, ['start', 'rollback', 'end']);
        expect(ok, isFalse);
      },
    );
  });

  group('registerParticipant', () {
    test('deduplicates participants by id, enlisting only once', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('same');
      await txn.registerParticipant(p);
      await txn.registerParticipant(p);
      // startTransaction() called exactly once despite two registrations.
      expect(p.calls.where((c) => c == 'start').length, 1);
    });

    test('rejects enlistment once the transaction has concluded', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.commitTransaction();
      // registerParticipant returns a Future, so the guard's exception surfaces
      // to the awaiting caller and is directly catchable.
      await expectLater(
        txn.registerParticipant(_RecordingParticipant('late')),
        throwsA(
          isA<TomTransactionException>().having(
            (e) => e.key,
            'key',
            'transaction_manager.register_participant.transaction_not_running',
          ),
        ),
      );
    });

    test('rejects enlistment once the transaction has rolled back', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.rollbackTransaction();
      await expectLater(
        txn.registerParticipant(_RecordingParticipant('late')),
        throwsA(isA<TomTransactionException>()),
      );
    });
  });

  group('runInTransactionScope', () {
    test(
      'two concurrent flows do not observe each other\'s transaction',
      () async {
        // The assertion this whole change exists for. Both flows are started
        // before either finishes, and each yields at a point where the other is
        // guaranteed to have opened its transaction — exactly what two requests
        // interleaving in one isolate do. With a process-wide current
        // transaction the second flow would receive the first one's handle with
        // isNew == false, and whichever concluded first would commit the other's
        // work.
        final aOpened = Completer<void>();
        final bOpened = Completer<void>();

        Future<TomTransaction> flow(
          Completer<void> mine,
          Completer<void> theirs,
          TomTransactionParticipant participant,
        ) => TomTransactionManager.runInTransactionScope(() async {
          final (txn, isNew) = TomTransactionManager.startTransaction();
          expect(isNew, isTrue, reason: 'each flow opens its own transaction');
          await enlistAmbiently(participant);
          mine.complete();
          await theirs.future;
          // After the interleave the flow still sees its own transaction.
          expect(
            identical(TomTransactionManager.getCurrentTransaction(), txn),
            isTrue,
          );
          await txn.commitTransaction();
          return txn;
        });

        final pa = _RecordingParticipant('a');
        final pb = _RecordingParticipant('b');
        final transactions = await Future.wait([
          flow(aOpened, bOpened, pa),
          flow(bOpened, aOpened, pb),
        ]);

        expect(identical(transactions[0], transactions[1]), isFalse);
        // Each participant joined exactly one transaction and was driven by it
        // once — nobody was committed twice or by the wrong flow.
        expect(pa.calls, ['start', 'commit', 'end']);
        expect(pb.calls, ['start', 'commit', 'end']);
      },
    );

    test('a transaction inside a scope is invisible outside it', () async {
      // A flow running outside the scope must find *nothing*, not the
      // transaction that happens to be running next to it.
      final observed = <TomTransaction?>[];
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction();
        observed.add(txn);
        await txn.commitTransaction();
      });
      expect(observed, hasLength(1));
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
      expect(TomTransactionManager.transactional, isFalse);
    });

    test('a transaction outside a scope is invisible inside one', () async {
      final (outer, _) = TomTransactionManager.startTransaction();
      final inner = TomTransactionManager.runInTransactionScope(
        () => TomTransactionManager.getCurrentTransaction(),
      );
      expect(inner, isNull);
      expect(
        identical(TomTransactionManager.getCurrentTransaction(), outer),
        isTrue,
      );
    });

    test('nesting scopes gives the inner one its own transaction', () async {
      await TomTransactionManager.runInTransactionScope(() async {
        final (outer, _) = TomTransactionManager.startTransaction();
        final inner = await TomTransactionManager.runInTransactionScope(
          () async {
            final (txn, isNew) = TomTransactionManager.startTransaction();
            expect(isNew, isTrue);
            await txn.commitTransaction();
            return txn;
          },
        );
        expect(identical(inner, outer), isFalse);
        // Concluding the inner transaction left the outer scope untouched.
        expect(
          identical(TomTransactionManager.getCurrentTransaction(), outer),
          isTrue,
        );
        await outer.rollbackTransaction();
      });
    });

    test('a second startTransaction within one scope still nests', () async {
      // Scoping changes *where* the current transaction lives, not the nesting
      // contract every existing caller relies on.
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, isNew) = TomTransactionManager.startTransaction();
        final (again, isNewAgain) = TomTransactionManager.startTransaction();
        expect(isNew, isTrue);
        expect(isNewAgain, isFalse);
        expect(identical(txn, again), isTrue);
        await txn.rollbackTransaction();
      });
    });

    test('hasTransactionScope reports whether the zone carries one', () {
      expect(TomTransactionManager.hasTransactionScope, isFalse);
      expect(
        TomTransactionManager.runInTransactionScope(
          () => TomTransactionManager.hasTransactionScope,
        ),
        isTrue,
      );
    });

    test('concluding in a different zone clears the opening scope', () async {
      // commitTransaction may well run somewhere other than where the
      // transaction was opened. The transaction carries its scope, so the
      // clear lands on the scope that actually holds it.
      late TomTransaction opened;
      final scopeSawItCleared = Completer<bool>();
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction();
        opened = txn;
        // Conclude from outside the scope entirely.
        await Zone.root.run(() => txn.commitTransaction());
        scopeSawItCleared.complete(
          TomTransactionManager.getCurrentTransaction() == null,
        );
      });
      expect(await scopeSawItCleared.future, isTrue);
      expect(opened.isRunning, isFalse);
    });
  });

  group('ambient enlistment', () {
    test(
      'a participant enlisting inside a scope joins that transaction',
      () async {
        final p = _RecordingParticipant('inside');
        await TomTransactionManager.runInTransactionScope(() async {
          final (txn, _) = TomTransactionManager.startTransaction();
          expect(await enlistAmbiently(p), isTrue);
          await txn.commitTransaction();
        });
        expect(p.calls, ['start', 'commit', 'end']);
      },
    );

    test('a participant enlisting outside every scope joins nothing', () async {
      final inside = _RecordingParticipant('inside');
      final outside = _RecordingParticipant('outside');
      final started = Completer<void>();
      final mayFinish = Completer<void>();

      final flow = TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction();
        await enlistAmbiently(inside);
        started.complete();
        await mayFinish.future;
        await txn.commitTransaction();
      });

      await started.future;
      // A scoped transaction is running right now, and this code is not in it.
      expect(await enlistAmbiently(outside), isFalse);
      mayFinish.complete();
      await flow;

      expect(inside.calls, ['start', 'commit', 'end']);
      expect(outside.calls, isEmpty);
    });
  });

  group('TomTransactionException', () {
    test('is a TomServerException subtype', () {
      expect(TomTransactionException('k', 'm'), isA<TomServerException>());
    });

    test('carries its key and default user message', () {
      final e = TomTransactionException('a.key', 'a message');
      expect(e.key, 'a.key');
      expect(e, isA<TomException>());
    });
  });

  group('The example runs green', () {
    final examplePath = p.join(
      'example',
      'transactions',
      'transactions_example.dart',
    );

    test('under exactly the command its header documents', () async {
      // The example is the module's worked demonstration and the source of the
      // completion document's snippets, so it drifts silently unless something
      // runs it. Run it the way a reader would — plain `dart run`, no extra
      // flags — and require the exit code its own checks produce.
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // A crash before the last step would also exit 0 if it were swallowed,
      // so pin that every numbered step actually reported.
      for (var step = 1; step <= 7; step++) {
        expect(result.stdout, contains('$step. '));
      }
    });

    test('with its expectations checked rather than asserted', () async {
      // The test above cannot see the difference on its own: an example that
      // checks nothing exits 0 too. `dart run` leaves assertions disabled —
      // that is what `--enable-asserts` is for — so an `assert` in the example
      // is compiled out under the very command the test above uses, and the
      // run stays green with every expectation violated. The example therefore
      // states its expectations through a throwing helper, and this guards the
      // regression of quietly reverting them to `assert`.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        isNot(contains('assert(')),
        reason: 'an assert in the example does not run under `dart run`',
      );
      expect(
        source,
        contains("import '../_support/check.dart'"),
        reason: 'the example states its expectations through the shared helper',
      );
    });
  });

  group('the documents agree with the contract about a prepare phase', () {
    // Every text a reader could reach for the module's guarantees. The source
    // is first because it is also the contract these tests read.
    const texts = [
      'lib/src/tomserver/transactions/transaction_manager.dart',
      'lib/src/tomserver/transactions/readme.md',
      'doc/transactions.md',
      'doc/api_reference/api_summary_transactions.md',
    ];

    /// Whether `TomTransactionParticipant` declares a prepare step.
    ///
    /// Read from the source rather than hard-coded, so that adding a prepare
    /// phase flips these tests instead of leaving them asserting yesterday's
    /// answer: the documents are forced to follow the code either way.
    bool contractHasPrepare() =>
        RegExp(r'abstract class TomTransactionParticipant \{[\s\S]*?\n\}')
            .firstMatch(File(texts.first).readAsStringSync())!
            .group(0)!
            .contains('prepare(');

    test('the contract is the one the documents describe', () {
      // Pins today's answer in one place. When a prepare phase is added this
      // is the test that fails first, and its failure is the instruction to
      // rewrite the four texts rather than to edit this line.
      expect(
        contractHasPrepare(),
        isFalse,
        reason:
            'TomTransactionParticipant gained a prepare step — the four texts '
            'listed here now say the opposite of the code',
      );
    });

    test('no text claims two-phase commit while the contract lacks one', () {
      if (contractHasPrepare()) return;
      final offenders = <String>[];
      for (final path in texts) {
        // Line breaks fall anywhere in prose, so a claim and its denial can be
        // split across two lines; normalise before looking at either.
        final prose = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        for (final match in RegExp(
          r'[\w-]*two[- ]phase[\w-]*',
          caseSensitive: false,
        ).allMatches(prose)) {
          final before = prose.substring(
            match.start < 40 ? 0 : match.start - 40,
            match.start,
          );
          if (RegExp(r'\bnot\b', caseSensitive: false).hasMatch(before)) {
            continue;
          }
          offenders.add('$path: ...$before${match.group(0)}...');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the coordinator has no prepare step, so an unqualified "two-phase" '
            'promises a veto that can abort before anything is committed',
      );
    });

    test('every text says so, rather than merely not saying otherwise', () {
      if (contractHasPrepare()) return;
      // Deleting the word would satisfy the test above while leaving a reader
      // to discover the limitation from the source. The absent prepare phase is
      // the module's single most consequential property — a rollback runs after
      // a peer has already committed — so each text has to state it.
      for (final path in texts) {
        final prose = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          prose,
          contains('not two-phase commit'),
          reason: '$path does not tell the reader this is not two-phase commit',
        );
      }
    });
  });
}
