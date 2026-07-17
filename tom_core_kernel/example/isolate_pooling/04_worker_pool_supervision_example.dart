/// Worker Pool Liveness Supervision Example
///
/// This example demonstrates the opt-in liveness supervision of
/// [TomWorkerPool]. Without supervision, a command dispatched to a worker
/// whose isolate dies (a crash, `Isolate.kill`, or an out-of-memory kill)
/// would hang forever on its completer. With supervision enabled the pool:
///
/// - detects the death via [Isolate.addOnExitListener],
/// - fails the in-flight command with a [TomWorkerDiedException]
///   (rather than re-dispatching it — the command may have had side effects
///   before the isolate died), and
/// - respawns a replacement worker so the pool returns to full capacity.
///
/// Key concepts covered:
/// - Enabling supervision with `healthCheckInterval`
/// - Observing a [TomWorkerDiedException] for the in-flight command
/// - Confirming the pool recovers and keeps serving requests
library;

import 'dart:isolate';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Command Definitions
// ============================================================================

/// A normal compute command used to confirm the pool works before and after a
/// worker death.
class AddCommand extends TomCommand {
  final int a;
  final int b;

  AddCommand(this.a, this.b);

  @override
  Future<Object?> execute() async => a + b;
}

/// A command that kills its own worker isolate mid-execution.
///
/// This simulates an unexpected worker death: the isolate terminates before it
/// can answer, so the awaiting request never receives a response.
class CrashCommand extends TomCommand {
  @override
  Future<Object?> execute() async {
    Isolate.current.kill(priority: Isolate.immediate);
    // Unreachable once the kill takes effect; keeps the body well-typed.
    await Future<void>.delayed(const Duration(seconds: 60));
    return 'never';
  }
}

// ============================================================================
// Example Code
// ============================================================================

Future<void> run() async {
  print('=== 04: Worker Pool Liveness Supervision Example ===\n');

  final context = TomWorkerContext(
    defaultTomEnvironment,
    platformLinux,
    [],
    'SupervisedWorker',
  );

  // -------------------------------------------------------------------------
  // 1. Create a supervised pool (opt-in via healthCheckInterval).
  // -------------------------------------------------------------------------
  print('1. Creating a supervised pool of 2 workers:');
  final pool = await TomWorkerPool.withSize(
    2,
    context,
    healthCheckInterval: const Duration(milliseconds: 50),
  );
  print('   isSupervised = ${pool.isSupervised}');
  print('   workerCount  = ${pool.workerCount}\n');

  // -------------------------------------------------------------------------
  // 2. Normal work succeeds.
  // -------------------------------------------------------------------------
  print('2. Executing a normal command:');
  final before = await pool.execute(AddCommand(2, 3)) as int;
  print('   2 + 3 = $before\n');

  // -------------------------------------------------------------------------
  // 3. A worker dies mid-command — the request FAILS instead of hanging.
  // -------------------------------------------------------------------------
  print('3. Dispatching a command that kills its worker isolate:');
  var sawDeath = false;
  try {
    await pool.execute(CrashCommand());
  } on TomWorkerDiedException catch (e) {
    sawDeath = true;
    print('   Caught TomWorkerDiedException (as expected):');
    print('   -> ${e.defaultUserMessage}\n');
  }

  // -------------------------------------------------------------------------
  // 4. The pool respawns a replacement; wait for full capacity.
  // -------------------------------------------------------------------------
  print('4. Waiting for the pool to respawn a replacement worker:');
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (pool.workerCount < 2 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  print('   workerCount = ${pool.workerCount}\n');

  // -------------------------------------------------------------------------
  // 5. The recovered pool keeps serving requests.
  // -------------------------------------------------------------------------
  print('5. Executing work on the recovered pool:');
  final after = await pool.execute(AddCommand(20, 22)) as int;
  print('   20 + 22 = $after\n');

  pool.close();
  print('   Pool closed. Recovery complete.\n');

  // ---- Self-checks (run under `dart run --enable-asserts`) -----------------
  assert(before == 5, 'normal command before death should compute 2 + 3');
  assert(sawDeath, 'the in-flight command must fail with TomWorkerDiedException');
  assert(after == 42, 'recovered pool should compute 20 + 22');
}
