/// Connection-free tests for the cluster hardening of the relational scheduler
/// (CSEXC2).
///
/// Six questions, none of which a live database can be made to ask reliably:
///
///  * **the ambiguous commit** — what a node does when the answer to its claim
///    is lost rather than negative. Reproducing it against a real server means
///    severing a socket at a chosen instant; against a scripted data source it
///    is one line, and the case under test is the *classification*, not the
///    network;
///  * **the failed-node formula** — pure arithmetic over three instants,
///    including the case that is easiest to omit, a stalled node accusing its
///    peers of its own outage;
///  * **opt-in recovery** — which of two `UPDATE`s the store issues for an
///    interrupted run. The behaviour is in the choice, and the choice is
///    visible in the statement;
///  * **the roll call as an accelerator** — that a roll call which is *itself*
///    broken cannot break recovery. A live server can be stopped, but it cannot
///    be asked to fail one of the four roll-call calls and answer the other
///    three; a throwing collaborator can;
///  * **the wiring guards** — the named-data-source lookups and the payload
///    encoder, all of which refuse before any statement is issued;
///  * **the contended branches of a lease acquire** — including the one a live
///    server cannot be asked for at all: a `forget()` landing between the
///    insert and the read. Scripting the two answers takes two lines, where
///    arranging the interleaving against a real connection is not something a
///    test can arrange at all.
///
/// The round trips these decisions ride on — that `started_at` survives the
/// column, that the roll-call table really is one row per node — are asserted
/// against a live server in `scheduling_db_test.dart`.
library;

import 'dart:collection';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// ===========================================================================
// A scripted data source
// ===========================================================================

/// A [TomDataSource] that answers from a script instead of from a server.
///
/// It parses no SQL and enforces no constraints: it hands back the queued answer
/// for each call in order and records what it was asked. That is enough, because
/// every behaviour under test here is a decision the *store* makes about an
/// answer it was given — and it lets a claim fail in transport, which is the one
/// thing a real server will not do on request.
///
/// Only the two execution methods are implemented; [noSuchMethod] makes anything
/// else a loud test bug rather than a silent `null`.
class _ScriptedDataSource implements TomDataSource {
  /// What each successive `executeQuery` does: a `List` of rows to return, or
  /// any other object to throw.
  final Queue<Object> queryAnswers = Queue();

  /// What each successive `executeCommand` does: a `BigInt` to return, or any
  /// other object to throw.
  final Queue<Object> commandAnswers = Queue();

  /// Every command issued, in order, with the parameters it was bound with.
  final List<String> commands = [];

  /// The bound parameters of every command issued, in order.
  final List<Map<String, dynamic>?> commandParameters = [];

  /// Every query issued, in order.
  final List<String> queries = [];

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    commands.add(command);
    commandParameters.add(params);
    if (commandAnswers.isEmpty) return BigInt.one;
    final answer = commandAnswers.removeFirst();
    if (answer is BigInt) return answer;
    throw answer;
  }

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    queries.add(command);
    if (queryAnswers.isEmpty) return <T>[];
    final answer = queryAnswers.removeFirst();
    // `cast` rather than a `is List<T>` test: a `[_row(...)]` literal is a
    // `List<Object>`, so the type test would be false and every scripted row
    // would be thrown instead of returned.
    if (answer is List) return answer.cast<T>();
    throw answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The scripted data source was asked for '
    '${invocation.memberName}, which no test needs. Implement it here if '
    'that changes.',
  );
}

/// A queue row in whatever state a test needs it in.
TomJobRunRow _row({
  String id = 'run-1',
  String jobName = 'job',
  required DateTime scheduledFor,
  TomJobRunState state = TomJobRunState.pending,
  String? claimedBy,
  DateTime? claimedAt,
  int claimToken = 0,
  DateTime? startedAt,
}) => TomJobRunRow()
  ..id = id
  ..jobName = jobName
  ..scheduledFor = sqlInstant(scheduledFor)
  ..runAt = sqlInstant(scheduledFor)
  ..state = state.name
  ..attempt = 1
  ..claimedBy = claimedBy
  ..claimedAt = claimedAt == null ? null : sqlInstant(claimedAt)
  ..claimToken = claimToken
  ..startedAt = startedAt == null ? null : sqlInstant(startedAt);

