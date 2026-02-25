/// Worker Pool Example
///
/// This example demonstrates TomWorkerPool for managing multiple
/// worker isolates with automatic load distribution. Worker pools
/// are ideal for CPU-intensive parallel processing.
///
/// Key concepts covered:
/// - Creating a pool with TomWorkerPool.withSize()
/// - Executing commands with automatic load balancing
/// - Parallel execution with Future.wait()
/// - Performance benefits of pooled workers
/// - Real-world use cases for worker pools
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Command Definitions
// ============================================================================

/// A command that performs prime number checking.
///
/// This is a CPU-bound operation that benefits from parallelization.
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
///
/// This simulates a heavier workload suitable for worker pools.
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

/// A command that performs matrix multiplication.
///
/// Another CPU-intensive operation ideal for worker pools.
class MatrixMultiplyCommand extends TomCommand {
  final List<List<int>> a;
  final List<List<int>> b;

  MatrixMultiplyCommand(this.a, this.b);

  @override
  Future<Object?> execute() async {
    final rowsA = a.length;
    final colsA = a[0].length;
    final colsB = b[0].length;

    final result = List.generate(
      rowsA,
      (_) => List.filled(colsB, 0),
    );

    for (int i = 0; i < rowsA; i++) {
      for (int j = 0; j < colsB; j++) {
        for (int k = 0; k < colsA; k++) {
          result[i][j] += a[i][k] * b[k][j];
        }
      }
    }

    return result;
  }
}

/// A command that simulates a task with a unique identifier.
///
/// Used to demonstrate work distribution across workers.
class IdentifiedTaskCommand extends TomCommand {
  final int taskId;
  final int workAmount;

  IdentifiedTaskCommand(this.taskId, this.workAmount);

  @override
  Future<Object?> execute() async {
    // Simulate work
    int result = 0;
    for (int i = 0; i < workAmount; i++) {
      result += i;
    }
    return {'taskId': taskId, 'result': result};
  }
}

// ============================================================================
// Example Code
// ============================================================================

