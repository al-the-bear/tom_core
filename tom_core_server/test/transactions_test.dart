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
/// A [TomLogOutput] that keeps every message instead of printing it, so a test
/// can assert on what the coordinator actually wrote.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => messages.add(convertToString(message));
}

/// A participant that records the lifecycle calls made on it.
///
/// [vetoPrepare] makes `prepare()` return `false`, which is the veto; a
/// [prepareThrows] makes it throw, which the coordinator has to treat the same
/// way. [vetoCommit] makes `commit()` return `false` — *not* a veto, since the
/// transaction is decided by then, but the in-doubt outcome the coordinator
/// has to report without rolling anybody back.
/// [endResult] is the value returned by `endTransaction()` — set it `false` to
/// exercise the "an end call failed" branch of the commit/rollback drive. When
/// a [sharedLog] is supplied, every call is also appended to it as `id:call`,
/// so a test spanning several participants can assert cross-participant
/// ordering.
class _RecordingParticipant extends TomTransactionParticipant {
  _RecordingParticipant(
    this.id, {
    this.vetoPrepare = false,
    this.prepareThrows = false,
    this.vetoCommit = false,
    this.endResult = true,
    this.sharedLog,
  });

  final String id;
  final bool vetoPrepare;
  final bool prepareThrows;
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
  Future<bool> prepare() async {
    _record('prepare');
    if (prepareThrows) throw StateError('the resource cannot promise');
    return !vetoPrepare;
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

/// A participant whose `startTransaction` fails, in whichever of the two ways
/// the caller asks for.
///
/// Both are scripted from one class so the two tests differ only in the failure
/// and not in the participant: the coordinator is supposed to treat a refusal
/// and a throw alike, and a fixture that made them different shapes would
/// obscure whether it does.
class _UnstartableParticipant extends TomTransactionParticipant {
  _UnstartableParticipant(this.id, {required this.byThrowing});

  final String id;
  final bool byThrowing;
  final List<String> calls = [];

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction() async {
    calls.add('start');
    if (byThrowing) throw StateError('the resource is not there');
    return false;
  }

  @override
  Future<bool> prepare() async {
    calls.add('prepare');
    return true;
  }

  @override
  Future<bool> commit() async {
    calls.add('commit');
    return true;
  }

  @override
  Future<void> rollback() async => calls.add('rollback');

  @override
  Future<bool> endTransaction() async {
    calls.add('end');
    return true;
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
        expect(p.calls, ['start', 'prepare', 'commit', 'end']);
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
      // The whole point of the two-phase shape, in one list: **every**
      // participant is prepared before **any** is committed. A commit
      // interleaved into the prepare loop would make the first commit durable
      // before the second participant had said whether it could, which is the
      // window a prepare phase exists to close. Every loop follows registration
      // order, and the ends come last because they decide nothing.
      expect(log, [
        'a:start',
        'b:start',
        'a:prepare',
        'b:prepare',
        'a:commit',
        'b:commit',
        'a:end',
        'b:end',
      ]);
    });

    test(
      'a participant vetoing in prepare turns the commit into a rollback',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a', vetoPrepare: true);
        await txn.registerParticipant(p);
        await txn.commitTransaction();
        expect(p.calls, ['start', 'prepare', 'rollback', 'end']);
        expect(
          p.calls,
          isNot(contains('commit')),
          reason: 'a vetoed transaction commits nobody',
        );
        expect(TomTransactionManager.getCurrentTransaction(), isNull);
      },
    );

