import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the transactions module: the [TomTransaction] lifecycle, the
/// two-phase commit and the rollback drive, participant enlistment and its
/// refusals, [TomTransactionManager.runInTransaction], and the ambient
/// accessors — both in the process-wide fallback scope and inside an explicit
/// [TomTransactionManager.runInTransactionScope]. The module is self-contained
/// (no reflection, no database), so the whole surface is exercised here with
/// fake participants.
///
/// **The failure paths are driven with two participants, not one.** One is
/// exactly the population size at which a drive that stops at the first
/// failure looks correct: the single participant reports its failure, the
/// return value carries it, and nothing shows that the participant *behind* it
/// was never concluded. Every test of a `false` or a throw from a conclusion
/// hook therefore enlists a second participant and asserts that it was driven.
///
/// **A participant that throws does not reach the caller**, and that is a
/// decision rather than an omission: one resource's failure must not stop its
/// neighbours being concluded, and an exception escaping the drive would also
/// leave the scope pointing at a concluded transaction. What makes the
/// catching safe is that the failure is on the record — so the suite asserts,
/// for every conclusion hook, that the swallowed throw is logged naming the
/// participant that raised it and what it raised. A throw the coordinator
/// swallows and never mentions is the one nobody can investigate.
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
    this.failRollback = false,
    this.endResult = true,
    this.sharedLog,
  });

  final String id;
  final bool vetoPrepare;
  final bool prepareThrows;
  final bool vetoCommit;
  final bool failRollback;
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
  Future<bool> startTransaction(TomTransaction transaction) async {
    _record(transaction.isReadOnly ? 'start(read-only)' : 'start');
    return true;
  }

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    _record('prepare');
    if (prepareThrows) throw StateError('the resource cannot promise');
    return !vetoPrepare;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    _record('commit');
    return !vetoCommit;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    _record('rollback');
    return !failRollback;
  }

  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
    _record('end');
    return endResult;
  }
}

/// A participant whose every hook **suspends** before it answers.
///
/// The recording fakes above are `async` but complete without yielding, so a
/// coordinator that drove them with `Future.wait` would produce exactly the
/// recorded order a sequential one does. Ordering is only observable across a
/// real asynchronous gap, so this one takes one: it records entering a hook,
/// awaits, and records leaving it. A sequential drive produces
/// `a:enter, a:leave, b:enter, b:leave`; a parallel drive interleaves.
class _SuspendingParticipant extends TomTransactionParticipant {
  _SuspendingParticipant(this.id, this.log);

  final String id;
  final List<String> log;

  @override
  String getParticipantId() => id;

  Future<void> _span(String hook) async {
    log.add('$id:$hook:enter');
    // Two hops rather than one, so that a parallel drive has somewhere to
    // interleave even if the scheduler runs the first continuation eagerly.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    log.add('$id:$hook:leave');
  }

  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    await _span('start');
    return true;
  }

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    await _span('prepare');
    return true;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    await _span('commit');
    return true;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    await _span('rollback');
    return true;
  }

  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
    await _span('end');
    return true;
  }
}

/// A participant that throws from exactly one of the conclusion hooks.
///
/// A data source whose connection has dropped mid-conclusion is the case: it
/// fails at whichever hook happens to be next, and which one that is depends on
/// timing rather than on anything the coordinator chose. So all four are driven
/// from one class.
class _ThrowingParticipant extends TomTransactionParticipant {
  _ThrowingParticipant(this.id, this.throwsFrom);

  final String id;

  /// One of `prepare`, `commit`, `rollback`, `end`.
  final String throwsFrom;

  final List<String> calls = [];