Future<void> run() async {
  print('=== 02: Worker Pool Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating a worker pool
  // -------------------------------------------------------------------------
  print('1. Creating a worker pool:');

  final context = TomWorkerContext(
    defaultTomEnvironment,
    platformLinux,
    [],
    'PoolWorker',
  );

  final poolSize = 4;
  final pool = await TomWorkerPool.withSize(poolSize, context);

  print('   Created pool with $poolSize workers');
  print('   Workers are ready to process commands\n');

  // -------------------------------------------------------------------------
  // Example 2: Executing commands through the pool
  // -------------------------------------------------------------------------
  print('2. Executing prime checks through the pool:');

  final numbersToCheck = [97, 100, 127, 150, 199, 200];
  final primeResults = <int, bool>{};

  for (final num in numbersToCheck) {
    final isPrime = pool.execute(IsPrimeCommand(num)) as bool;
    primeResults[num] = isPrime;
  }

  print('   Prime number checks:');
  for (final entry in primeResults.entries) {
    print('   - ${entry.key}: ${entry.value ? "prime" : "not prime"}');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 3: Parallel execution with Future.wait
  // -------------------------------------------------------------------------
  print('3. Parallel execution with Future.wait:');

  final ranges = [1000, 2000, 3000, 4000];
  final stopwatch = Stopwatch()..start();

  final parallelFutures = ranges.map((n) async => pool.execute(CountPrimesCommand(n)));
  final parallelResults = await Future.wait(parallelFutures);

  final parallelTime = stopwatch.elapsedMilliseconds;

  print('   Counting primes up to $ranges (in parallel):');
  for (int i = 0; i < ranges.length; i++) {
    print('   - Primes up to ${ranges[i]}: ${parallelResults[i]}');
  }
  print('   Parallel execution time: ${parallelTime}ms\n');

  // -------------------------------------------------------------------------
  // Example 4: Work distribution demonstration
  // -------------------------------------------------------------------------
  print('4. Work distribution across workers:');

  final taskCount = 8;
  final taskFutures = <Future<Object?>>[];

  for (int i = 0; i < taskCount; i++) {
    taskFutures.add(Future.value(pool.execute(IdentifiedTaskCommand(i, 10000))));
  }

  final taskResults = await Future.wait(taskFutures);

  print('   Distributed $taskCount tasks across $poolSize workers:');
  for (final result in taskResults) {
    final map = result as Map;
    print('   - Task ${map['taskId']} completed with result ${map['result']}');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 5: Matrix multiplication in parallel
  // -------------------------------------------------------------------------
  print('5. Matrix multiplication in parallel:');

  final matrixA = [
    [1, 2],
    [3, 4],
  ];
  final matrixB = [
    [5, 6],
    [7, 8],
  ];
  final matrixC = [
    [2, 0],
    [1, 2],
  ];

  final matrixFutures = [
    Future.value(pool.execute(MatrixMultiplyCommand(matrixA, matrixB))),
    Future.value(pool.execute(MatrixMultiplyCommand(matrixB, matrixC))),
    Future.value(pool.execute(MatrixMultiplyCommand(matrixA, matrixC))),
  ];

  final matrixResults = await Future.wait(matrixFutures);

  final abResult = matrixResults[0] as List<List<int>>;
  final bcResult = matrixResults[1] as List<List<int>>;
  final acResult = matrixResults[2] as List<List<int>>;

  print('   A × B = $abResult');
  print('   B × C = $bcResult');
  print('   A × C = $acResult\n');

  // -------------------------------------------------------------------------
  // Example 6: Handling many concurrent requests
  // -------------------------------------------------------------------------
  print('6. Handling many concurrent requests:');

  final manyNumbers = List.generate(20, (i) => 100 + i * 10);
  final manyFutures = manyNumbers.map((n) async => pool.execute(IsPrimeCommand(n)));

  final stopwatch2 = Stopwatch()..start();
  final manyResults = await Future.wait(manyFutures);
  final batchTime = stopwatch2.elapsedMilliseconds;

  final primeCount = manyResults.where((r) => r == true).length;
  final nonPrimeCount = manyResults.where((r) => r == false).length;

  print('   Checked ${manyNumbers.length} numbers for primality');
  print('   - Primes found: $primeCount');
  print('   - Non-primes found: $nonPrimeCount');
  print('   - Processing time: ${batchTime}ms\n');

  // -------------------------------------------------------------------------
  // Example 7: Real-world scenario - batch data processing
  // -------------------------------------------------------------------------
  print('7. Batch data processing scenario:');

  // Simulate processing different data chunks
  final dataChunks = [
    [1, 2, 3, 4, 5],
    [10, 20, 30],
    [100, 200, 300, 400],
    [5, 10, 15, 20, 25, 30],
  ];

  final processFutures = dataChunks.map((chunk) async {
    return pool.execute(_SumCommand(chunk));
  });

  final sums = await Future.wait(processFutures);

  print('   Processing ${dataChunks.length} data chunks in parallel:');
  for (int i = 0; i < dataChunks.length; i++) {
    print('   - Chunk ${i + 1} ${dataChunks[i]}: sum = ${sums[i]}');
  }

  final totalSum = sums.fold<int>(0, (a, b) => a + (b as int));
  print('   - Total sum across all chunks: $totalSum');

  print('\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 2: Prime number checks
  assert(primeResults[97] == true); // 97 is prime
  assert(primeResults[100] == false); // 100 is not prime
  assert(primeResults[127] == true); // 127 is prime
  assert(primeResults[150] == false); // 150 is not prime
  assert(primeResults[199] == true); // 199 is prime
  assert(primeResults[200] == false); // 200 is not prime

  // Example 3: Prime counts
  assert(parallelResults[0] == 168); // Primes up to 1000
  assert(parallelResults[1] == 303); // Primes up to 2000
  assert(parallelResults[2] == 430); // Primes up to 3000
  assert(parallelResults[3] == 550); // Primes up to 4000

  // Example 4: Task distribution
  assert(taskResults.length == taskCount);
  for (int i = 0; i < taskCount; i++) {
    final map = taskResults[i] as Map;
    assert(map['taskId'] == i);
    assert(map['result'] == 49995000); // Sum of 0 to 9999
  }

  // Example 5: Matrix multiplication
  // A × B = [[1*5+2*7, 1*6+2*8], [3*5+4*7, 3*6+4*8]] = [[19, 22], [43, 50]]
  assert(abResult[0][0] == 19);
  assert(abResult[0][1] == 22);
  assert(abResult[1][0] == 43);
  assert(abResult[1][1] == 50);

  // B × C = [[5*2+6*1, 5*0+6*2], [7*2+8*1, 7*0+8*2]] = [[16, 12], [22, 16]]
  assert(bcResult[0][0] == 16);
  assert(bcResult[0][1] == 12);
  assert(bcResult[1][0] == 22);
  assert(bcResult[1][1] == 16);

  // A × C = [[1*2+2*1, 1*0+2*2], [3*2+4*1, 3*0+4*2]] = [[4, 4], [10, 8]]
  assert(acResult[0][0] == 4);
  assert(acResult[0][1] == 4);
  assert(acResult[1][0] == 10);
  assert(acResult[1][1] == 8);

  // Example 6: Many concurrent requests
  assert(manyResults.length == 20);
  assert(primeCount + nonPrimeCount == 20);

  // Example 7: Batch processing
  assert(sums[0] == 15); // 1+2+3+4+5
  assert(sums[1] == 60); // 10+20+30
  assert(sums[2] == 1000); // 100+200+300+400
  assert(sums[3] == 105); // 5+10+15+20+25+30
  assert(totalSum == 1180);
}

// ============================================================================
// Helper Commands
// ============================================================================

/// Simple sum command for batch processing example.
class _SumCommand extends TomCommand {
  final List<int> numbers;

  _SumCommand(this.numbers);

  @override
  Future<Object?> execute() async {
    return numbers.fold<int>(0, (a, b) => a + b);
  }
}
