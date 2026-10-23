/// A process that dies in the middle of a two-phase commit, for
/// `transaction_recovery_db_test.dart`.
///
/// `dart run test/fixtures/xa_recovery_probe.dart <settings json> <mode>`
/// registers two two-phase data sources (`xa_one`, `xa_two`) and a one-phase
/// one for the decision log (`decision_log`) from the settings, writes a row
/// through each two-phase source in one transaction, and exits with code 3:
///
///  * `after-decision` — during the commit phase, before any branch commits:
///    both branches are prepared and the decision is recorded;
///  * `before-decision` — during the prepare phase, after both branches
///    prepared: no decision is recorded.
///
/// Exiting drops the connections, as a crash does; the prepared branches
/// survive on the servers. Exit code 0 means the process was not stopped.
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'reflection_fixture.reflection.dart';

/// Ends the process when the coordinator reaches the phase it waits for.
class _Crash implements TomTransactionParticipant {
  _Crash({required this.inCommit});

  final bool inCommit;

  @override
  String getParticipantId() => 'probe.crash';

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async {
    if (!inCommit) exit(3);
    return true;
  }

  @override
  Future<bool> commit(TomTransaction transaction) async {
    exit(3);
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async => true;

  @override
  Future<bool> endTransaction(TomTransaction transaction) async => true;
}

Future<void> main(List<String> args) async {
  initializeReflection();
  final settings = (jsonDecode(args[0]) as Map).cast<String, dynamic>();
  final mode = args[1];
  await TomDataSourceInfo.initializeDatasourceInfo(settings);
  TomTransactionManager.decisionLog = TomSqlDecisionLog('decision_log');
  final one = TomDataSourceInfo.getDataSourceInfo('xa_one')!.datasource;
  final two = TomDataSourceInfo.getDataSourceInfo('xa_two')!.datasource;
  await TomTransactionManager.runInTransaction((tx) async {
    // Commit runs in enlistment order, so a crash in the commit phase is
    // enlisted first; prepare does too, so one in the prepare phase last.
    if (mode == 'after-decision') {
      await tx.registerParticipant(_Crash(inCommit: true));
    }
    for (final ds in [one, two]) {
      await tx.registerParticipant(ds as TomTransactionParticipant);
      await ds.executeCommand('INSERT INTO xr_note (text) VALUES (:text)', {
        'text': mode,
      });
    }
    if (mode == 'before-decision') {
      await tx.registerParticipant(_Crash(inCommit: false));
    }
  });
  exit(0);
}
