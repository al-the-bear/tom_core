/// Worker Pool Liveness Supervision Example
///
/// Demonstrates the opt-in liveness supervision of [TomWorkerPool]. When a
/// worker isolate dies unexpectedly (a crash, `Isolate.kill`, or an
/// out-of-memory kill), an unsupervised pool would hang forever on the
/// in-flight command's completer. A supervised pool instead detects the death,
/// fails the in-flight command with a [TomWorkerDiedException], and respawns a
/// replacement worker to restore capacity.
///
/// Key concepts covered:
/// - Enabling supervision with `healthCheckInterval`
/// - Observing a [TomWorkerDiedException] for the in-flight command
/// - Confirming the pool recovers and keeps serving requests
library;

import 'dart:isolate';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A normal compute command used to confirm the pool works before and after a
/// worker death.
class AddCommand extends TomCommand {
  final int a;
  final int b;

  AddCommand(this.a, this.b);

  @override
  Future<Object?> execute() async => a + b;
}

/// A command that kills its own worker isolate mid-execution, simulating an
/// unexpected worker death.
class CrashCommand extends TomCommand {
  @override
  Future<Object?> execute() async {
    Isolate.current.kill(priority: Isolate.immediate);
    // Unreachable once the kill takes effect; keeps the body well-typed.
    await Future<void>.delayed(const Duration(seconds: 60));
    return 'never';
  }
}

/// Run the liveness supervision example.
Future<void> run() async {
  final context = TomWorkerContext(
    defaultTomEnvironment,
    platformLinux,
    [],
    'SupervisedWorker',
  );

  // Opt in to supervision via healthCheckInterval.
  final pool = await TomWorkerPool.withSize(
    2,
    context,
    healthCheckInterval: const Duration(milliseconds: 50),
  );
  print('  Supervised pool created (isSupervised=${pool.isSupervised}, '
      'workers=${pool.workerCount})');

  // Normal work succeeds.
  final before = await pool.execute(AddCommand(2, 3)) as int;
  print('  Before death: 2 + 3 = $before');

  // A worker dies mid-command — the request FAILS instead of hanging.
  var sawDeath = false;
  try {
    await pool.execute(CrashCommand());
  } on TomWorkerDiedException {
    sawDeath = true;
    print('  In-flight command failed with TomWorkerDiedException (expected)');
  }

  // The pool respawns a replacement; wait for full capacity.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (pool.workerCount < 2 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  print('  Recovered: workerCount=${pool.workerCount}');

  // The recovered pool keeps serving requests.
  final after = await pool.execute(AddCommand(20, 22)) as int;
  print('  After recovery: 20 + 22 = $after');

  pool.close();

  assert(before == 5, 'normal command before death should compute 2 + 3');
  assert(sawDeath, 'the in-flight command must fail with TomWorkerDiedException');
  assert(after == 42, 'recovered pool should compute 20 + 22');
}