  void _maybeThrow(String hook) {
    calls.add(hook);
    if (hook == throwsFrom) throw StateError('the connection dropped');
  }

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    _maybeThrow('prepare');
    return true;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    _maybeThrow('commit');
    return true;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    _maybeThrow('rollback');
    return true;
  }

  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
    _maybeThrow('end');
    return true;
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
  Future<bool> startTransaction(TomTransaction transaction) async {
    calls.add('start');
    if (byThrowing) throw StateError('the resource is not there');
    return false;
  }

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    calls.add('prepare');
    return true;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    calls.add('commit');
    return true;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    calls.add('rollback');
    return true;
  }

  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
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
        expect(ok.isClean, isTrue);
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
      expect(ok.isClean, isTrue);
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

      expect(
        ok.outcome,
        TomTransactionOutcome.rolledBack,
        reason:
            'the work did not commit, however cleanly the rollback ran — the '
            'result names the rollback rather than reporting a commit',
      );
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

      expect(
        ok.outcome,
        TomTransactionOutcome.rolledBack,
        reason: 'a vetoed transaction did not commit',
      );
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

        expect(ok.outcome, TomTransactionOutcome.partiallyCommitted);
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
        expect(ok.isCommitted, isTrue, reason: 'the work is durable');
        expect(ok.notReleased, ['a']);
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
        expect(ok.notReleased, ['a']);
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
        expect(ok.isClean, isTrue);
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
        expect(ok.isClean, isTrue);
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
      expect(ok.outcome, TomTransactionOutcome.rolledBack);
      expect(ok.notReleased, ['a']);
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
        expect(ok.notReleased, ['a']);
      },
    );
  });

  // A conclusion has four possible fates for the work and one further, unrelated
  // fact about resources, and a single boolean can carry none of them
  // separately. The case that shows why is a rollback in which every
  // participant failed to undo its work and every participant released its
  // connection cleanly: the work is neither committed nor undone — the one
  // outcome that requires a human — while every release succeeded. A value
  // built from the releases calls that success.
  group('the conclusion names what became of the work', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    test('a clean commit is committed and clean', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_RecordingParticipant('a'));

      final result = await txn.commitTransaction();

      expect(result.outcome, TomTransactionOutcome.committed);
      expect(result.isCommitted, isTrue);
      expect(result.isClean, isTrue);
      expect(result.failed, isEmpty);
      expect(result.notReleased, isEmpty);
    });

    test('a clean rollback is rolledBack, not committed', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_RecordingParticipant('a'));

      final result = await txn.rollbackTransaction();

      expect(result.outcome, TomTransactionOutcome.rolledBack);
      expect(result.isCommitted, isFalse);
      expect(result.isClean, isTrue);
    });

    test('a rollback that could not undo is rolledBackWithFailures', () async {
      // The case the boolean could not express at all. Both participants
      // release cleanly, so every value the old signature could see said the
      // conclusion had gone well.
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(
        _RecordingParticipant('ledger', failRollback: true),
      );
      await txn.registerParticipant(_RecordingParticipant('audit'));

      final result = await txn.rollbackTransaction();

      expect(result.outcome, TomTransactionOutcome.rolledBackWithFailures);
      expect(result.failed, ['ledger']);
      expect(
        result.notReleased,
        isEmpty,
        reason:
            'every participant released — which is exactly what made this '
            'invisible before',
      );
      expect(result.isClean, isFalse);
      expect(
        captured.messages.join('\n'),
        contains('neither committed nor rolled back'),
      );
    });

    test(
      'a participant that throws while rolling back is a failure too',
      () async {
        // A throw and a `false` are the same answer: this participant did not
        // undo its work.
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(
          _ThrowingParticipant('thrower', 'rollback'),
        );
        await txn.registerParticipant(_RecordingParticipant('behind'));

        final result = await txn.rollbackTransaction();

        expect(result.outcome, TomTransactionOutcome.rolledBackWithFailures);
        expect(result.failed, ['thrower']);
      },
    );

    test('a veto answers with the rollback it became', () async {
      // `commitTransaction` returns the rollback's own result, so the answer
      // says what happened rather than reporting a commit that did not.
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(
        _RecordingParticipant('a', vetoPrepare: true),
      );

      final result = await txn.commitTransaction();

      expect(result.outcome, TomTransactionOutcome.rolledBack);
      expect(result.isCommitted, isFalse);
    });

    test(
      'a broken promise is partiallyCommitted, naming the participant',
      () async {
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(
          _RecordingParticipant('ledger', vetoCommit: true),
        );
        await txn.registerParticipant(_RecordingParticipant('audit'));

        final result = await txn.commitTransaction();

        expect(result.outcome, TomTransactionOutcome.partiallyCommitted);
        expect(result.failed, ['ledger']);
        expect(result.isCommitted, isFalse);
      },
    );

    test('a release failure is separate from the outcome', () async {
      // The fifth fact the boolean merged in. The work is durable; a connection
      // is not back in the pool. A caller told "false" could not tell this from
      // "your work is gone", and the two call for opposite responses — this one
      // must not be retried.
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(
        _RecordingParticipant('a', endResult: false),
      );

      final result = await txn.commitTransaction();

      expect(result.outcome, TomTransactionOutcome.committed);
      expect(result.isCommitted, isTrue, reason: 'the work is durable');
      expect(result.notReleased, ['a']);
      expect(result.isClean, isFalse);
    });

    test('and toString names the outcome and everyone who failed', () async {
      // The result reaches a log line or an exception message far more often
      // than it is destructured, and `Instance of TomTransactionResult` is the
      // same silence in a new place.
      const result = TomTransactionResult(
        TomTransactionOutcome.rolledBackWithFailures,
        failed: ['ledger'],
        notReleased: ['audit'],
      );

      expect(result.toString(), contains('rolledBackWithFailures'));
      expect(result.toString(), contains('ledger'));
      expect(result.toString(), contains('audit'));
    });
  });

  // Both drives are `for` loops with an `await` in the body, which is a
  // decision rather than an accident. The order they give is the contract —
  // "in registration order", in four documents — and a veto depends on it: which
  // participants have already been asked to commit when one arrives is knowable
  // only because they were asked one at a time. Driven with `Future.wait`, "the
  // participants that had already committed" stops being a knowable set.
  //
  // The cost is real and is stated where a reader meets it: a transaction
  // spanning n resources pays n sequential round trips on each phase, at the
  // point in a request where the client is waiting and the connections are
  // still held. A transaction spanning enough resources for that to matter is a
  // design problem before it is a performance one.
  //
  // This group exists because the ordering tests above cannot see the
  // difference. The recording fakes are `async` but complete without yielding,
  // so a coordinator using `Future.wait` produces exactly the order they
  // record. Ordering is only observable across a real asynchronous gap.
  group('the drives are sequential, not merely ordered', () {
    /// The hooks of [log] that belong to [phase], as `<id>:enter|leave`.
    List<String> phaseOf(List<String> log, String phase) => [
      for (final entry in log)
        if (entry.split(':')[1] == phase)
          '${entry.split(':')[0]}:${entry.split(':')[2]}',
    ];

    /// Asserts that no two participants were inside [phase] at once.
    void expectSerial(List<String> log, String phase) {
      expect(
        phaseOf(log, phase),
        ['a:enter', 'a:leave', 'b:enter', 'b:leave'],
        reason:
            'the $phase phase interleaved: the coordinator drove its '
            'participants concurrently, so registration order no longer says '
            'which of them had been reached when a failure arrived',
      );
    }

    Future<List<String>> drive({required bool byRollback}) async {
      final log = <String>[];
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_SuspendingParticipant('a', log));
      await txn.registerParticipant(_SuspendingParticipant('b', log));
      await (byRollback ? txn.rollbackTransaction() : txn.commitTransaction());
      return log;
    }

    test('a commit prepares one participant at a time', () async {
      expectSerial(await drive(byRollback: false), 'prepare');
    });

    test('and commits one at a time', () async {
      expectSerial(await drive(byRollback: false), 'commit');
    });

    test('and ends one at a time', () async {
      // Releasing a connection is ordered by nothing, so this phase stays a
      // loop for a measured reason rather than for its order:
      // tool/bench_transaction_end_phase.dart puts the whole sequential phase
      // at microseconds for every shipped participant, with `Future.wait`
      // slower. Parallelising it is a change to make against a new
      // measurement, not by edit.
      expectSerial(await drive(byRollback: false), 'end');
    });

    test('a rollback rolls back one participant at a time', () async {
      expectSerial(await drive(byRollback: true), 'rollback');
    });

    test('and ends one at a time as well', () async {
      expectSerial(await drive(byRollback: true), 'end');
    });

    test('and the fixture can tell the two apart', () async {
      // Every assertion above is a list comparison, and a fixture that could
      // not interleave would satisfy them whatever the coordinator did. So it
      // is shown a genuinely concurrent drive of the same participants.
      final log = <String>[];
      final a = _SuspendingParticipant('a', log);
      final b = _SuspendingParticipant('b', log);
      final txn = TomTransactionManager.startTransaction().$1;

      await Future.wait([a.prepare(txn), b.prepare(txn)]);

      expect(
        phaseOf(log, 'prepare'),
        isNot(['a:enter', 'a:leave', 'b:enter', 'b:leave']),
        reason:
            'the fixture completes without suspending, so nothing it is '
            'used for can distinguish sequential from parallel',
      );
    });
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

  // The invariant the rest of the module assumes: a transaction that is no
  // longer running is not the current one. It is set `false` on the first line
  // of both conclusions, so anything that leaves either of them without
  // clearing the scope leaves the two public accessors contradicting each
  // other — `getCurrentTransaction()` non-null while `transactional` is
  // `false` — and hands every later `startTransaction()` in that scope the dead
  // transaction with `isNew == false`. The caller reads that as "I am nested
  // inside somebody else's transaction", so it neither concludes it nor opens
  // one of its own, and every enlistment on it is refused with
  // `transaction_not_running`: three symptoms, none of which names the cause.
  //
  // On the request path the blast radius is one request, because the scope goes
  // away with it. Off it — a script, a scheduler, a test — the scope is the
  // process-wide fallback, so the state outlives the flow that produced it.
  group('a participant that throws while concluding leaves the scope clear', () {
    /// Drives a transaction whose single participant throws from [hook] and
    /// reports what the scope holds afterwards.
    Future<({bool escaped, bool cleared, bool transactional})> conclude(
      String hook, {
      required bool byRollback,
    }) async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_ThrowingParticipant('p', hook));
      var escaped = false;
      try {
        await (byRollback
            ? txn.rollbackTransaction()
            : txn.commitTransaction());
      } catch (_) {
        escaped = true;
      }
      return (
        escaped: escaped,
        cleared: TomTransactionManager.getCurrentTransaction() == null,
        transactional: TomTransactionManager.transactional,
      );
    }

    for (final hook in ['prepare', 'commit', 'end']) {
      test('a commit whose participant throws from $hook', () async {
        final result = await conclude(hook, byRollback: false);
        expect(
          result.escaped,
          isFalse,
          reason:
              'the coordinator handles it, deliberately — see the header, and '
              'the group that pins the log line it writes instead',
        );
        expect(result.cleared, isTrue);
        expect(result.transactional, isFalse);
      });
    }

    for (final hook in ['rollback', 'end']) {
      test('a rollback whose participant throws from $hook', () async {
        final result = await conclude(hook, byRollback: true);
        expect(result.escaped, isFalse);
        expect(result.cleared, isTrue);
        expect(result.transactional, isFalse);
      });
    }

    test('the scope is usable again afterwards', () async {
      // The consequence a caller actually meets, rather than the state that
      // causes it: the next flow in this scope has to get a *new* transaction
      // it can enlist in. A pinned scope answers `isNew == false` and then
      // refuses the enlistment.
      await conclude('commit', byRollback: false);

      final (next, isNew) = TomTransactionManager.startTransaction();
      addTearDown(() async {
        if (next.isRunning) await next.rollbackTransaction();
      });

      expect(isNew, isTrue, reason: 'the dead transaction was handed back');
      expect(next.isRunning, isTrue);
      await next.registerParticipant(_RecordingParticipant('after'));
    });

    test('the two accessors never disagree', () async {
      // They are read from different places — `transactional` from the
      // transaction's own flag, `getCurrentTransaction()` from the scope — and
      // a caller that happens to test the other one gets the opposite answer.
      // Stated over every hook, because the disagreement is the state, not the
      // hook that produced it.
      for (final hook in ['prepare', 'commit', 'rollback', 'end']) {
        final result = await conclude(hook, byRollback: hook == 'rollback');
        expect(
          result.cleared,
          isTrue,
          reason: 'a throw from $hook left the scope pinned',
        );
        expect(result.transactional, result.cleared ? isFalse : isTrue);
      }
    });

    test('and the clear is in a finally, not on the way out', () async {
      // Every participant call in both conclusions is caught, so nothing
      // reaches the `finally` today and no test can drive it. That is exactly
      // why it is read from the source: the guarantee is that the scope is
      // cleared *however* the method leaves, and a later edit that adds one
      // uncaught call — or moves the clear back to the last line — would
      // silently return the module to the state this group describes, with
      // every test above still green.
      final source = File(
        'lib/src/tomserver/transactions/transaction_manager.dart',
      ).readAsStringSync();

      // The public conclusions run their drive inside the transaction's span;
      // the drive itself is `_commit` / `_rollback`.
      expect(
        source,
        allOf(
          contains('commitTransaction() => _traced(_commit);'),
          contains('rollbackTransaction() => _traced(_rollback);'),
        ),
      );
      for (final method in ['_commit', '_rollback']) {
        final body = source.substring(
          source.indexOf('Future<TomTransactionResult> $method() async {'),
        );
        final end = body.indexOf('\n  }\n');
        final drive = body.substring(0, end);
        expect(
          drive,
          contains('} finally {\n      _scope._clear(this);\n    }'),
          reason: '$method no longer clears its scope in a finally',
        );
        expect(
          '_scope._clear(this)'.allMatches(drive).length,
          1,
          reason: '$method clears its scope more than once',
        );
      }
    });
  });

  // A participant that throws is caught, which is right — one resource's
  // failure must not stop its neighbours being concluded — but a throw the
  // coordinator swallows and never mentions is the one nobody can investigate.
  // These are the two halves that make the catching safe: the neighbours are
  // still driven, and the failure is on the record with the participant's name
  // on it.
  //
  // One participant is exactly the population size at which the first half is
  // invisible, which is why every test here uses two.
  group('a throwing participant does not take its neighbours with it', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    String written() => captured.messages.join('\n');

    test(
      'a commit that throws still commits the participant behind it',
      () async {
        final thrower = _ThrowingParticipant('thrower', 'commit');
        final behind = _RecordingParticipant('behind');
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(thrower);
        await txn.registerParticipant(behind);

        final ok = await txn.commitTransaction();

        expect(ok.outcome, TomTransactionOutcome.partiallyCommitted);
        expect(behind.calls, ['start', 'prepare', 'commit', 'end']);
        expect(thrower.calls, ['prepare', 'commit', 'end']);
        expect(written(), contains('thrower'));
        expect(
          written(),
          contains('partially committed'),
          reason: 'a broken promise is reported by name, not only counted',
        );
      },
    );

    test(
      'an endTransaction that throws still ends the one behind it',
      () async {
        // A `false` from `endTransaction` is already covered with three
        // participants. A throw is a different path through the same loop, and
        // the leak it would cause is the same one: a pooled connection with
        // nothing coming back for it.
        final thrower = _ThrowingParticipant('thrower', 'end');
        final behind = _RecordingParticipant('behind');
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(thrower);
        await txn.registerParticipant(behind);

        final ok = await txn.commitTransaction();

        expect(ok.notReleased, [
          'thrower',
        ], reason: 'a release that threw is a release that failed');
        expect(
          ok.isCommitted,
          isTrue,
          reason: 'the work committed; a connection is what leaked',
        );
        expect(behind.calls, [
          'start',
          'prepare',
          'commit',
          'end',
        ], reason: 'the participant behind the throw was never released');
        expect(written(), contains('thrower'));
      },
    );

    test('a rollback that throws still rolls back the one behind it', () async {
      // The path a failure already arrives on, so a participant skipped here is
      // skipped exactly when things are already wrong.
      final thrower = _ThrowingParticipant('thrower', 'rollback');
      final behind = _RecordingParticipant('behind');
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(thrower);
      await txn.registerParticipant(behind);

      final ok = await txn.rollbackTransaction();

      expect(
        ok.outcome,
        TomTransactionOutcome.rolledBackWithFailures,
        reason: 'a throw and a `false` are the same answer: it did not undo',
      );
      expect(ok.failed, ['thrower']);
      expect(behind.calls, ['start', 'rollback', 'end']);
      expect(thrower.calls, ['rollback', 'end']);
      expect(written(), contains('thrower'));
    });

    test(
      'an endTransaction that throws during a rollback is the same',
      () async {
        final thrower = _ThrowingParticipant('thrower', 'end');
        final behind = _RecordingParticipant('behind');
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(thrower);
        await txn.registerParticipant(behind);

        final ok = await txn.rollbackTransaction();

        expect(ok.notReleased, ['thrower']);
        expect(behind.calls, ['start', 'rollback', 'end']);
        expect(written(), contains('thrower'));
      },
    );

    test('a prepare that throws rolls back the participant behind it', () async {
      // The one hook where the throw is a veto rather than a report: nothing is
      // durable, so the participant behind it is rolled back having never been
      // asked to commit.
      final thrower = _ThrowingParticipant('thrower', 'prepare');
      final behind = _RecordingParticipant('behind');
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(thrower);
      await txn.registerParticipant(behind);

      final ok = await txn.commitTransaction();

      expect(
        ok.outcome,
        TomTransactionOutcome.rolledBack,
        reason: 'a vetoed transaction did not commit',
      );
      expect(behind.calls, ['start', 'rollback', 'end']);
      expect(
        behind.calls,
        isNot(contains('commit')),
        reason: 'the veto arrived in phase one',
      );
      expect(written(), contains('thrower'));
    });

    test('every conclusion hook names the participant that threw', () async {
      // Read as a set rather than per test: the four catches are four separate
      // `tomLog.error` calls, and one of them interpolating the wrong thing —
      // or nothing — is a failure that looks identical from outside.
      for (final hook in ['prepare', 'commit', 'rollback', 'end']) {
        captured.messages.clear();
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(_ThrowingParticipant('p-$hook', hook));
        await (hook == 'rollback'
            ? txn.rollbackTransaction()
            : txn.commitTransaction());

        expect(
          written(),
          contains("'p-$hook'"),
          reason:
              'a throw from $hook was swallowed without naming the participant '
              'that raised it',
        );
        expect(
          written(),
          contains('the connection dropped'),
          reason: 'and without saying what it raised',
        );
      }
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
      expect((await txn.commitTransaction()).isClean, isTrue);
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

      expect((await txn.commitTransaction()).isClean, isTrue);
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
        expect((await txn.commitTransaction()).isClean, isTrue);
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

        expect((await txn.commitTransaction()).isClean, isTrue);
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

  // Written by hand, the flow is a scope, a `startTransaction`, the work, a
  // `commitTransaction` and a `catch` that rolls back and rethrows — and the
  // version without the last part is shorter, reads correctly, and leaks. Every
  // assertion here is about the part a caller forgets.
  // `getParticipantId` names a resource, not an object — `MariaDbDatasource`
  // answers `"MariaDb-<database>@<host>:@<port>"` — so two instances pointing
  // at one database collide by construction. Collapsing the second to the first
  // is the one failure in this method that says nothing at all: the caller's
  // `await` completes, the resource is never started, prepared, committed,
  // rolled back or ended, and the work issued against it is neither committed
  // with the transaction nor rolled back with it. The first sign is data that
  // should have been undone and was not.
  // The flag exists to reach the resource that can act on it, and the contract
  // is the only path between the `@TomTransactional(isReadOnly: true)` that
  // declares it and the data source that opens the connection. Handed over
  // rather than looked up: an ambient `getCurrentTransaction()` asks the
  // participant to re-derive, from inside a call the coordinator just made,
  // which transaction made it — and it answers from whatever zone the call is
  // running in, which is the case the scoping exists to separate.
  group('a participant is handed the transaction it joins', () {
    test('and can read whether it was opened read-only', () async {
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction(true);
        final p = _RecordingParticipant('a');
        await txn.registerParticipant(p);
        await txn.commitTransaction();

        expect(p.calls, ['start(read-only)', 'prepare', 'commit', 'end']);
      });
    });

    test('a read-write transaction is reported as one', () async {
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a');
        await txn.registerParticipant(p);
        await txn.commitTransaction();

        expect(p.calls.first, 'start');
      });
    });

    test('it is the transaction it joined, not whatever is current', () async {
      // The distinction an ambient lookup cannot make. The participant is
      // enlisted in a read-only transaction from inside a *different* scope
      // whose own current transaction is read-write; a lookup would answer with
      // that one.
      late _RecordingParticipant p;
      await TomTransactionManager.runInTransactionScope(() async {
        final (outer, _) = TomTransactionManager.startTransaction();
        addTearDown(() async {
          if (outer.isRunning) await outer.rollbackTransaction();
        });
        expect(outer.isReadOnly, isFalse);

        late TomTransaction readOnly;
        await TomTransactionManager.runInTransactionScope(() async {
          (readOnly, _) = TomTransactionManager.startTransaction(true);
        });

        // Enlisting from out here, in the read-write scope, into the read-only
        // transaction held from the inner one.
        p = _RecordingParticipant('a');
        await readOnly.registerParticipant(p);
        await readOnly.commitTransaction();
      });

      expect(
        p.calls.first,
        'start(read-only)',
        reason:
            'the participant was told about the ambient transaction rather '
            'than the one it was enlisted in',
      );
    });
  });

  group('two distinct participants cannot share one id', () {
    test('the second is refused, naming the id', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      addTearDown(() async {
        if (txn.isRunning) await txn.rollbackTransaction();
      });
      final first = _RecordingParticipant('MariaDb-app@db:@3306');
      final second = _RecordingParticipant('MariaDb-app@db:@3306');
      await txn.registerParticipant(first);

      await expectLater(
        txn.registerParticipant(second),
        throwsA(
          isA<TomTransactionException>()
              .having(
                (e) => e.key,
                'key',
                'transaction_manager.register_participant.duplicate_id',
              )
              .having(
                (e) => e.parameters?['participant'],
                'participant',
                'MariaDb-app@db:@3306',
              ),
        ),
      );
    });

    test('and is never started, so it holds nothing to release', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final first = _RecordingParticipant('shared');
      final second = _RecordingParticipant('shared');
      await txn.registerParticipant(first);
      await expectLater(
        txn.registerParticipant(second),
        throwsA(isA<TomTransactionException>()),
      );

      await txn.commitTransaction();

      expect(first.calls, ['start', 'prepare', 'commit', 'end']);
      expect(
        second.calls,
        isEmpty,
        reason:
            'a refused participant opened nothing, so there is nothing for the '
            'conclusion to reach',
      );
    });

    test('the transaction the refusal interrupted is intact', () async {
      // The refusal is a report to the caller, not a conclusion: the
      // participants that did enlist are untouched, so a caller that catches it
      // may carry on with them or roll back — the same contract a failed
      // enlistment already has.
      final (txn, _) = TomTransactionManager.startTransaction();
      final first = _RecordingParticipant('shared');
      await txn.registerParticipant(first);
      await expectLater(
        txn.registerParticipant(_RecordingParticipant('shared')),
        throwsA(isA<TomTransactionException>()),
      );

      expect(txn.isRunning, isTrue);
      expect(TomTransactionManager.getCurrentTransaction(), same(txn));

      final other = _RecordingParticipant('other');
      await txn.registerParticipant(other);
      expect((await txn.commitTransaction()).isClean, isTrue);
      expect(other.calls, ['start', 'prepare', 'commit', 'end']);
    });

    test(
      'registering the very same participant again is still a no-op',
      () async {
        // The convenience the id-keying exists for, and the half that must not
        // change: a data source used twice in one request enlists once, without
        // the caller tracking membership.
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('shared');

        await txn.registerParticipant(p);
        await txn.registerParticipant(p);
        await txn.registerParticipant(p);

        await txn.commitTransaction();

        expect(p.calls, [
          'start',
          'prepare',
          'commit',
          'end',
        ], reason: 'one enlistment, however many times it was registered');
      },
    );
  });

  group('runInTransaction', () {
    test('commits on a normal return and hands back the body result', () async {
      final p = _RecordingParticipant('a');

      final result = await TomTransactionManager.runInTransaction((txn) async {
        await txn.registerParticipant(p);
        return 'the body result';
      });

      expect(result, 'the body result');
      expect(p.calls, ['start', 'prepare', 'commit', 'end']);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('rolls back on a throw, and rethrows the body failure', () async {
      // Both halves matter. The rollback is what the hand-written form omits;
      // rethrowing the *body's* exception is what keeps the caller's own error
      // reaching the caller rather than a transaction error standing in for it.
      final p = _RecordingParticipant('a');

      await expectLater(
        TomTransactionManager.runInTransaction((txn) async {
          await txn.registerParticipant(p);
          throw StateError('the work failed');
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'the work failed',
          ),
        ),
      );

      expect(p.calls, ['start', 'rollback', 'end']);
      expect(
        p.calls,
        isNot(contains('commit')),
        reason: 'a body that threw must not have its work committed',
      );
    });

    test(
      'and leaves no transaction behind in a scope it did not open',
      () async {
        // The leak stated where it is observable. When the helper forks its own
        // scope the abandoned transaction goes away with it, which is a bound
        // rather than a fix; in a scope that outlives the call — every request,
        // and every flow a caller wrapped itself — an unrolled-back transaction
        // stays current, and the next `startTransaction` here hands it back with
        // `isNew == false` instead of opening one.
        final p = _RecordingParticipant('a');

        await TomTransactionManager.runInTransactionScope(() async {
          await expectLater(
            TomTransactionManager.runInTransaction((txn) async {
              await txn.registerParticipant(p);
              throw StateError('the work failed');
            }),
            throwsA(isA<StateError>()),
          );

          expect(TomTransactionManager.getCurrentTransaction(), isNull);
          expect(TomTransactionManager.transactional, isFalse);

          final (next, isNew) = TomTransactionManager.startTransaction();
          expect(isNew, isTrue, reason: 'the abandoned transaction came back');
          await next.rollbackTransaction();
        });

        expect(p.calls, [
          'start',
          'rollback',
          'end',
        ], reason: 'and the participant was released rather than left holding');
      },
    );

    test('a body that throws synchronously is still a rollback', () async {
      // `Future.sync` and the `await` in the owning half both have to carry it;
      // a synchronous throw that escaped before the try would leak exactly as
      // the hand-written form does.
      final p = _RecordingParticipant('a');

      await expectLater(
        TomTransactionManager.runInTransaction((txn) {
          // Enlisted first so there is something to leak.
          return txn.registerParticipant(p).then((_) {
            throw StateError('synchronously, from the continuation');
          });
        }),
        throwsA(isA<StateError>()),
      );

      expect(p.calls, ['start', 'rollback', 'end']);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('a commit that does not succeed is not a silent success', () async {
      // The boolean cannot say which of the three it was, so the helper refuses
      // to hand back the body's result as though the work had happened. Here it
      // is the sharpest of the three: a veto, so nothing is durable at all.
      final vetoer = _RecordingParticipant('a', vetoPrepare: true);

      await expectLater(
        TomTransactionManager.runInTransaction((txn) async {
          await txn.registerParticipant(vetoer);
          return 'the body result';
        }),
        throwsA(
          isA<TomTransactionException>().having(
            (e) => e.key,
            'key',
            'transaction_manager.run_in_transaction.commit_failed',
          ),
        ),
      );

      expect(vetoer.calls, ['start', 'prepare', 'rollback', 'end']);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('a release failure is a warning, not a failure of the body', () async {
      // The compromise the boolean forced and the result type removes. The work
      // committed; a connection did not come back. Throwing would tell the
      // caller its work did not happen when it did — and for a non-idempotent
      // operation that invites a retry which applies it twice.
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final result = await TomTransactionManager.runInTransaction((txn) async {
        await txn.registerParticipant(
          _RecordingParticipant('a', endResult: false),
        );
        return 'the body result';
      });

      expect(result, 'the body result');
      expect(output.messages.join('\n'), contains('did not release'));
    });

    test(
      'joins a transaction that is already running, and concludes nothing',
      () async {
        // The nesting contract the `isNew` half of `startTransaction` states,
        // reached through the helper. An inner call that opened a second,
        // isolated transaction would let the inner work commit while the outer
        // rolled back.
        final outer = _RecordingParticipant('outer');
        final inner = _RecordingParticipant('inner');

        final (txn, isNew) = TomTransactionManager.startTransaction();
        expect(isNew, isTrue);
        await txn.registerParticipant(outer);

        final seen = await TomTransactionManager.runInTransaction((
          joined,
        ) async {
          await joined.registerParticipant(inner);
          return joined;
        });

        expect(
          seen,
          same(txn),
          reason: 'the helper opened a second transaction',
        );
        expect(inner.calls, [
          'start',
        ], reason: 'the joined transaction was concluded by the helper');
        expect(txn.isRunning, isTrue);
        expect(TomTransactionManager.getCurrentTransaction(), same(txn));

        await txn.commitTransaction();
        expect(outer.calls, ['start', 'prepare', 'commit', 'end']);
        expect(inner.calls, ['start', 'prepare', 'commit', 'end']);
      },
    );

    test(
      'a throw inside a joined transaction is the opener\'s to answer',
      () async {
        // The other half of joining: the helper does not roll back a transaction
        // it does not own, because the opener may well intend to carry on with
        // the participants it has.
        final (txn, _) = TomTransactionManager.startTransaction();
        final p = _RecordingParticipant('a');
        await txn.registerParticipant(p);

        await expectLater(
          TomTransactionManager.runInTransaction((_) async {
            throw StateError('the inner work failed');
          }),
          throwsA(isA<StateError>()),
        );

        expect(txn.isRunning, isTrue);
        expect(p.calls, ['start']);
        expect(TomTransactionManager.getCurrentTransaction(), same(txn));

        await txn.rollbackTransaction();
      },
    );

    test('establishes a scope when the flow has none', () async {
      // Off the request path there is no scope, and the fallback is shared by
      // every flow in the process. The helper forks one for the same reason a
      // transactional endpoint does: the failure it prevents — one flow
      // concluding another's transaction — is silent.
      expect(TomTransactionManager.hasTransactionScope, isFalse);

      final inScope = await TomTransactionManager.runInTransaction(
        (_) async => TomTransactionManager.hasTransactionScope,
      );

      expect(inScope, isTrue);
      expect(TomTransactionManager.hasTransactionScope, isFalse);
    });

    test('opens read-only when asked, and only when it opens', () async {
      final opened = await TomTransactionManager.runInTransaction(
        (txn) async => txn.isReadOnly,
        isReadOnly: true,
      );
      expect(opened, isTrue);

      // Joined: the flag belongs to the transaction that was opened, exactly as
      // `startTransaction` documents.
      final (txn, _) = TomTransactionManager.startTransaction();
      addTearDown(() => txn.rollbackTransaction());
      final joined = await TomTransactionManager.runInTransaction(
        (t) async => t.isReadOnly,
        isReadOnly: true,
      );
      expect(joined, isFalse);
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
      'doc/api/api_summary_transactions.md',
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
