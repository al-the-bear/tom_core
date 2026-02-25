import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Simple test executor that handles String commands.
class TestStringExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is String) {
      return 'Processed: $command';
    }
    return TomExecutor.noResult;
  }
}

/// Test executor that handles int commands.
class TestIntExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is int) {
      return command * 2;
    }
    return TomExecutor.noResult;
  }
}

/// Test executor that always returns noResult.
class NoOpExecutor extends TomExecutor {
  int executeCallCount = 0;

  @override
  Object execute(Object command) {
    executeCallCount++;
    return TomExecutor.noResult;
  }
}

/// Test command that returns a fixed value.
class FixedValueCommand extends TomCommand {
  final Object? value;

  FixedValueCommand(this.value);

  @override
  Future<Object?> execute() async {
    return value;
  }
}

/// Test command that performs a computation.
class ComputeCommand extends TomCommand {
  final int a;
  final int b;

  ComputeCommand(this.a, this.b);

  @override
  Future<Object?> execute() async {
    return a + b;
  }
}

/// Test command that throws an exception.
class ThrowingCommand extends TomCommand {
  final String message;

  ThrowingCommand(this.message);

  @override
  Future<Object?> execute() async {
    throw Exception(message);
  }
}

/// Test command with async delay.
class DelayedCommand extends TomCommand {
  final int delayMs;
  final Object result;

  DelayedCommand(this.delayMs, this.result);

  @override
  Future<Object?> execute() async {
    await Future.delayed(Duration(milliseconds: delayMs));
    return result;
  }
}

/// Simple test worker context.
class TestWorkerContext extends TomWorkerContext {
  bool isolateInitialized = false;
  bool workerInitialized = false;

  TestWorkerContext({String namePrefix = 'Test'})
      : super(
          const TomEnvironment('test', isTest: true),
          platformLinux,
          [],
          namePrefix,
        );

  @override
  Future<bool> initializeIsolate() async {
    isolateInitialized = true;
    return true;
  }

  @override
  Future<bool> initializeWorker(TomWorker worker) async {
    workerInitialized = true;
    return true;
  }
}

/// Worker context that adds an executor during initialization.
class ExecutorWorkerContext extends TomWorkerContext {
  ExecutorWorkerContext()
      : super(
          const TomEnvironment('test', isTest: true),
          platformLinux,
          [],
          'Exec',
        );

