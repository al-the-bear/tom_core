/// Worker Basics Example
///
/// This example demonstrates the fundamental concepts of TomWorker:
/// spawning worker isolates, executing commands, using the TomCommand
/// pattern, what happens to a message no executor claims, and managing
/// worker lifecycle.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// Command Definitions
// =============================================================================

/// A simple command that computes the factorial of a number.
class FactorialCommand extends TomCommand {
  final int number;

  FactorialCommand(this.number);

  @override
  Future<Object?> execute() async {
    int result = 1;
    for (int i = 2; i <= number; i++) {
      result *= i;
    }
    return result;
  }
}

/// A command that performs a CPU-intensive Fibonacci computation.
class FibonacciCommand extends TomCommand {
  final int n;

  FibonacciCommand(this.n);

  @override
  Future<Object?> execute() async {
    return _fibonacci(n);
  }

  int _fibonacci(int n) {
    if (n <= 1) return n;
    return _fibonacci(n - 1) + _fibonacci(n - 2);
  }
}

/// A command that returns multiple values as a Map.
class ProcessDataCommand extends TomCommand {
  final List<int> numbers;

  ProcessDataCommand(this.numbers);

  @override
  Future<Object?> execute() async {
    final sum = numbers.fold<int>(0, (a, b) => a + b);
    final avg = numbers.isEmpty ? 0.0 : sum / numbers.length;
    final max = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b);
    final min = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a < b ? a : b);

    return {
      'sum': sum,
      'average': avg,
      'max': max,
      'min': min,
      'count': numbers.length,
    };
  }
}

/// An executor that handles string manipulation commands.
class StringExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is Map && command['type'] == 'reverse') {
      final input = command['value'] as String;
      return input.split('').reversed.join('');
    }
    if (command is Map && command['type'] == 'uppercase') {
      final input = command['value'] as String;
      return input.toUpperCase();
    }
    return TomExecutor.noResult;
  }
}

// =============================================================================
// EXAMPLE 1: Creating a worker context and spawning a worker
// =============================================================================

class WorkerSpawningExample {
  static bool workerIsReady = false;
  static bool workerIsClosed = false;
  static bool workerSpawnedSuccessfully = false;

  static Future<TomWorker> example1SpawningWorker() async {
    final context = TomWorkerContext(
      defaultTomEnvironment,
      platformLinux,
      [],
      'BasicWorker',
    );

    final worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);

    workerIsReady = worker.isReady;
    workerIsClosed = worker.isClosed;
    workerSpawnedSuccessfully = workerIsReady && !workerIsClosed;

    assert(workerIsReady, 'Worker should be ready');
    assert(!workerIsClosed, 'Worker should not be closed');
    assert(workerSpawnedSuccessfully, 'Worker should spawn successfully');

    return worker;
  }
}

// =============================================================================
// EXAMPLE 2: Executing a simple TomCommand
// =============================================================================

class SimpleCommandExample {
  static int? factorialResult;
  static bool commandExecuted = false;

  static Future<void> example2ExecutingCommand(TomWorker worker) async {
    factorialResult = await worker.executeCommand(FactorialCommand(5)) as int?;
    commandExecuted = factorialResult != null;

    assert(factorialResult == 120, 'Factorial of 5 should be 120');
    assert(commandExecuted, 'Command should execute');
  }
}

// =============================================================================
// EXAMPLE 3: Executing a CPU-intensive command
// =============================================================================

class CpuIntensiveCommandExample {
  static int? fibResult;
  static bool computationComplete = false;

  static Future<void> example3CpuIntensiveCommand(TomWorker worker) async {
    fibResult = await worker.executeCommand(FibonacciCommand(20)) as int?;
    computationComplete = fibResult != null;

    assert(fibResult == 6765, 'Fibonacci(20) should be 6765');
    assert(computationComplete, 'Computation should complete');
  }
}

// =============================================================================
// EXAMPLE 4: Commands returning complex data
// =============================================================================

class ComplexDataCommandExample {
  static int? dataSum;
  static double? dataAvg;
  static int? dataMax;
  static int? dataMin;
  static int? dataCount;

  static Future<void> example4ComplexDataCommand(TomWorker worker) async {
    final dataResult =
        await worker.executeCommand(ProcessDataCommand([10, 20, 30, 40, 50]))
            as Map;

    dataSum = dataResult['sum'] as int?;
    dataAvg = dataResult['average'] as double?;
    dataMax = dataResult['max'] as int?;
    dataMin = dataResult['min'] as int?;
    dataCount = dataResult['count'] as int?;

    assert(dataSum == 150, 'Sum should be 150');
    assert(dataAvg == 30.0, 'Average should be 30.0');
    assert(dataMax == 50, 'Max should be 50');
    assert(dataMin == 10, 'Min should be 10');
    assert(dataCount == 5, 'Count should be 5');
  }
}

// =============================================================================
// EXAMPLE 5: Using TomExecutor for command handling
// =============================================================================

class ExecutorExample {
  static String? reverseResult;
  static String? uppercaseResult;
  static bool executorWorks = false;

  static Future<void> example5UsingExecutor(TomWorker worker) async {
    // Send the executor to the worker isolate. No wait is needed before the
    // commands below: the registration and the commands travel the same port,
    // and the isolate processes them in the order they were sent.
    worker.sendExecutorToIsolate(StringExecutor());

    reverseResult =
        await worker.executeCommand({'type': 'reverse', 'value': 'Hello World'})
            as String?;

    uppercaseResult =
        await worker.executeCommand({
              'type': 'uppercase',
              'value': 'hello world',
            })
            as String?;

    executorWorks =
        reverseResult == 'dlroW olleH' && uppercaseResult == 'HELLO WORLD';

    assert(reverseResult == 'dlroW olleH', 'Reverse should work');
    assert(uppercaseResult == 'HELLO WORLD', 'Uppercase should work');
    assert(executorWorks, 'Executor should work');
  }
}

