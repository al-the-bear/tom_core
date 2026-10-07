/// Measures what the end phase of a transaction conclusion costs, sequential
/// as the coordinator drives it against `Future.wait`.
///
/// ```bash
/// dart run tool/bench_transaction_end_phase.dart
/// ```
///
/// The participants release exactly as `MariaDbDatasource.endTransaction`
/// does — they complete the connection's release completer and report `true`,
/// issuing no statement — so the numbers are the coordinator's own overhead
/// for every participant this package ships. A participant whose release is a
/// round trip would change the answer; rerun this against one before deciding
/// the end phase should be parallel. `doc/transactions.md`, *Sequential by
/// design*, records the last measurement.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

/// Releases as `MariaDbDatasource.endTransaction` does.
class _Releasing extends TomTransactionParticipant {
  _Releasing(this.id);
  final String id;
  Completer<void>? _released;

  @override
  String getParticipantId() => id;
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    _released = Completer<void>();
    return true;
  }

  @override
  Future<bool> prepare() async => true;
  @override
  Future<bool> commit() async => true;
  @override
  Future<bool> rollback() async => true;
  @override
  Future<bool> endTransaction() async {
    final r = _released;
    _released = null;
    r?.complete();
    return true;
  }
}

Future<void> main() async {
  const rounds = 20000;
  for (final n in [1, 2, 4, 8, 16]) {
    final ps = [for (var i = 0; i < n; i++) _Releasing('p$i')];
    Future<void> arm() async {
      for (final p in ps) {
        await p.startTransaction(TomTransactionManager.startTransaction().$1);
      }
    }

    // Warm up both shapes.
    for (var i = 0; i < 2000; i++) {
      await arm();
      for (final p in ps) {
        await p.endTransaction();
      }
      await arm();
      await Future.wait([for (final p in ps) p.endTransaction()]);
    }

    var seq = Duration.zero, par = Duration.zero;
    final sw = Stopwatch();
    for (var i = 0; i < rounds; i++) {
      await arm();
      sw
        ..reset()
        ..start();
      for (final p in ps) {
        await p.endTransaction();
      }
      sw.stop();
      seq += sw.elapsed;
      await arm();
      sw
        ..reset()
        ..start();
      await Future.wait([for (final p in ps) p.endTransaction()]);
      sw.stop();
      par += sw.elapsed;
    }

    // A whole committed transaction through the coordinator, end phase
    // included, for scale.
    final whole = Stopwatch()..start();
    for (var i = 0; i < rounds; i++) {
      final (txn, _) = TomTransactionManager.startTransaction();
      for (final p in ps) {
        await txn.registerParticipant(p);
      }
      await txn.commitTransaction();
    }
    whole.stop();

    String us(Duration d) =>
        (d.inMicroseconds / rounds).toStringAsFixed(2).padLeft(6);
    print(
      'n=${n.toString().padLeft(2)}  end sequential ${us(seq)} us  '
      'end Future.wait ${us(par)} us  whole commit ${us(whole.elapsed)} us',
    );
  }
}