/// A lease row in whatever state a test needs it in.
///
/// [acquiredAt] and [expiresAt] are both required because the pair *is* the
/// state under test: whether the row reads as live or lapsed is what decides
/// which of `acquire`'s two contended branches runs.
TomLeaseRow _leaseRow({
  String resource = 'resource-1',
  String owner = 'node-a',
  int token = 7,
  required DateTime acquiredAt,
  required DateTime expiresAt,
  bool released = false,
  int version = 3,
}) => TomLeaseRow()
  ..resource = resource
  ..owner = owner
  ..token = token
  ..acquiredAt = sqlInstant(acquiredAt)
  ..expiresAt = sqlInstant(expiresAt)
  ..released = released ? 1 : 0
  ..version = version;

/// A transport-level failure, wrapped the way the MariaDB driver wraps one.
Object _transportFailure([String message = 'socket closed']) => TomException(
  'error.result_processing.executecommand_failed',
  'ExecuteCommand failed',
  rootException: MySQLClientException(message),
);

/// A failure the server itself reported.
Object _serverFailure([int code = 1213]) => TomException(
  'error.result_processing.executecommand_failed',
  'ExecuteCommand failed',
  rootException: MySQLServerException('deadlock found', code),
);

/// A roll call whose chosen calls throw instead of answering.
///
/// Each of the three methods [TomSqlJobStore.recoverAbandoned] touches can be
/// made to fail on its own, because the property under test is that *any single*
/// broken call still leaves recovery working — a stub that failed all three at
/// once would prove only that the first guard exists.
class _BrokenNodes extends TomSqlSchedulerNodes {
  _BrokenNodes({
    required TomDataSource datasource,
    this.onCheckIn = false,
    this.onFailedNodes = false,
    this.onForget = false,
    this.failed = const [],
  }) : super(datasource, nodeId: 'node-here', createSchema: false);

  /// Whether the liveness announcement fails.
  final bool onCheckIn;

  /// Whether reading the roll call fails.
  final bool onFailedNodes;

  /// Whether dropping a recovered peer from the roll call fails.
  final bool onForget;

  /// What [failedNodes] reports when it is not made to throw.
  final List<TomSchedulerNode> failed;

  /// The peers [forget] was asked to drop, in order.
  final List<String> forgotten = [];

  @override
  Future<void> checkIn(DateTime now) async {
    if (onCheckIn) throw StateError('roll call unreachable');
  }

  @override
  Future<List<TomSchedulerNode>> failedNodes(DateTime now) async {
    if (onFailedNodes) throw StateError('roll call unreadable');
    return failed;
  }

  @override
  Future<void> forget(String nodeId) async {
    forgotten.add(nodeId);
    if (onForget) throw StateError('roll call not writable');
  }
}

