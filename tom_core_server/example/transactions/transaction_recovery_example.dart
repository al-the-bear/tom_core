// ignore_for_file: avoid_print
/// Executable example for the recovery of two-phase transactions in the
/// transactions module of `tom_core_server`.
///
/// A process that dies between the two phases of a two-phase commit leaves
/// its branches prepared: durable, holding their locks, and resolved by
/// nobody. The coordinator therefore records its decision — the transaction
/// id and its prepared branches — before the commit phase, and forgets it once
/// every branch committed; `TomTransactionRecovery.recover` commits the
/// branches a recorded decision names and rolls back the rest. This program
/// shows:
///
/// 1. a branch id naming the data source it was opened through and when, and
///    `tomSqlOwnsBranch` telling this data source's branches from another's;
/// 2. the coordinator recording the decision before the first commit, and
///    forgetting it once both branches committed;
/// 3. a decision that cannot be recorded is not taken: the transaction rolls
///    back;
/// 4. a recovery committing the decided branch, rolling back the undecided
///    one, leaving another data source's branch alone, and forgetting the
///    decision;
/// 5. a branch younger than `TomTransactionRecovery.minimumAge` left to the
///    process that may still be resolving it.
///
/// The participants and the data source are in memory, so it needs no
/// database. A deployment records decisions with `TomSqlDecisionLog` and
/// recovers the `mariadb_xa` and `postgresql_xa` data sources — see
/// "Recovering Prepared Branches" in `doc/transactions.md`.
///
/// Run with `dart run example/transactions/transaction_recovery_example.dart`.
/// Every step checks its own result and the run fails when one does not hold.
/// `test/transaction_recovery_test.dart` covers the same behaviour.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A branch id of the `orders` database at `db.internal:3306`, as the
/// two-phase drivers mint one.
String ordersBranch(int counter) => tomSqlBranchId(
  databaseName: 'orders',
  host: 'db.internal',
  port: 3306,
  processTag: '0a1b2c3d',
  counter: counter,
  maxBytes: 64,
);

/// A two-phase participant holding [branch]; [onCommit] runs while it
/// commits.
class Branch implements TomTransactionParticipant, TomPreparedBranchHolder {
  Branch(this.branch, {this.onCommit});

  final String branch;
  final Future<void> Function()? onCommit;
  final List<String> calls = [];

  @override
  String getParticipantId() => 'branch:$branch';

  @override
  String? preparedBranchOf(TomTransaction transaction) => branch;

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    calls.add('prepare');
    return true;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    calls.add('commit');
    await onCommit?.call();
    return true;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    calls.add('rollback');
    return true;
  }

  @override
  Future<bool> endTransaction(TomTransaction transaction) async => true;
}

/// A decision log whose database is unreachable.
class UnreachableLog implements TomTransactionDecisionLog {
  @override
  Future<void> recordCommit(String transactionId, List<String> branches) =>
      throw StateError('decision log unreachable');

  @override
  Future<void> forget(String transactionId) async {}

  @override
  Future<Map<String, Set<String>>> decisions() async => {};
}

/// The `orders` database after a crash: the branches it still holds
/// prepared, whatever process opened them.
class OrdersDatabase implements TomTwoPhaseRecoverable {
  OrdersDatabase(this.prepared);

  final Set<String> prepared;
  final List<String> committed = [];
  final List<String> rolledBack = [];

  @override
  String get recoveryLabel => 'orders@db.internal:3306';

  @override
  Future<List<String>> listPreparedBranches() async => [...prepared];

  @override
  bool ownsBranch(String branchId) => tomSqlOwnsBranch(
    branchId,
    databaseName: 'orders',
    host: 'db.internal',
    port: 3306,
  );

  @override
  DateTime? branchOpenedAt(String branchId) => tomSqlBranchOpenedAt(branchId);

  @override
  Future<void> commitPreparedBranch(String branchId) async {
    prepared.remove(branchId);
    committed.add(branchId);
  }

  @override
  Future<void> rollbackPreparedBranch(String branchId) async {
    prepared.remove(branchId);
    rolledBack.add(branchId);
  }
}

