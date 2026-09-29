/// Worker Pool Example
///
/// This example demonstrates TomWorkerPool for managing multiple
/// worker isolates with automatic load distribution. Worker pools
/// are ideal for CPU-intensive parallel processing.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/isolate_pooling/02_worker_pool_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Command Definitions
// =============================================================================

/// A command that performs prime number checking.
class IsPrimeCommand extends TomCommand {
  final int number;

  IsPrimeCommand(this.number);

  @override
  Future<Object?> execute() async {
    if (number < 2) return false;
    if (number == 2) return true;
    if (number % 2 == 0) return false;

    for (int i = 3; i * i <= number; i += 2) {
      if (number % i == 0) return false;
    }
    return true;
  }
}

/// A command that counts primes up to a given number.
class CountPrimesCommand extends TomCommand {
  final int upTo;

  CountPrimesCommand(this.upTo);

  @override
  Future<Object?> execute() async {
    int count = 0;
    for (int n = 2; n <= upTo; n++) {
      if (_isPrime(n)) count++;
    }
    return count;
  }

  bool _isPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  }
}

/// A command that performs a task with a unique identifier.
class IdentifiedTaskCommand extends TomCommand {
  final int taskId;
  final int workAmount;

  IdentifiedTaskCommand(this.taskId, this.workAmount);

  @override
  Future<Object?> execute() async {
    int result = 0;
    for (int i = 0; i < workAmount; i++) {
      result += i;
    }
    return {'taskId': taskId, 'result': result};
  }
}

// =============================================================================
// EXAMPLE 1: Creating a worker pool
// =============================================================================

class WorkerPoolCreationExample {
  static int poolSize = 0;
  static int workersInPool = 0;
  static bool emptyPoolRejected = false;

  static Future<TomWorkerPool> example1CreatePool() async {
    final context = SampleWorkerContext(
      defaultTomEnvironment,
      platformLinux,
      [],
      'PoolWorker',
    );

    poolSize = 4;
    final pool = await TomWorkerPool.withSize(poolSize, context);
    workersInPool = pool.workerCount;

    // The size that matters is the one the pool actually started, not the one
    // it was asked for: a pool that came back short would still hand out
    // workers, just fewer of them, and only under load would that show.
    assert(
      workersInPool == poolSize,
      'The pool should hold every worker asked for',
    );
    assert(workersInPool == 4, 'Pool size should be 4');

    // A pool needs at least one worker. An empty one could never acquire a
    // worker, so every execute() would wait forever — withSize refuses at
    // construction, where the mistake actually is. A computed size such as
    // `numberOfProcessors - 1` reaches 0 on a single-core container.
    Object? sizeError;
    try {
      await TomWorkerPool.withSize(0, context);
    } on TomWorkerException catch (e) {
      sizeError = e;
    }
    emptyPoolRejected = sizeError != null;

    assert(
      emptyPoolRejected,
      'withSize(0, ...) should throw TomWorkerException',
    );

    return pool;
  }
}

// =============================================================================
// EXAMPLE 2: Executing commands through the pool
// =============================================================================

class PoolCommandExecutionExample {
  static Map<int, bool> primeResults = {};
  static bool allCommandsExecuted = false;

  static Future<void> example2ExecuteCommands(TomWorkerPool pool) async {
    final numbersToCheck = [97, 100, 127, 150, 199, 200];

    for (final num in numbersToCheck) {
      final isPrime = (await pool.execute(IsPrimeCommand(num))) as bool;
      primeResults[num] = isPrime;
    }

    allCommandsExecuted = primeResults.length == numbersToCheck.length;

    assert(primeResults[97] == true, '97 should be prime');
    assert(primeResults[100] == false, '100 should not be prime');
    assert(primeResults[127] == true, '127 should be prime');
    assert(primeResults[150] == false, '150 should not be prime');
    assert(primeResults[199] == true, '199 should be prime');
    assert(primeResults[200] == false, '200 should not be prime');
    assert(allCommandsExecuted, 'All commands should execute');
  }
}

// =============================================================================
// EXAMPLE 3: Parallel execution with Future.wait
// =============================================================================

class ParallelExecutionExample {
  static List<int> parallelResults = [];
  static int executionTimeMs = 0;
  static bool parallelExecutionComplete = false;

  static Future<void> example3ParallelExecution(TomWorkerPool pool) async {
    final ranges = [1000, 2000, 3000, 4000];
    final stopwatch = Stopwatch()..start();

    final parallelFutures = ranges.map(
      (n) async => pool.execute(CountPrimesCommand(n)),
    );
    final results = await Future.wait(parallelFutures);

    executionTimeMs = stopwatch.elapsedMilliseconds;
    parallelResults = results.cast<int>().toList();
    parallelExecutionComplete = parallelResults.length == ranges.length;

    // Expected prime counts: primes up to 1000=168, 2000=303, 3000=430, 4000=550
    assert(parallelResults[0] == 168, 'Primes up to 1000 should be 168');
    assert(parallelResults[1] == 303, 'Primes up to 2000 should be 303');
    assert(parallelResults[2] == 430, 'Primes up to 3000 should be 430');
    assert(parallelResults[3] == 550, 'Primes up to 4000 should be 550');
    assert(parallelExecutionComplete, 'Parallel execution should complete');
  }
}

// =============================================================================
// EXAMPLE 4: Work distribution across workers
// =============================================================================

class WorkDistributionExample {
  static List<Map<String, dynamic>> taskResults = [];
  static int taskCount = 0;
  static bool allTasksCompleted = false;