// =============================================================================
// EXAMPLE 6: Messages that nothing handles
// =============================================================================

class UnhandledMessageExample {
  static Object? unclaimedResult;
  static bool wasReportedAsUnhandled = false;
  static int? followUpResult;
  static bool workerStillUsable = false;

  static Future<void> example6UnhandledMessage(TomWorker worker) async {
    // The StringExecutor registered in example 5 only claims the two Map
    // shapes it knows; a plain String walks the whole chain unclaimed.
    unclaimedResult = await worker.executeCommand('no executor claims this');

    // The command is still answered — with the sentinel — so the caller learns
    // that nothing handled it instead of waiting on a reply that never comes.
    wasReportedAsUnhandled = identical(unclaimedResult, TomExecutor.noResult);

    // And the worker carries on normally afterwards.
    followUpResult = await worker.executeCommand(FactorialCommand(4)) as int?;
    workerStillUsable = followUpResult == 24;

    assert(
      wasReportedAsUnhandled,
      'An unclaimed message must answer with TomExecutor.noResult',
    );
    assert(workerStillUsable, 'The worker must stay usable afterwards');
  }
}

// =============================================================================
// EXAMPLE 7: Worker lifecycle management
// =============================================================================

class WorkerLifecycleExample {
  static bool wasReadyBeforeClose = false;
  static bool isClosedAfterClose = false;
  static bool dispatchAfterCloseRefused = false;

  static Future<void> example7WorkerLifecycle(TomWorker worker) async {
    wasReadyBeforeClose = worker.isReady;

    // Close the worker
    worker.close();

    // Give time for close to complete
    await Future.delayed(Duration(milliseconds: 50));

    isClosedAfterClose = worker.isClosed;

    // Dispatch after close fails fast instead of hanging: the isolate has
    // already been told to shut down, so nothing would ever answer.
    Object? closedError;
    try {
      await worker.executeCommand(FactorialCommand(3));
    } on TomWorkerException catch (e) {
      closedError = e;
    }
    dispatchAfterCloseRefused = closedError != null;

    assert(wasReadyBeforeClose, 'Worker should be ready before close');
    assert(isClosedAfterClose, 'Worker should be closed after close');
    assert(
      dispatchAfterCloseRefused,
      'executeCommand() after close() should throw TomWorkerException',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 01: Worker Basics Example ===\n');

  final worker = await WorkerSpawningExample.example1SpawningWorker();
  print('1. Spawning a worker isolate from a worker context:');
  print('   worker is ready      : ${WorkerSpawningExample.workerIsReady}');
  print('   worker is closed     : ${WorkerSpawningExample.workerIsClosed}');
  print(
    '   spawned successfully : '
    '${WorkerSpawningExample.workerSpawnedSuccessfully}',
  );
  print('');

  await SimpleCommandExample.example2ExecutingCommand(worker);
  print('2. Running a TomCommand on the worker:');
  print('   factorial(5)     : ${SimpleCommandExample.factorialResult}');
  print('   command executed : ${SimpleCommandExample.commandExecuted}');
  print('');

  await CpuIntensiveCommandExample.example3CpuIntensiveCommand(worker);
  print('3. Offloading a CPU-bound computation:');
  print('   fibonacci(20)        : ${CpuIntensiveCommandExample.fibResult}');
  print(
    '   computation complete : '
    '${CpuIntensiveCommandExample.computationComplete}',
  );
  print('');

  await ComplexDataCommandExample.example4ComplexDataCommand(worker);
  print('4. A command returning several values in one Map:');
  print('   sum     : ${ComplexDataCommandExample.dataSum}');
  print('   average : ${ComplexDataCommandExample.dataAvg}');
  print('   max     : ${ComplexDataCommandExample.dataMax}');
  print('   min     : ${ComplexDataCommandExample.dataMin}');
  print('   count   : ${ComplexDataCommandExample.dataCount}');
  print('');

  await ExecutorExample.example5UsingExecutor(worker);
  print('5. A TomExecutor registered inside the worker isolate:');
  print('   reverse("Hello World")   : ${ExecutorExample.reverseResult}');
  print('   uppercase("hello world") : ${ExecutorExample.uppercaseResult}');
  print('   executor handled both    : ${ExecutorExample.executorWorks}');
  print('');

  await UnhandledMessageExample.example6UnhandledMessage(worker);
  print('6. A message that no executor claims:');
  print(
    '   answered with TomExecutor.noResult : '
    '${UnhandledMessageExample.wasReportedAsUnhandled}',
  );
  print(
    '   follow-up factorial(4)             : '
    '${UnhandledMessageExample.followUpResult}',
  );
  print(
    '   worker still usable                : '
    '${UnhandledMessageExample.workerStillUsable}',
  );
  print('');

  await WorkerLifecycleExample.example7WorkerLifecycle(worker);
  print('7. Closing the worker, then dispatching to it anyway:');
  print(
    '   ready before close()       : '
    '${WorkerLifecycleExample.wasReadyBeforeClose}',
  );
  print(
    '   closed after close()       : '
    '${WorkerLifecycleExample.isClosedAfterClose}',
  );
  print(
    '   dispatch after close threw : '
    '${WorkerLifecycleExample.dispatchAfterCloseRefused}',
  );
  print('');
}

/// Standalone entry point.
Future<void> main() async {
  requireAsserts();
  await run();
}