Future<void> main() async {
  // 1. A branch id names its data source and when it was opened, so a
  //    recovery can tell its own branches — and how old they are.
  final opened = DateTime.now().toUtc();
  final decided = ordersBranch(1);
  final foreign = tomSqlBranchId(
    databaseName: 'billing',
    host: 'db.internal',
    port: 3306,
    processTag: '0a1b2c3d',
    counter: 1,
    maxBytes: 64,
  );
  print('1. $decided');
  check(
    tomSqlOwnsBranch(
      decided,
      databaseName: 'orders',
      host: 'db.internal',
      port: 3306,
    ),
    'the branch belongs to the orders data source',
  );
  check(
    !tomSqlOwnsBranch(
      foreign,
      databaseName: 'orders',
      host: 'db.internal',
      port: 3306,
    ),
    "a billing branch is not the orders data source's",
  );
  check(
    tomSqlBranchOpenedAt(decided)!.difference(opened).inSeconds.abs() < 5,
    'the id says when the branch was opened',
  );

  // 2. The coordinator records the decision before the first commit and
  //    forgets it once every branch committed.
  final log = TomMemoryDecisionLog();
  TomTransactionManager.decisionLog = log;
  Map<String, Set<String>> seenDuringCommit = const {};
  final first = Branch(
    ordersBranch(2),
    onCommit: () async => seenDuringCommit = await log.decisions(),
  );
  final second = Branch(ordersBranch(3));
  late String transactionId;
  await TomTransactionManager.runInTransaction((tx) async {
    transactionId = tx.id;
    await tx.registerParticipant(first);
    await tx.registerParticipant(second);
  });
  print(
    '2. during commit: ${seenDuringCommit.length} decision, after: '
    '${(await log.decisions()).length}',
  );
  check(
    seenDuringCommit[transactionId]?.length == 2 &&
        seenDuringCommit[transactionId]!.containsAll([
          first.branch,
          second.branch,
        ]),
    'the decision named both prepared branches while they committed',
  );
  check((await log.decisions()).isEmpty, 'the decision was forgotten');

  // 3. A decision that cannot be recorded is not taken: the coordinator
  //    rolls back rather than commit what a recovery could not resolve.
  TomTransactionManager.decisionLog = UnreachableLog();
  final unrecorded = Branch(ordersBranch(4));
  var refused = false;
  try {
    await TomTransactionManager.runInTransaction(
      (tx) => tx.registerParticipant(unrecorded),
    );
  } on TomTransactionException catch (e) {
    refused = e.key == 'transaction_manager.run_in_transaction.commit_failed';
  }
  print('3. ${unrecorded.calls.join(', ')}');
  check(refused, 'the transaction was reported as not committed');
  check(
    unrecorded.calls.join(',') == 'prepare,rollback',
    'the prepared branch was rolled back, never committed',
  );
  TomTransactionManager.decisionLog = null;

  // 4. A process died after recording its decision for one branch; another
  //    branch was prepared by a transaction that never decided. A recovery,
  //    once both are older than the minimum age, commits the first, rolls back
  //    the second, leaves the billing branch alone and forgets the decision.
  final undecided = ordersBranch(5);
  final crashLog = TomMemoryDecisionLog();
  await crashLog.recordCommit('tx_dead', [decided]);
  final orders = OrdersDatabase({decided, undecided, foreign});
  final later = DateTime.now().toUtc().add(const Duration(minutes: 2));
  final report = await TomTransactionRecovery.recover(
    sources: [orders],
    log: crashLog,
    now: later,
  );
  print('4. $report');
  check(orders.committed.single == decided, 'the decided branch was committed');
  check(
    orders.rolledBack.single == undecided,
    'the undecided branch was rolled back',
  );
  check(
    orders.prepared.single == foreign,
    "another data source's branch was left alone",
  );
  check(
    report.forgotten.single == 'tx_dead' &&
        (await crashLog.decisions()).isEmpty,
    'the resolved decision was forgotten',
  );
  check(report.isClean, 'nothing failed');

  // 5. A branch younger than the minimum age may belong to a live process
  //    between its two phases: the recovery leaves it alone.
  final young = ordersBranch(6);
  final busy = OrdersDatabase({young});
  final soon = await TomTransactionRecovery.recover(
    sources: [busy],
    log: TomMemoryDecisionLog(),
  );
  print('5. too young: ${soon.tooYoung.length} of 1');
  check(soon.tooYoung.single == young, 'the young branch was left alone');
  check(
    busy.prepared.contains(young) && busy.rolledBack.isEmpty,
    'it is still prepared',
  );
}