    test('a participant throwing in prepare is treated as a veto', () async {
      // `false` and a throw are the same event to the coordinator — the
      // participant cannot promise — and letting the throw escape would leave
      // the transaction not-running, nobody rolled back, and the scope still
      // pointing at it.
      final (txn, _) = TomTransactionManager.startTransaction();
      final thrower = _RecordingParticipant('a', prepareThrows: true);
      final other = _RecordingParticipant('b');
      await txn.registerParticipant(thrower);
      await txn.registerParticipant(other);

      final ok = await txn.commitTransaction();

      expect(ok, isTrue, reason: 'the rollback itself succeeded');
      expect(thrower.calls, ['start', 'prepare', 'rollback', 'end']);
      expect(other.calls, ['start', 'rollback', 'end']);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('a later veto stops the commit before anyone has committed', () async {
      // The property the prepare phase buys, stated as the thing that used to
      // be false: the first participant is rolled back having never been
      // asked to commit, so there is nothing durable to undo and the rollback
      // is a real abort rather than a compensation nobody can guarantee.
      final (txn, _) = TomTransactionManager.startTransaction();
      final first = _RecordingParticipant('a');
      final vetoer = _RecordingParticipant('b', vetoPrepare: true);
      await txn.registerParticipant(first);
      await txn.registerParticipant(vetoer);

      final ok = await txn.commitTransaction();

      expect(ok, isTrue); // rollback's end calls all succeeded
      expect(first.calls, ['start', 'prepare', 'rollback', 'end']);
      expect(vetoer.calls, ['start', 'prepare', 'rollback', 'end']);
      expect(
        [...first.calls, ...vetoer.calls],
        isNot(contains('commit')),
        reason:
            'the veto arrived in phase one, so no participant was asked to '
            'make anything durable',
      );
    });

    test(
      'a commit that fails after a successful prepare is not a veto',
      () async {
        // The in-doubt outcome, and the one the coordinator must NOT answer
        // with a rollback: the participants that committed are durable, and
        // rolling them back would discard work the transaction decided to keep.
        // Every participant is still committed — the broken promise does not
        // stop the ones behind it — and the failure comes out in the result.
        final (txn, _) = TomTransactionManager.startTransaction();
        final broken = _RecordingParticipant('a', vetoCommit: true);
        final kept = _RecordingParticipant('b');
        await txn.registerParticipant(broken);
        await txn.registerParticipant(kept);

        final ok = await txn.commitTransaction();

        expect(ok, isFalse);
        expect(broken.calls, ['start', 'prepare', 'commit', 'end']);
        expect(kept.calls, ['start', 'prepare', 'commit', 'end']);
        expect(
          [...broken.calls, ...kept.calls],
          isNot(contains('rollback')),
          reason:
              'rolling back a participant whose commit succeeded is the '
              'failure two-phase commit exists to prevent',
        );
      },
    );

    test('and the partial commit is reported by name', () async {
      // An operator repairing it has to go to the named resources, so the
      // names are the whole message. Nothing else in the run can produce it:
      // this is the only path that logs at error level from the coordinator.
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(
        _RecordingParticipant('ledger', vetoCommit: true),
      );
      await txn.registerParticipant(_RecordingParticipant('audit'));
      await txn.commitTransaction();

      final written = output.messages.join('\n');
      expect(written, contains('partially committed'));
      expect(written, contains('ledger'));
    });

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
        expect(p.calls, ['start', 'prepare', 'commit', 'end']);
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
        expect(failing.calls, ['start', 'prepare', 'commit', 'end']);
        expect(second.calls, ['start', 'prepare', 'commit', 'end']);
        expect(third.calls, ['start', 'prepare', 'commit', 'end']);
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

  group('clearing the scope', () {
    test('a concluded transaction does not wipe its successor', () async {
      // The scope is cleared by identity, and this is the case that needs it.
      // A transaction concludes at a point in time; the scope may already have
      // moved on, and concluding it a second time -- neither `commit` nor
      // `rollback` refuses a transaction that has already ended -- must not
      // take the successor with it. Without the identity check the second
      // transaction is silently dropped from the scope while still running, so
      // the next `startTransaction()` opens a third and the work enlisted in
      // the second is concluded by nobody.
      //
      // Found by mutation: replacing the guard with an unconditional
      // `current = null` left the whole suite green.
      final (first, _) = TomTransactionManager.startTransaction();
      await first.commitTransaction();

      final (second, opened) = TomTransactionManager.startTransaction();
      expect(opened, isTrue, reason: 'the first must have cleared itself');
      expect(TomTransactionManager.getCurrentTransaction(), same(second));

      await first.rollbackTransaction();

      expect(
        TomTransactionManager.getCurrentTransaction(),
        same(second),
        reason:
            'the concluded transaction cleared its successor from the scope',
      );
      expect(second.isRunning, isTrue);

      await second.rollbackTransaction();
    });
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

    // Enlistment is all or nothing, and the two ways a start can fail are
    // reported alike. A participant left enlisted after a failed start is
    // committed later by `commitTransaction` — which for `MariaDbXADatasource`
    // is `XA COMMIT null;` against the branch its failed start had already
    // cleared, so the failure surfaces as a commit-time error naming the wrong
    // operation, at the moment the coordinator is deciding whether to roll
    // everyone back.
    //
    // The two are separate tests because they were separately wrong: the
    // refusal was discarded (the `bool` was not read at all) and the throw
    // propagated *after* the map insert had already happened. Both are asserted
    // through the same participant so the only difference is the failure.

    test('a participant that refuses to start is not enlisted', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final refuser = _UnstartableParticipant('refuser', byThrowing: false);

      await expectLater(
        txn.registerParticipant(refuser),
        throwsA(
          isA<TomTransactionException>()
              .having(
                (e) => e.key,
                'key',
                'transaction_manager.register_participant.start_failed',
              )
              .having(
                (e) => e.parameters?['participant'],
                'participant',
                'refuser',
              ),
        ),
      );

      // The point of the throw: concluding the transaction must not reach a
      // resource that never opened one. `commit` here would be the wrong
      // operation on a branch that is not there.
      expect(await txn.commitTransaction(), isTrue);
      expect(refuser.calls, ['start']);
    });

    test('a participant that throws while starting is not enlisted', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final thrower = _UnstartableParticipant('thrower', byThrowing: true);

      await expectLater(
        txn.registerParticipant(thrower),
        throwsA(
          isA<TomTransactionException>()
              .having(
                (e) => e.key,
                'key',
                'transaction_manager.register_participant.start_threw',
              )
              .having(
                (e) => e.parameters?['participant'],
                'participant',
                'thrower',
              )
              // The original is carried rather than summarised: the coordinator
              // knows which participant failed and nothing else, and what the
              // resource objected to is only in what it raised.
              .having(
                (e) => e.rootException,
                'rootException',
                isA<StateError>(),
              ),
        ),
      );

      expect(await txn.commitTransaction(), isTrue);
      expect(thrower.calls, ['start']);
    });

    test(
      'a failed enlistment leaves the rest of the transaction intact',
      () async {
        // The transaction is not concluded by the failure — a caller that catches
        // it may carry on with the participants that did enlist. What must not
        // happen is the failed one joining them.
        final (txn, _) = TomTransactionManager.startTransaction();
        final good = _RecordingParticipant('good');
        await txn.registerParticipant(good);

        await expectLater(
          txn.registerParticipant(
            _UnstartableParticipant('bad', byThrowing: false),
          ),
          throwsA(isA<TomTransactionException>()),
        );

        expect(txn.isRunning, isTrue);
        expect(await txn.commitTransaction(), isTrue);
        expect(good.calls, ['start', 'prepare', 'commit', 'end']);
      },
    );

    test(
      'a refused participant may be enlisted again once it can start',
      () async {
        // Nothing is remembered about the failure, which is what makes a retry
        // possible: the id was never recorded, so a second attempt is a first
        // enlistment rather than the deduplicated no-op it would be if the map
        // had kept it.
        final (txn, _) = TomTransactionManager.startTransaction();
        await expectLater(
          txn.registerParticipant(
            _UnstartableParticipant('flaky', byThrowing: false),
          ),
          throwsA(isA<TomTransactionException>()),
        );

        final retry = _RecordingParticipant('flaky');
        await txn.registerParticipant(retry);

        expect(await txn.commitTransaction(), isTrue);
        expect(retry.calls, ['start', 'prepare', 'commit', 'end']);
      },
    );

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
        expect(pa.calls, ['start', 'prepare', 'commit', 'end']);
        expect(pb.calls, ['start', 'prepare', 'commit', 'end']);
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
        expect(p.calls, ['start', 'prepare', 'commit', 'end']);
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

      expect(inside.calls, ['start', 'prepare', 'commit', 'end']);
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

  // The module's guarantee is decided by one declaration — whether
  // `TomTransactionParticipant` has a prepare step — and it is described in
  // four places a reader can reach. Those four have to say what the code does,
  // in both directions: a document promising two-phase commit over a contract
  // that has no prepare phase invites a caller to rely on atomicity it will not
  // get, and a document still denying one over a contract that has it sends a
  // reader to build compensation they no longer need.
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
    /// Read from the source rather than hard-coded, so that removing the
    /// prepare phase flips these tests instead of leaving them asserting
    /// yesterday's answer: the documents are forced to follow the code either
    /// way.
    bool contractHasPrepare() =>
        RegExp(r'abstract class TomTransactionParticipant \{[\s\S]*?\n\}')
            .firstMatch(File(texts.first).readAsStringSync())!
            .group(0)!
            .contains('prepare(');

    test('the contract is the one the documents describe', () {
      // Pins today's answer in one place. If the prepare phase is ever taken
      // out, this is the test that fails first, and its failure is the
      // instruction to rewrite the four texts rather than to edit this line.
      expect(
        contractHasPrepare(),
        isTrue,
        reason:
            'TomTransactionParticipant lost its prepare step — the four texts '
            'listed here now say the opposite of the code',
      );
    });

    test('no text denies the two-phase commit the contract performs', () {
      if (!contractHasPrepare()) return;
      // The denial this module carried while it had no prepare phase, in every
      // spelling the old texts used. Leaving one behind is worse than saying
      // nothing: it is a specific, confident, wrong instruction to a reader
      // deciding whether they need their own compensation logic.
      const denials = [
        'not two-phase commit',
        'no prepare step',
        'there is no prepare',
        'has no prepare',
        'lacks a prepare',
      ];
      final offenders = <String>[];
      for (final path in texts) {
        // Line breaks fall anywhere in prose, so a claim and its denial can be
        // split across two lines; normalise before looking at either.
        final prose = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        for (final denial in denials) {
          if (prose.toLowerCase().contains(denial)) {
            offenders.add('$path: "$denial"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the coordinator prepares every participant before it commits any '
            'of them, so these sentences are false',
      );
    });

    test('every text says so, rather than merely not denying it', () {
      if (!contractHasPrepare()) return;
      // Deleting the denial would satisfy the test above while leaving a reader
      // to discover the guarantee from the source. The prepare phase is the
      // module's single most consequential property — it is what makes a veto
      // arrive before anything is durable — so each text has to state it.
      for (final path in texts) {
        final prose = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        expect(
          prose,
          contains('two-phase'),
          reason: '$path does not tell the reader this is two-phase commit',
        );
        expect(
          prose,
          contains('prepare'),
          reason: '$path does not name the prepare phase',
        );
      }
    });

    test(
      'and every text states the one outcome two phases cannot rule out',
      () {
        if (!contractHasPrepare()) return;
        // A prepare phase makes a veto free; it does not make a commit
        // infallible. A participant that promised and then failed leaves the
        // transaction durable in part, and no coordinator can undo that — so a
        // text that describes the guarantee without the residue is describing
        // something stronger than what ships.
        for (final path in texts) {
          final prose = File(
            path,
          ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          expect(
            prose,
            anyOf(
              contains('partially committed'),
              contains('in doubt'),
              contains('in-doubt'),
            ),
            reason:
                '$path describes the two-phase commit without the outcome it '
                'cannot prevent',
          );
        }
      },
    );
  });
}