  static Future<void> example4WorkDistribution(TomWorkerPool pool) async {
    taskCount = 8;
    taskResults = [];

    // Execute tasks sequentially so each result is collected in task order.
    for (int i = 0; i < taskCount; i++) {
      final result = await pool.execute(IdentifiedTaskCommand(i, 10000));
      taskResults.add(result as Map<String, dynamic>);
    }

    allTasksCompleted = taskResults.length == taskCount;

    // Verify each task completed with correct ID
    for (int i = 0; i < taskCount; i++) {
      final result = taskResults.firstWhere(
        (r) => r['taskId'] == i,
        orElse: () => {},
      );
      assert(result.isNotEmpty, 'Task $i should have completed');
    }
    assert(allTasksCompleted, 'All tasks should complete');
  }
}

// =============================================================================
// EXAMPLE 5: Sequential vs parallel comparison
// =============================================================================

class SequentialVsParallelExample {
  static int sequentialTimeMs = 0;
  static int parallelTimeMs = 0;
  static bool parallelWasFaster = false;

  static Future<void> example5SequentialVsParallel(TomWorkerPool pool) async {
    final ranges = [500, 600, 700, 800];

    // Sequential execution
    final seqStopwatch = Stopwatch()..start();
    for (final n in ranges) {
      await pool.execute(CountPrimesCommand(n));
    }
    sequentialTimeMs = seqStopwatch.elapsedMilliseconds;

    // Parallel execution: fan the tasks out across the pool, then await all.
    final parStopwatch = Stopwatch()..start();
    final futures = ranges
        .map((n) => pool.execute(CountPrimesCommand(n)))
        .toList();
    await Future.wait(futures);
    parallelTimeMs = parStopwatch.elapsedMilliseconds;

    // Parallel should generally be faster with a pool
    parallelWasFaster = parallelTimeMs <= sequentialTimeMs;

    assert(sequentialTimeMs >= 0, 'Sequential time should be positive');
    assert(parallelTimeMs >= 0, 'Parallel time should be positive');
  }
}

// =============================================================================
// EXAMPLE 6: Pool cleanup
// =============================================================================

class PoolCleanupExample {
  static bool poolClosedSuccessfully = false;

  static Future<void> example6PoolCleanup(TomWorkerPool pool) async {
    // Give any pending operations a moment to settle before tearing down.
    await Future.delayed(Duration(milliseconds: 100));

    // close() shuts down every worker in the pool and cancels supervision.
    // The pool must not be reused afterwards.
    pool.close();

    // Dispatch after close fails fast instead of hanging on a free worker.
    Object? closedError;
    try {
      await pool.execute(IsPrimeCommand(7));
    } on TomWorkerException catch (e) {
      closedError = e;
    }

    poolClosedSuccessfully = closedError != null;

    assert(
      closedError is TomWorkerException,
      'execute() after close() should throw TomWorkerException',
    );
    assert(poolClosedSuccessfully, 'Pool cleanup should complete successfully');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 02: Worker Pool Example ===\n');

  final pool = await WorkerPoolCreationExample.example1CreatePool();
  print('1. Creating a pool, and why an empty one is refused:');
  print('   pool size            : ${WorkerPoolCreationExample.poolSize}');
  print('   workers started      : ${WorkerPoolCreationExample.workersInPool}');
  print(
    '   withSize(0) rejected : '
    '${WorkerPoolCreationExample.emptyPoolRejected}',
  );
  print('');

  await PoolCommandExecutionExample.example2ExecuteCommands(pool);
  print('2. Dispatching commands through the pool:');
  print(
    '   isPrime by number     : '
    '${PoolCommandExecutionExample.primeResults}',
  );
  print(
    '   all commands executed : '
    '${PoolCommandExecutionExample.allCommandsExecuted}',
  );
  print('');

  await ParallelExecutionExample.example3ParallelExecution(pool);
  print('3. Fanning four counts out over the pool with Future.wait:');
  print(
    '   primes up to 1000/2000/3000/4000: '
    '${ParallelExecutionExample.parallelResults}',
  );
  print(
    '   elapsed                        : '
    '${ParallelExecutionExample.executionTimeMs} ms',
  );
  print('');

  await WorkDistributionExample.example4WorkDistribution(pool);
  print('4. Eight identified tasks spread across the workers:');
  print('   tasks dispatched   : ${WorkDistributionExample.taskCount}');
  print('   first task result  : ${WorkDistributionExample.taskResults.first}');
  print('   last task result   : ${WorkDistributionExample.taskResults.last}');
  print(
    '   all tasks completed: '
    '${WorkDistributionExample.allTasksCompleted}',
  );
  print('');

  await SequentialVsParallelExample.example5SequentialVsParallel(pool);
  print('5. The same four counts, sequentially then in parallel:');
  print(
    '   sequential      : '
    '${SequentialVsParallelExample.sequentialTimeMs} ms',
  );
  print(
    '   parallel        : '
    '${SequentialVsParallelExample.parallelTimeMs} ms',
  );
  print(
    '   parallel faster : '
    '${SequentialVsParallelExample.parallelWasFaster}',
  );
  print('');

  await PoolCleanupExample.example6PoolCleanup(pool);
  print('6. Closing the pool, then dispatching to it anyway:');
  print(
    '   execute() after close() threw: '
    '${PoolCleanupExample.poolClosedSuccessfully}',
  );
  print('');
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