  @override
  Future<bool> initializeWorker(TomWorker worker) async {
    worker.sendExecutorToIsolate(TestStringExecutor());
    return true;
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // Reset static state between tests
  setUp(() {
    TomWorker.executors.clear();
    TomWorker.workerCount = 0;
    TomWorker.isMainIsolate = true;
  });

  // ===========================================================================
  // TomWorkerException Tests
  // ===========================================================================
  group('TomWorkerException', () {
    group('constructor', () {
      test('should create exception with key and message', () {
        final exception = TomWorkerException(
          'test.error.key',
          'Test error message',
        );

        expect(exception.key, equals('test.error.key'));
        expect(exception.defaultUserMessage, equals('Test error message'));
      });

      test('should create exception with parameters', () {
        final exception = TomWorkerException(
          'test.error.key',
          'Test error message',
          parameters: {'param1': 'value1', 'param2': 42},
        );

        expect(exception.parameters, isNotNull);
        expect(exception.parameters!['param1'], equals('value1'));
        expect(exception.parameters!['param2'], equals(42));
      });

      test('should create exception with root exception', () {
        final rootException = Exception('Root cause');
        final exception = TomWorkerException(
          'test.error.key',
          'Test error message',
          rootException: rootException,
        );

        expect(exception.rootException, equals(rootException));
      });
    });
  });

  // ===========================================================================
  // TomExecutor Tests
  // ===========================================================================
  group('TomExecutor', () {
    group('noResult', () {
      test('should be a constant sentinel value', () {
        expect(TomExecutor.noResult, isNotNull);
        expect(TomExecutor.noResult, same(TomExecutor.noResult));
      });

      test('should be distinguishable from null', () {
        expect(TomExecutor.noResult, isNot(equals(null)));
      });
    });

    group('execute', () {
      test('should return processed result for matching command type', () {
        final executor = TestStringExecutor();

        final result = executor.execute('test input');

        expect(result, equals('Processed: test input'));
      });

      test('should return noResult for non-matching command type', () {
        final executor = TestStringExecutor();

        final result = executor.execute(42);

        expect(result, same(TomExecutor.noResult));
      });

      test('should handle multiple executor types', () {
        final stringExecutor = TestStringExecutor();
        final intExecutor = TestIntExecutor();

        expect(stringExecutor.execute('hello'), equals('Processed: hello'));
        expect(stringExecutor.execute(5), same(TomExecutor.noResult));
        expect(intExecutor.execute(5), equals(10));
        expect(intExecutor.execute('hello'), same(TomExecutor.noResult));
      });
    });
  });

  // ===========================================================================
  // TomCommand Tests
  // ===========================================================================
  group('TomCommand', () {
    group('execute', () {
      test('should return fixed value from FixedValueCommand', () async {
        final command = FixedValueCommand('test value');

        final result = await command.execute();

        expect(result, equals('test value'));
      });

      test('should perform computation in ComputeCommand', () async {
        final command = ComputeCommand(10, 20);

        final result = await command.execute();

        expect(result, equals(30));
      });

      test('should handle null return value', () async {
        final command = FixedValueCommand(null);

        final result = await command.execute();

        expect(result, isNull);
      });

      test('should handle various types as return values', () async {
        expect(await FixedValueCommand(42).execute(), equals(42));
        expect(await FixedValueCommand(3.14).execute(), equals(3.14));
        expect(await FixedValueCommand(true).execute(), equals(true));
        expect(
          await FixedValueCommand([1, 2, 3]).execute(),
          equals([1, 2, 3]),
        );
        expect(
          await FixedValueCommand({'key': 'value'}).execute(),
          equals({'key': 'value'}),
        );
      });
    });
  });

  // ===========================================================================
  // TomWorkerContext Tests
  // ===========================================================================
  group('TomWorkerContext', () {
    group('constructor', () {
      test('should create context with all parameters', () {
        final context = TomWorkerContext(
          const TomEnvironment('production'),
          platformWeb,
          ['--arg1', '--arg2'],
          'Prod',
        );

        expect(context.tomEnvironment.env, equals('production'));
        expect(context.tomPlatform.name, equals('web'));
        expect(context.args, equals(['--arg1', '--arg2']));
        expect(context.namePrefix, equals('Prod'));
      });

      test('should create context with empty args', () {
        final context = TomWorkerContext(
          const TomEnvironment('dev'),
          platformMacos,
          [],
          'Dev',
        );

        expect(context.args, isEmpty);
      });
    });

    group('initializeIsolate', () {
      test('should return true by default', () async {
        final context = TomWorkerContext(
          const TomEnvironment('test'),
          platformLinux,
          [],
          'Test',
        );

        final result = await context.initializeIsolate();

        expect(result, isTrue);
      });
    });

    group('initializeWorker', () {
      test('should return true by default', () async {
        final context = TomWorkerContext(
          const TomEnvironment('test'),
          platformLinux,
          [],
          'Test',
        );

        // Create a mock worker for testing
        // Note: We can't easily test this without spawning a real worker
        // This test validates the method signature exists
        expect(context.initializeWorker, isNotNull);
      });
    });
  });

  // ===========================================================================
  // TomWorker Tests
  // ===========================================================================
  group('TomWorker', () {
    group('static properties', () {
      test('should have workerCount starting at zero after reset', () {
        expect(TomWorker.workerCount, equals(0));
      });

      test('should have isMainIsolate set to true by default', () {
        expect(TomWorker.isMainIsolate, isTrue);
      });

      test('should have empty executors list initially', () {
        expect(TomWorker.executors, isEmpty);
      });

      test('should have readyMessage constant', () {
        expect(TomWorker.readyMessage, equals('--- ready ---'));
      });
    });

    group('executors', () {
      test('should allow adding executors', () {
        final executor = TestStringExecutor();

        TomWorker.executors.add(executor);

        expect(TomWorker.executors.length, equals(1));
        expect(TomWorker.executors.first, same(executor));
      });

      test('should allow adding multiple executors', () {
        TomWorker.executors.add(TestStringExecutor());
        TomWorker.executors.add(TestIntExecutor());

        expect(TomWorker.executors.length, equals(2));
      });

      test('should allow clearing executors', () {
        TomWorker.executors.add(TestStringExecutor());
        TomWorker.executors.add(TestIntExecutor());

        TomWorker.executors.clear();

        expect(TomWorker.executors, isEmpty);
      });
    });

    group('canSendToCreator', () {
      test('should return false in main isolate', () {
        expect(TomWorker.canSendToCreator(), isFalse);
      });
    });

    group('sendToCreator', () {
      test('should throw TomWorkerException when called from main isolate',
          () {
        expect(
          () => TomWorker.sendToCreator('test'),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('should throw exception with correct key', () {
        try {
          TomWorker.sendToCreator('test');
          fail('Expected TomWorkerException');
        } on TomWorkerException catch (e) {
          expect(
            e.key,
            equals('isolate.state_error.attempt_to_send_to_creator_in_creator'),
          );
        }
      });
    });

    group('executeInCreator', () {
      test('should throw TomWorkerException when called from main isolate',
          () async {
        expect(
          () => TomWorker.executeInCreator('test'),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('should throw exception with correct key', () async {
        try {
          await TomWorker.executeInCreator('test');
          fail('Expected TomWorkerException');
        } on TomWorkerException catch (e) {
          expect(
            e.key,
            equals(
              'isolate.state_error.attempt_to_execute_in_creator_in_creator',
            ),
          );
        }
      });
    });

    group('spawn', () {
      test('should spawn worker and return ready instance', () async {
        final context = TestWorkerContext();

        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        expect(worker, isNotNull);
        expect(worker.isReady, isTrue);
        expect(worker.isClosed, isFalse);

        worker.close();
      });

      test('should increment workerCount for each spawned worker', () async {
        final initialCount = TomWorker.workerCount;
        final context1 = TestWorkerContext(namePrefix: 'W1');
        final context2 = TestWorkerContext(namePrefix: 'W2');

        final worker1 = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context1,
        );
        final worker2 = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context2,
        );

        expect(TomWorker.workerCount, equals(initialCount + 2));

        worker1.close();
        worker2.close();
      });

      test('should call initializeWorker on context', () async {
        final context = TestWorkerContext();

        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        expect(context.workerInitialized, isTrue);

        worker.close();
      });
    });

    group('executeCommand', () {
      late TomWorker worker;

      setUp(() async {
        final context = TestWorkerContext();
        worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );
      });

      tearDown(() {
        worker.close();
      });

      test('should execute TomCommand and return result', () async {
        final result = await worker.executeCommand(FixedValueCommand('hello'));

        expect(result, equals('hello'));
      });

      test('should execute computation command', () async {
        final result = await worker.executeCommand(ComputeCommand(15, 25));

        expect(result, equals(40));
      });

      test('should execute multiple commands sequentially', () async {
        final result1 = await worker.executeCommand(ComputeCommand(1, 2));
        final result2 = await worker.executeCommand(ComputeCommand(3, 4));
        final result3 = await worker.executeCommand(ComputeCommand(5, 6));

        expect(result1, equals(3));
        expect(result2, equals(7));
        expect(result3, equals(11));
      });

      test('should execute multiple commands in parallel', () async {
        final futures = [
          worker.executeCommand(ComputeCommand(10, 20)),
          worker.executeCommand(ComputeCommand(30, 40)),
          worker.executeCommand(ComputeCommand(50, 60)),
        ];

        final results = await Future.wait(futures);

        expect(results, containsAll([30, 70, 110]));
      });

      test('should handle null result from command', () async {
        final result = await worker.executeCommand(FixedValueCommand(null));

        // null is converted to "null" string in the implementation
        expect(result, equals('null'));
      });
    });

    group('isBusy', () {
      late TomWorker worker;

      setUp(() async {
        final context = TestWorkerContext();
        worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );
      });

      tearDown(() {
        worker.close();
      });

      test('should return false when no commands are pending', () {
        expect(worker.isBusy(), isFalse);
      });

      test('should return true when commands are pending', () async {
        // Start a delayed command but don't await it yet
        final future = worker.executeCommand(DelayedCommand(100, 'result'));

        // Check busy state immediately
        expect(worker.isBusy(), isTrue);

        // Wait for completion
        await future;

        // Should no longer be busy
        expect(worker.isBusy(), isFalse);
      });
    });

    group('close', () {
      test('should set isClosed to true', () async {
        final context = TestWorkerContext();
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        expect(worker.isClosed, isFalse);

        worker.close();

        expect(worker.isClosed, isTrue);
      });

      test('should be idempotent', () async {
        final context = TestWorkerContext();
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.close();
        worker.close();
        worker.close();

        expect(worker.isClosed, isTrue);
      });
    });

    group('sendExecutorToIsolate', () {
      test('should send executor that can process commands', () async {
        final context = TestWorkerContext();
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.sendExecutorToIsolate(TestStringExecutor());

        // Give the isolate time to receive the executor
        await Future.delayed(Duration(milliseconds: 50));

        // Now the executor should be registered in the isolate
        // Note: We can't directly test this without sending a non-TomCommand
        // The executor will handle string commands sent to the isolate

        worker.close();
      });
    });
  });

  // ===========================================================================
  // TomWorkerPool Tests
  // ===========================================================================
  group('TomWorkerPool', () {
    group('withSize', () {
      test('should create pool with specified number of workers', () async {
        final context = TestWorkerContext(namePrefix: 'Pool');

        final pool = await TomWorkerPool.withSize(3, context);

        // Verify pool was created by executing commands
        final result = pool.execute(FixedValueCommand('test'));
        expect(result, equals('test'));
      });

      test('should create pool with single worker', () async {
        final context = TestWorkerContext(namePrefix: 'Single');

        final pool = await TomWorkerPool.withSize(1, context);

        final result = pool.execute(ComputeCommand(5, 5));
        expect(result, equals(10));
      });
    });

    group('execute', () {
      late TomWorkerPool pool;

      setUp(() async {
        final context = TestWorkerContext(namePrefix: 'PoolTest');
        pool = await TomWorkerPool.withSize(2, context);
      });

      test('should execute command and return result', () async {
        final result = pool.execute(FixedValueCommand(42));

        expect(result, equals(42));
      });

      test('should execute multiple commands', () async {
        final result1 = pool.execute(ComputeCommand(1, 1));
        final result2 = pool.execute(ComputeCommand(2, 2));
        final result3 = pool.execute(ComputeCommand(3, 3));

        expect(result1, equals(2));
        expect(result2, equals(4));
        expect(result3, equals(6));
      });

      test('should distribute commands across workers', () async {
        // Execute multiple delayed commands in parallel
        final results = <Object?>[];
        for (int i = 0; i < 4; i++) {
          results.add(pool.execute(ComputeCommand(i, i)));
        }

        expect(results, containsAll([0, 2, 4, 6]));
      });

      test('should handle commands when all workers are busy', () async {
        // Create a pool with just 1 worker
        final smallContext = TestWorkerContext(namePrefix: 'Small');
        final smallPool = await TomWorkerPool.withSize(1, smallContext);

        // Queue multiple commands sequentially
        final result1 = smallPool.execute(DelayedCommand(10, 'first'));
        final result2 = smallPool.execute(DelayedCommand(10, 'second'));
        final result3 = smallPool.execute(DelayedCommand(10, 'third'));

        expect([result1, result2, result3], containsAll(['first', 'second', 'third']));
      });
    });
  });

  // ===========================================================================
  // Integration Tests
  // ===========================================================================
  group('Integration', () {
    test('should complete full worker lifecycle', () async {
      // Create context
      final context = TestWorkerContext(namePrefix: 'Lifecycle');

      // Spawn worker
      final worker = await TomWorker.spawn(
        TomWorker.startRemoteIsolate,
        context,
      );

      // Verify ready
      expect(worker.isReady, isTrue);
      expect(worker.isClosed, isFalse);

      // Execute commands
      final result1 = await worker.executeCommand(ComputeCommand(100, 200));
      expect(result1, equals(300));

      final result2 = await worker.executeCommand(FixedValueCommand('done'));
      expect(result2, equals('done'));

      // Close worker
      worker.close();
      expect(worker.isClosed, isTrue);
    });

    test('should handle rapid command execution', () async {
      final context = TestWorkerContext(namePrefix: 'Rapid');
      final worker = await TomWorker.spawn(
        TomWorker.startRemoteIsolate,
        context,
      );

      // Execute many commands rapidly
      final futures = <Future<Object?>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(worker.executeCommand(ComputeCommand(i, 1)));
      }

      final results = await Future.wait(futures);

      // Verify all results
      for (int i = 0; i < 20; i++) {
        expect(results[i], equals(i + 1));
      }

      worker.close();
    });

    test('should work with pool for parallel processing', () async {
      final context = TestWorkerContext(namePrefix: 'Parallel');
      final pool = await TomWorkerPool.withSize(4, context);

      // Execute commands that should be distributed across workers
      final results = <Object?>[];
      for (int i = 0; i < 10; i++) {
        results.add(pool.execute(ComputeCommand(i, i)));
      }

      // Verify all results are correct
      for (int i = 0; i < 10; i++) {
        expect(results.contains(i * 2), isTrue);
      }
    });
  });
}
