/// Worker Basics Example
///
/// This example demonstrates the fundamental concepts of TomWorker:
/// spawning worker isolates, executing commands, using the TomCommand
/// pattern, and managing worker lifecycle.
///
/// Key concepts covered:
/// - Creating a TomWorkerContext for worker configuration
/// - Spawning workers with TomWorker.spawn()
/// - Using TomCommand for self-executing commands
/// - Using TomExecutor for centralized command handling
/// - Checking worker status with isBusy()
/// - Proper cleanup with close()
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Command Definitions
// ============================================================================

/// A simple command that computes the factorial of a number.
///
/// This demonstrates the TomCommand pattern where the command
/// encapsulates both data and behavior.
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

/// A command that performs a CPU-intensive computation.
///
/// This simulates work that benefits from running in a separate isolate
/// to avoid blocking the main thread.
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
///
/// This demonstrates the TomExecutor pattern for centralized
/// command handling.
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

// ============================================================================
// Example Code
// ============================================================================

Future<void> run() async {
  print('=== 01: Worker Basics Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating a worker context and spawning a worker
  // -------------------------------------------------------------------------
  print('1. Creating and spawning a worker:');

  final context = TomWorkerContext(
    defaultTomEnvironment,
    platformLinux,
    [],
    'BasicWorker',
  );

  final worker = await TomWorker.spawn(
    TomWorker.startRemoteIsolate,
    context,
  );

  final workerIsReady = worker.isReady;
  final workerIsClosed = worker.isClosed;

  print('   Worker spawned successfully');
  print('   - isReady: $workerIsReady');
  print('   - isClosed: $workerIsClosed\n');

  // -------------------------------------------------------------------------
  // Example 2: Executing a simple TomCommand
  // -------------------------------------------------------------------------
  print('2. Executing a factorial command:');

  final factorialResult = await worker.executeCommand(FactorialCommand(5));

  print('   FactorialCommand(5) result: $factorialResult');
  print('   5! = 5 × 4 × 3 × 2 × 1 = $factorialResult\n');

  // -------------------------------------------------------------------------
  // Example 3: Executing a CPU-intensive command
  // -------------------------------------------------------------------------
  print('3. Executing a Fibonacci command:');

  final fibResult = await worker.executeCommand(FibonacciCommand(20));

  print('   FibonacciCommand(20) result: $fibResult');
  print('   This runs in a separate isolate, keeping the main thread free\n');

  // -------------------------------------------------------------------------
  // Example 4: Commands returning complex data
  // -------------------------------------------------------------------------
  print('4. Processing data and returning a Map:');

  final dataResult = await worker.executeCommand(
    ProcessDataCommand([10, 20, 30, 40, 50]),
  ) as Map;

  final dataSum = dataResult['sum'];
  final dataAvg = dataResult['average'];
  final dataMax = dataResult['max'];
  final dataMin = dataResult['min'];
  final dataCount = dataResult['count'];

  print('   ProcessDataCommand([10, 20, 30, 40, 50]):');
  print('   - sum: $dataSum');
  print('   - average: $dataAvg');
  print('   - max: $dataMax');
  print('   - min: $dataMin');
  print('   - count: $dataCount\n');

  // -------------------------------------------------------------------------
  // Example 5: Using TomExecutor for command handling
  // -------------------------------------------------------------------------
  print('5. Using TomExecutor for string operations:');

  // Send the executor to the worker isolate
  worker.sendExecutorToIsolate(StringExecutor());

  // Give the executor time to be registered
  await Future.delayed(Duration(milliseconds: 10));

  final reverseResult = await worker.executeCommand({
    'type': 'reverse',
    'value': 'Hello World',
  });

  final uppercaseResult = await worker.executeCommand({
    'type': 'uppercase',
    'value': 'hello world',
  });

  print('   Reverse "Hello World": $reverseResult');
  print('   Uppercase "hello world": $uppercaseResult\n');

  // -------------------------------------------------------------------------
  // Example 6: Checking worker busy status
  // -------------------------------------------------------------------------
  print('6. Checking worker busy status:');

  final busyBeforeCommand = worker.isBusy();

  // Start a command but don't await yet
  final pendingFuture = worker.executeCommand(FibonacciCommand(15));

  // Check if busy immediately after sending
  // Note: The worker may or may not be marked busy depending on timing
  final busyDuringCommand = worker.isBusy();

  // Wait for completion
  await pendingFuture;

  final busyAfterCommand = worker.isBusy();

  print('   Busy before command: $busyBeforeCommand');
  print('   Busy during command: $busyDuringCommand');
  print('   Busy after command: $busyAfterCommand\n');

  // -------------------------------------------------------------------------
  // Example 7: Multiple sequential commands
  // -------------------------------------------------------------------------
  print('7. Multiple sequential commands:');

  final results = <int>[];
  for (int i = 1; i <= 5; i++) {
    final result = await worker.executeCommand(FactorialCommand(i)) as int;
    results.add(result);
  }

  print('   Factorials 1! to 5!: $results\n');

  // -------------------------------------------------------------------------
  // Example 8: Closing a worker
  // -------------------------------------------------------------------------
  print('8. Closing the worker:');

  final closedBefore = worker.isClosed;
  worker.close();
  final closedAfter = worker.isClosed;

  print('   isClosed before close(): $closedBefore');
  print('   isClosed after close(): $closedAfter');

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Worker spawning
  assert(workerIsReady == true);
  assert(workerIsClosed == false);

  // Example 2: Factorial command
  assert(factorialResult == 120); // 5! = 120

  // Example 3: Fibonacci command
  assert(fibResult == 6765); // Fib(20) = 6765

  // Example 4: Data processing
  assert(dataSum == 150);
  assert(dataAvg == 30.0);
  assert(dataMax == 50);
  assert(dataMin == 10);
  assert(dataCount == 5);

  // Example 5: String executor
  assert(reverseResult == 'dlroW olleH');
  assert(uppercaseResult == 'HELLO WORLD');

  // Example 6: Busy status
  assert(busyBeforeCommand == false);
  assert(busyAfterCommand == false);

  // Example 7: Sequential results
  assert(results.length == 5);
  assert(results[0] == 1); // 1!
  assert(results[1] == 2); // 2!
  assert(results[2] == 6); // 3!
  assert(results[3] == 24); // 4!
  assert(results[4] == 120); // 5!

  // Example 8: Worker closing
  assert(closedBefore == false);
  assert(closedAfter == true);
}