void main() {
  final at = DateTime.utc(2026, 5, 1, 12);

  // =========================================================================
  // GAP 1 — the claim whose answer was lost
  // =========================================================================

  group('a claim whose answer is lost', () {
    late _ScriptedDataSource datasource;
    late TomSqlJobStore store;

    setUp(() {
      datasource = _ScriptedDataSource();
      // createSchema: false so the script describes only the statements under
      // test; a DDL call at the front would shift every queued answer by one.
      store = TomSqlJobStore(datasource, createSchema: false);
    });

    /// Scripts the candidate scan, then the claim's failure.
    void scriptClaimFailing(Object failure) {
      datasource.queryAnswers.add([_row(scheduledFor: at)]);
      datasource.commandAnswers.add(failure);
    }

    test('a failure the server reported is definitive and propagates', () async {
      // The server answered, so the row is untouched and there is nothing to
      // re-read. Re-reading anyway would be harmless but dishonest: it would
      // treat a known outcome as an unknown one, and hide real errors behind a
      // recheck that always says "not claimed".
      scriptClaimFailing(_serverFailure());

      await expectLater(
        store.claimDue(at, 'node-a'),
        throwsA(isA<TomException>()),
      );
      expect(
        datasource.queries,
        hasLength(1),
        reason: 'a definite failure must not trigger a recheck',
      );
    });

    test('a transport failure that had committed is claimed after all', () async {
      // The claim reached the server and committed; only the acknowledgement was
      // lost. Reporting this as a loss is the bug: the run would sit `running`,
      // owned by a node that believes it owns nothing, until the lease expired.
      scriptClaimFailing(_transportFailure());
      datasource.queryAnswers.add([
        _row(
          scheduledFor: at,
          state: TomJobRunState.running,
          claimedBy: 'node-a',
          claimedAt: at,
          // The scanned candidate was at 0, so this call's compare-and-set would
          // have written 1. The row carrying 1 is what says it committed.
          claimToken: 1,
        ),
      ]);

      final claimed = await store.claimDue(at, 'node-a');

      expect(claimed, hasLength(1));
      expect(claimed.single.owner, 'node-a');
      expect(claimed.single.token, 1);
      expect(claimed.single.run.claimedBy, 'node-a');
      expect(claimed.single.run.state, TomJobRunState.running);
    });

    test(
      'a transport failure that had not committed leaves the run available',
      () async {
        scriptClaimFailing(_transportFailure());
        datasource.queryAnswers.add([_row(scheduledFor: at)]);

        // Not an error: the run is still `pending`, so the next pass — this node's
        // or a peer's — will offer it again.
        expect(await store.claimDue(at, 'node-a'), isEmpty);
      },
    );

    test("a peer's claim is not mistaken for ours", () async {
      scriptClaimFailing(_transportFailure());
      datasource.queryAnswers.add([
        _row(
          scheduledFor: at,
          state: TomJobRunState.running,
          claimedBy: 'node-b',
          claimedAt: at,
          claimToken: 1,
        ),
      ]);

      expect(await store.claimDue(at, 'node-a'), isEmpty);
    });

    test('an earlier claim of our own is not mistaken for this one', () async {
      // Same owner, and — because both passes scanned the row at the same token
      // — the same next token too. Neither identifies this write on its own; the
      // claim stamp does, because two passes of one node do not share a tick.
      // Reading the older one as proof would dispatch the run a second time.
      scriptClaimFailing(_transportFailure());
      datasource.queryAnswers.add([
        _row(
          scheduledFor: at,
          state: TomJobRunState.running,
          claimedBy: 'node-a',
          claimedAt: at.subtract(const Duration(minutes: 5)),
          claimToken: 1,
        ),
      ]);

      expect(await store.claimDue(at, 'node-a'), isEmpty);
    });

    test(
      'a run that vanished between the scan and the recheck is not claimed',
      () async {
        scriptClaimFailing(_transportFailure());
        datasource.queryAnswers.add(<Object>[]);

        expect(await store.claimDue(at, 'node-a'), isEmpty);
      },
    );

    test('a recheck that also fails surfaces the original failure', () async {
      final original = _transportFailure('the original break');
      scriptClaimFailing(original);
      datasource.queryAnswers.add(_transportFailure('and the recheck too'));

      // Still blind, so the honest answer is the failure that started it. The
      // lease timeout remains the backstop if the claim did land.
      await expectLater(store.claimDue(at, 'node-a'), throwsA(same(original)));
    });
  });

  // =========================================================================
  // The claim fence — what the statements actually say
  //
  // The behaviour these statements produce is asserted against a real server by
  // the shared kernel contract in `scheduling_db_test.dart`. What is checked
  // here is the thing a fake cannot enforce and a green contract run would not
  // notice: that the conditions are *in the SQL* and bound to the ticket. A
  // dropped conjunct only ever widens what a statement matches, so it fails
  // nothing until two nodes race.
  // =========================================================================

  group('the claim fence', () {
    late _ScriptedDataSource datasource;
    late TomSqlJobStore store;

    setUp(() {
      datasource = _ScriptedDataSource();
      store = TomSqlJobStore(datasource, createSchema: false);
    });

    test('a claim is a compare-and-set on the token it scanned', () async {
      datasource.queryAnswers.add([_row(scheduledFor: at, claimToken: 3)]);

      final claim = (await store.claimDue(at, 'node-a')).single;

      expect(datasource.commands.single, contains('claim_token = :next'));
      expect(
        datasource.commands.single,
        contains('AND claim_token = :current'),
      );
      expect(datasource.commandParameters.single, containsPair('current', 3));
      expect(datasource.commandParameters.single, containsPair('next', 4));
      // The ticket carries what the statement wrote, so the fence it presents to
      // every later transition is the value now in the row.
      expect(claim.token, 4);
      expect(claim.run.claimToken, 4);
    });

    test('every transition out of a claim is bound to the ticket', () async {
      datasource.queryAnswers.add([_row(scheduledFor: at, claimToken: 3)]);
      final claim = (await store.claimDue(at, 'node-a')).single;
      datasource.commands.clear();
      datasource.commandParameters.clear();

      await store.markStarted(claim, at);
      await store.renewClaim(claim, at);
      await store.release(claim);
      await store.complete(claim, at);
      await store.fail(claim, 'boom', at);
      await store.fail(claim, 'boom', at, retryAt: at);

      expect(datasource.commands, hasLength(6));
      for (var i = 0; i < datasource.commands.length; i++) {
        final sql = datasource.commands[i];
        expect(sql, contains('state = :running'), reason: sql);
        expect(sql, contains('claimed_by = :owner'), reason: sql);
        expect(sql, contains('claim_token = :token'), reason: sql);
        expect(
          datasource.commandParameters[i],
          containsPair('owner', 'node-a'),
        );
        expect(datasource.commandParameters[i], containsPair('token', 4));
      }
    });

    test('a released claim leaves the token where it is', () async {
      // Resetting it would restart the counter for the next holder, and a token
      // that repeats is not a fence. The next claim raises it instead.
      datasource.queryAnswers.add([_row(scheduledFor: at, claimToken: 3)]);
      final claim = (await store.claimDue(at, 'node-a')).single;
      datasource.commands.clear();

      await store.release(claim);

      final sql = datasource.commands.single;
      final assignments = sql.substring(0, sql.indexOf('WHERE'));
      expect(assignments, isNot(contains('claim_token')));
      expect(sql, contains('AND claim_token = :token'));
    });
  });

  group('classifying a failed write', () {
    test('a server-reported error is definitive', () {
      expect(
        classifySqlFailure(MySQLServerException('duplicate key', 1062)),
        TomSqlFailureMode.definite,
      );
    });

    test('a driver-side error is ambiguous', () {
      expect(
        classifySqlFailure(MySQLClientException('socket closed')),
        TomSqlFailureMode.ambiguous,
      );
      expect(
        classifySqlFailure(MySQLProtocolException('bad packet')),
        TomSqlFailureMode.ambiguous,
      );
    });

    test('the verdict is found through the wrapping', () {
      // The driver's exception arrives inside a MariadbDatasourceException, so a
      // classifier that only looked at the top of the chain would call every
      // failure ambiguous — including the ones it can be sure about.
      expect(classifySqlFailure(_serverFailure()), TomSqlFailureMode.definite);
      expect(
        classifySqlFailure(_transportFailure()),
        TomSqlFailureMode.ambiguous,
      );
    });

    test('anything unrecognised is ambiguous', () {
      // The default is the safe direction, and deliberately so: the set of
      // transport failures is open-ended, the set of "the server answered" is
      // not. Guessing "ambiguous" costs one SELECT; guessing "definite" costs an
      // abandoned run.
      expect(
        classifySqlFailure(const SocketException('reset by peer')),
        TomSqlFailureMode.ambiguous,
      );
      expect(
        classifySqlFailure(StateError('connection closed')),
        TomSqlFailureMode.ambiguous,
      );
      expect(classifySqlFailure(null), TomSqlFailureMode.ambiguous);
    });

    test('the cause chain is enumerable for logging', () {
      final causes = sqlFailureCauses(_serverFailure(1205)).toList();
      expect(causes.first, isA<TomException>());
      expect(causes.last, isA<MySQLServerException>());
    });
  });

  // =========================================================================
  // GAP 2 — the failed-node formula
  // =========================================================================

  group('the failed-node formula', () {
    TomSchedulerNode peer({
      required Duration silentFor,
      Duration interval = const Duration(seconds: 30),
      String nodeId = 'node-b',
    }) => TomSchedulerNode(
      nodeId: nodeId,
      checkinAt: at.subtract(silentFor),
      checkinInterval: interval,
    );

    bool failed(
      TomSchedulerNode node, {
      Duration selfSilentFor = Duration.zero,
    }) => isSchedulerNodeFailed(
      peer: node,
      now: at,
      lastSelfCheckin: at.subtract(selfSilentFor),
    );

    test('a peer inside its own interval is alive', () {
      expect(failed(peer(silentFor: const Duration(seconds: 20))), isFalse);
    });

    test('a peer past its interval plus the slack has failed', () {
      // 30 s interval + 7.5 s slack: 37 s is still grace, 38 s is not.
      expect(failed(peer(silentFor: const Duration(seconds: 37))), isFalse);
      expect(failed(peer(silentFor: const Duration(seconds: 38))), isTrue);
    });

    test('a peer is judged by its own interval, not the accuser\'s', () {
      // The same 40 s of silence: damning for a node that promised to speak
      // every 2 s, unremarkable for one that promised every 5 minutes. Judging
      // by the accuser's cadence would make the verdict depend on who asked.
      final chatty = peer(
        silentFor: const Duration(seconds: 40),
        interval: const Duration(seconds: 2),
      );
      final quiet = peer(
        silentFor: const Duration(seconds: 40),
        interval: const Duration(minutes: 5),
      );
      expect(failed(chatty), isTrue);
      expect(failed(quiet), isFalse);
    });

    test('a node that was itself stalled does not accuse its peers', () {
      // THE guard. This process was descheduled for two minutes; every peer now
      // looks two minutes stale through no fault of its own. Without the
      // `now - myLastCheckin` term, waking up would mean declaring the whole
      // cluster dead and stealing its work — the outage turning destructive at
      // the moment it ends.
      final silent = peer(silentFor: const Duration(minutes: 2));
      expect(
        failed(silent),
        isTrue,
        reason: 'a healthy accuser would call this peer failed',
      );
      expect(
        failed(silent, selfSilentFor: const Duration(minutes: 2)),
        isFalse,
        reason: 'an accuser that missed the same window must not accuse',
      );
    });

    test('a stalled node still accuses a peer that is later than its outage', () {
      // The guard grants peers the accuser's own lateness — not amnesty. A peer
      // silent for ten minutes was already gone before this node stalled.
      expect(
        failed(
          peer(silentFor: const Duration(minutes: 10)),
          selfSilentFor: const Duration(minutes: 2),
        ),
        isTrue,
      );
    });

    test('the failure instant is the sum the formula names', () {
      // Spelled out once, so a future edit that quietly drops a term fails here
      // rather than in a cluster.
      expect(
        schedulerNodeFailedAfter(
          peer: peer(
            silentFor: const Duration(seconds: 10),
            interval: const Duration(seconds: 30),
          ),
          now: at,
          lastSelfCheckin: at.subtract(const Duration(seconds: 90)),
        ),
        // checkinAt (now - 10s) + max(30s, 90s) + 7.5s
        at.add(const Duration(seconds: 87, milliseconds: 500)),
      );
    });
  });

  // =========================================================================
  // GAP 3 — recovery is opt-in for interrupted runs
  // =========================================================================

  group('recovering an abandoned run', () {
    late _ScriptedDataSource datasource;
    late TomSqlJobStore store;
    final later = at.add(const Duration(minutes: 30));

    setUp(() {
      datasource = _ScriptedDataSource();
      store = TomSqlJobStore(datasource, createSchema: false);
    });

    void scriptStaleRun({required bool started}) {
      datasource.queryAnswers.add([
        _row(
          scheduledFor: at,
          state: TomJobRunState.running,
          claimedBy: 'node-that-died',
          claimedAt: at,
          startedAt: started ? at : null,
        ),
      ]);
    }

    test('a run claimed but never started goes back to the queue', () async {
      // Nothing executed, so nothing can repeat: the opt-in does not apply and
      // is not consulted.
      scriptStaleRun(started: false);

      final recovered = await store.recoverAbandoned(
        later,
        const Duration(minutes: 15),
        requestsRecovery: (_) => false,
      );

      expect(recovered.single.state, TomJobRunState.pending);
      expect(
        datasource.commandParameters.single!['pending'],
        TomJobRunState.pending.name,
      );
    });

    test(
      'an interrupted run goes back to the queue when its job asks',
      () async {
        scriptStaleRun(started: true);

        final recovered = await store.recoverAbandoned(
          later,
          const Duration(minutes: 15),
          requestsRecovery: (_) => true,
        );

        expect(recovered.single.state, TomJobRunState.pending);
      },
    );

    test('an interrupted run is written off when its job does not', () async {
      // The default, and the conservative one: re-running a job that was halfway
      // through repeats whatever it had already done. The run becomes terminally
      // failed with the explanation, because an operator has to be able to see
      // that the framework made this call.
      scriptStaleRun(started: true);

      final recovered = await store.recoverAbandoned(
        later,
        const Duration(minutes: 15),
        requestsRecovery: (_) => false,
      );

      final run = recovered.single;
      expect(run.state, TomJobRunState.failed);
      expect(run.completedAt, later);
      expect(run.lastError, TomJobStore.recoveryDeclinedError);
      expect(
        datasource.commandParameters.single!['error'],
        TomJobStore.recoveryDeclinedError,
      );
    });

    test('with no predicate an interrupted run is still re-queued', () async {
      // A store asked in isolation cannot see the job registry, so it cannot
      // answer the question; recovering is the only answer it may give, and the
      // scheduler — which can see the registry — always supplies the predicate.
      scriptStaleRun(started: true);

      final recovered = await store.recoverAbandoned(
        later,
        const Duration(minutes: 15),
      );

      expect(recovered.single.state, TomJobRunState.pending);
    });

    test('a row a peer recovered first is not reported twice', () async {
      scriptStaleRun(started: false);
      datasource.commandAnswers.add(BigInt.zero);

      // The guarded UPDATE is still the arbitration: the loser of the race
      // changed nothing and must not claim it did.
      expect(
        await store.recoverAbandoned(later, const Duration(minutes: 15)),
        isEmpty,
      );
    });
  });

  // =========================================================================
  // GAP 4 — a broken roll call must not break recovery
  // =========================================================================

  /// The roll call is an accelerator: it finds a departed node's work within a
  /// poll interval instead of a lease timeout, and names the node. Every one of
  /// its calls is therefore expendable, and the assertion each test below makes
  /// is not "the exception was swallowed" but "the lease-expiry recovery that
  /// would have happened without a roll call at all still happens".
  group('a roll call that is itself broken', () {
    late _ScriptedDataSource datasource;
    final later = at.add(const Duration(minutes: 30));

    setUp(() => datasource = _ScriptedDataSource());

    /// The one stale run every test here expects back, found by lease expiry.
    void scriptStaleRun() {
      datasource.queryAnswers.add([
        _row(
          scheduledFor: at,
          state: TomJobRunState.running,
          claimedBy: 'node-that-died',
          claimedAt: at,
        ),
      ]);
    }

    /// Runs recovery over a store wired to [nodes] and returns what came back.
    Future<List<TomJobRun>> recoverWith(_BrokenNodes nodes) => TomSqlJobStore(
      datasource,
      createSchema: false,
      nodes: nodes,
    ).recoverAbandoned(later, const Duration(minutes: 15));

    test('a check-in that throws still leaves the run recovered', () async {
      // The first roll-call call on the pass, and the one whose failure is most
      // tempting to let through: it is this node's own liveness, so a failure
      // here says something true and alarming. It still may not propagate —
      // the pass that announces liveness is the same pass that recovers work,
      // and losing the second to the first is the outcome the roll call exists
      // to avoid.
      scriptStaleRun();

      final recovered = await recoverWith(
        _BrokenNodes(datasource: datasource, onCheckIn: true),
      );

      expect(recovered.single.id, 'run-1');
      expect(recovered.single.state, TomJobRunState.pending);
    });

    test(
      'a roll call that cannot be read still leaves the run recovered',
      () async {
        scriptStaleRun();

        final recovered = await recoverWith(
          _BrokenNodes(datasource: datasource, onFailedNodes: true),
        );

        expect(recovered.single.id, 'run-1');
        expect(recovered.single.state, TomJobRunState.pending);
        expect(
          datasource.queries,
          hasLength(1),
          reason: 'an unreadable roll call names no peer, so no peer is read',
        );
      },
    );

    test('a peer whose work cannot be read is left to lease expiry', () async {
      // The roll call named a failed peer, but the follow-up read of that
      // peer's rows failed. The peer's *own* work is then unrecoverable on this
      // pass — but the runs the lease timeout already found must still come
      // back, and the next pass will try the peer again.
      scriptStaleRun();
      datasource.queryAnswers.add(StateError('peer read failed'));

      final recovered = await recoverWith(
        _BrokenNodes(
          datasource: datasource,
          failed: [
            TomSchedulerNode(
              nodeId: 'node-b',
              checkinAt: at,
              checkinInterval: const Duration(seconds: 30),
            ),
          ],
        ),
      );

      expect(recovered.single.id, 'run-1');
      expect(
        datasource.queries,
        hasLength(2),
        reason: 'the peer was asked about before the read failed',
      );
    });

    test('a peer that cannot be forgotten is still recovered from', () async {
      // The last call on the pass, after the work is already in hand. Letting
      // it through would discard a completed recovery over a bookkeeping
      // failure whose only consequence is that the same peer is reported again
      // next pass.
      scriptStaleRun();
      datasource.queryAnswers.add(<TomJobRunRow>[]);

      final nodes = _BrokenNodes(
        datasource: datasource,
        onForget: true,
        failed: [
          TomSchedulerNode(
            nodeId: 'node-b',
            checkinAt: at,
            checkinInterval: const Duration(seconds: 30),
          ),
        ],
      );
      final recovered = await recoverWith(nodes);

      expect(recovered.single.id, 'run-1');
      expect(nodes.forgotten, ['node-b']);
    });
  });

  // =========================================================================
  // GAP 5 — the wiring guards, which refuse before any statement
  // =========================================================================

  group('wiring that cannot work is refused up front', () {
    /// Matches the exception a named-data-source lookup raises for [key].
    Matcher refusesDatasource(String key) => throwsA(
      isA<TomServerException>()
          .having((e) => e.key, 'key', key)
          .having(
            (e) => e.parameters?['datasource'],
            'datasource',
            'no-such-datasource',
          ),
    );

    test('the job store refuses an unregistered data source', () {
      expect(
        () => TomSqlJobStore.named('no-such-datasource'),
        refusesDatasource('scheduling.store.unknown_datasource'),
      );
    });

    test('the lease lock refuses an unregistered data source', () {
      expect(
        () => TomSqlLeaseLock.named('no-such-datasource'),
        refusesDatasource('scheduling.lock.unknown_datasource'),
      );
    });

    test('the roll call refuses an unregistered data source', () {
      expect(
        () =>
            TomSqlSchedulerNodes.named('no-such-datasource', nodeId: 'node-a'),
        refusesDatasource('scheduling.nodes.unknown_datasource'),
      );
    });

    test(
      'a payload that is not JSON-encodable is refused before any statement',
      () async {
        // The encode happens while the bind map is being built, which is before
        // `executeCommand` is called — so the queue never sees a row it would
        // have to read back as unparseable. The scripted source proves it: it
        // records every statement, and records none.
        //
        // The exception is the kernel's, not this layer's: every store refuses
        // the same payloads under the same key, which is what lets a job be
        // developed against the memory store and deployed against this one.
        final datasource = _ScriptedDataSource();
        final store = TomSqlJobStore(datasource, createSchema: false);

        await expectLater(
          store.enqueue(
            TomJobRun(
              id: 'run-9',
              jobName: 'export',
              scheduledFor: at,
              runAt: at,
              payload: {'sink': Socket},
            ),
          ),
          throwsA(
            isA<TomScheduleException>()
                .having((e) => e.key, 'key', 'schedule.job.payload')
                .having((e) => e.parameters?['job'], 'job', 'export')
                .having((e) => e.parameters?['run'], 'run', 'run-9'),
          ),
        );

        expect(datasource.commands, isEmpty);
      },
    );
  });

  // =========================================================================
  // GAP 6 — the two contended branches of a lease acquire
  // =========================================================================

  group('an acquire that loses the insert', () {
    late _ScriptedDataSource datasource;
    late TomSqlLeaseLock lock;
    const ttl = Duration(minutes: 5);

    setUp(() {
      datasource = _ScriptedDataSource();
      lock = TomSqlLeaseLock(datasource, createSchema: false, clock: () => at);
      // `INSERT IGNORE` reporting no new row is the entry condition for both
      // branches below: the resource row already existed.
      datasource.commandAnswers.add(BigInt.zero);
    });

    test('a resource forgotten before the read is answered as not taken', () {
      // The insert says the row existed and the read says it does not. Only a
      // concurrent forget() produces that pair.
      datasource.queryAnswers.add(<Object>[]);

      expect(lock.acquire('resource-1', 'node-a', ttl), completion(isNull));
    });

    test('the vanished-row answer is given without a second attempt', () async {
      datasource.queryAnswers.add(<Object>[]);

      await lock.acquire('resource-1', 'node-a', ttl);

      // One insert and one read, and nothing after them. Retrying is the
      // caller's job — `TomScheduler` hands the claim back without charging an
      // attempt and the run is offered again on the next tick — so a second
      // pass from in here would spin against a caller that is deleting the
      // resource. Pinned by count, because the comment beside that `return`
      // once described a retry the method has never performed.
      expect(datasource.commands, hasLength(1));
      expect(datasource.queries, hasLength(1));
    });

    test('extension by the live holder is guarded on the token, not the '
        'expiry', () async {
      datasource.queryAnswers.add([
        _leaseRow(
          acquiredAt: at,
          expiresAt: at.add(const Duration(minutes: 1)),
        ),
      ]);

      final lease = await lock.acquire('resource-1', 'node-a', ttl);

      // The token is kept, not bumped: the holder is already working under it.
      expect(lease?.token, 7);
      final extension = datasource.commands.last;
      expect(extension, contains('token = :token'));
      expect(extension, contains('owner = :owner'));
      expect(extension, contains('released = 0'));
      // Liveness was settled by the read that chose this branch, so the guard
      // carries no expiry predicate. It does not need one: a lease taken over
      // in between carries a higher token and this statement matches nothing.
      expect(extension, isNot(contains('expires_at > :now')));
    });
  });

  group('a renewal', () {
    test('is guarded on the expiry, having no read to lean on', () async {
      final datasource = _ScriptedDataSource();
      final lock = TomSqlLeaseLock(
        datasource,
        createSchema: false,
        clock: () => at,
      );

      await lock.renew(
        TomLease(
          resource: 'resource-1',
          owner: 'node-a',
          token: 7,
          acquiredAt: at,
          expiresAt: at.add(const Duration(minutes: 1)),
        ),
        const Duration(minutes: 5),
      );

      // The counterpart of the extension test above: `expires_at > :now` lives
      // here, where nothing has read the row, and that is what makes a lapsed
      // lease unrenewable without a separate round trip.
      expect(datasource.commands.single, contains('expires_at > :now'));
      expect(datasource.queries, isEmpty);
    });
  });
}
