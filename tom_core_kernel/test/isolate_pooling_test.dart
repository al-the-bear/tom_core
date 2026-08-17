import 'dart:async';
import 'dart:isolate';

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

/// Test command that kills its own worker isolate mid-execution.
///
/// Simulates an unexpected worker death (a crash / `Isolate.kill` / OOM): the
/// isolate terminates before it can answer, so the awaiting request would hang
/// forever without liveness supervision. Used to assert the supervised pool
/// fails the in-flight request and respawns a replacement.
class SuicideCommand extends TomCommand {
  @override
  Future<Object?> execute() async {
    Isolate.current.kill(priority: Isolate.immediate);
    // Unreachable once the kill takes effect, but keeps the body well-typed.
    await Future<void>.delayed(const Duration(seconds: 60));
    return 'never';
  }
}

/// Command executed in the CREATOR isolate via the back-channel.
///
/// Used by [CreatorRoundTripCommand] to exercise the worker→creator
/// round-trip (`_TomCreatorCommand` branch of `_handleResponsesFromIsolate`).
class CreatorComputeCommand extends TomCommand {
  final int value;

  CreatorComputeCommand(this.value);

  @override
  Future<Object?> execute() async {
    return value + 1000;
  }
}

/// Command run in the WORKER isolate that delegates back to the creator.
///
/// When executed inside the worker it calls [TomWorker.executeInCreator],
/// so the creator handles [CreatorComputeCommand] and the answer travels
/// back through the worker to the original caller.
class CreatorRoundTripCommand extends TomCommand {
  final int value;

  CreatorRoundTripCommand(this.value);

  @override
  Future<Object?> execute() async {
    return await TomWorker.executeInCreator(CreatorComputeCommand(value));
  }
}

/// A command that does not override [execute], to test the base default.
class DefaultCommand extends TomCommand {}

/// Reports whether the back-channel is reachable from inside the worker.
class CanSendProbeCommand extends TomCommand {
  @override
  Future<Object?> execute() async => TomWorker.canSendToCreator();
}

/// Sent from a worker as a fire-and-forget notification to the creator.
///
/// The worker returns `'sent'` immediately; the creator-side [InboxExecutor]
/// records the payload asynchronously.
class PingCreatorCommand extends TomCommand {
  final String data;

  PingCreatorCommand(this.data);

  @override
  Future<Object?> execute() async {
    TomWorker.sendToCreator({'kind': 'ping', 'data': data});
    return 'sent';
  }
}

/// Creator-side executor that records fire-and-forget `ping` notifications.
class InboxExecutor extends TomExecutor {
  final List<Object> received = [];

  @override
  Object execute(Object command) {
    if (command is Map && command['kind'] == 'ping') {
      received.add(command['data'] as Object);
      return 'ok';
    }
    return TomExecutor.noResult;
  }
}

/// A command that throws when run on the CREATOR side via the back-channel.
class ThrowingCreatorCommand extends TomCommand {
  @override
  Future<Object?> execute() async {
    throw Exception('creator boom');
  }
}

/// Runs in the worker and delegates a throwing command to the creator.
///
/// The creator catches the throw and returns the exception object as the
/// response payload (not a [RemoteError]), so [TomWorker.executeInCreator]
/// resolves *normally* with that exception as its value — the documented
/// behaviour of the creator→worker response path.
class DelegateThrowToCreator extends TomCommand {
  @override
  Future<Object?> execute() async {
    return await TomWorker.executeInCreator(ThrowingCreatorCommand());
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
    // `workerCount` is read-only (tcca16); the counter is reset through the
    // declared test seam so the generated worker names stay predictable.
    TomWorker.resetWorkerCount();
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

      test('base class default returns the "null" sentinel string', () async {
        // TomCommand.execute() is not abstract; its default returns the
        // literal string "null" so subclasses that forget to override still
        // produce a sendable, non-null response.
        expect(await DefaultCommand().execute(), equals('null'));
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

    group('startRemoteIsolate', () {
      test('throws TomWorkerException when the context has no send port',
          () async {
        // A context built directly (not through spawn) has no send port, so
        // starting an isolate with it must fail with the documented key. The
        // guard fires inside an async body, surfacing as a zone error rather
        // than a synchronous throw, so capture it with runZonedGuarded.
        final context = TestWorkerContext(namePrefix: 'NoPort');
        Object? asyncError;

        await runZonedGuarded(() async {
          TomWorker.startRemoteIsolate(context);
          await Future.delayed(const Duration(milliseconds: 10));
        }, (error, stack) {
          asyncError = error;
        });

        expect(asyncError, isA<TomWorkerException>());
        expect(
          (asyncError as TomWorkerException).key,
          equals(
            'isolate.state_error.attempt_to_start_isolate_but_sendport_is_null',
          ),
        );
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

    group('error propagation', () {
      test('surfaces a thrown command as an error on the future', () async {
        final context = TestWorkerContext(namePrefix: 'Throwing');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // The worker isolate catches the throw and sends back a RemoteError,
        // which must complete the awaiting future with an error (tests §3c).
        await expectLater(
          worker.executeCommand(ThrowingCommand('boom')),
          throwsA(isA<RemoteError>()),
        );

        worker.close();
      });
    });

    group('creator round-trip', () {
      test('worker can execute a command back in the creator', () async {
        final context = TestWorkerContext(namePrefix: 'RoundTrip');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // The worker delegates to the creator via executeInCreator; the
        // creator runs CreatorComputeCommand and the answer round-trips back
        // to this caller (tests §3b).
        final result = await worker.executeCommand(CreatorRoundTripCommand(5));

        expect(result, equals(1005));

        worker.close();
      });
    });

    group('close while busy', () {
      test('in-flight command still resolves after close-while-busy', () async {
        final context = TestWorkerContext(namePrefix: 'CloseBusy');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // Start a command, then close the worker while it is still in flight.
        // The response port can only be closed once this request resolves
        // (bug §5); the awaiting caller must still receive the result.
        final pending = worker.executeCommand(DelayedCommand(50, 'late'));
        expect(worker.isBusy(), isTrue);

        worker.close();
        expect(worker.isClosed, isTrue);

        final result = await pending;
        expect(result, equals('late'));
        expect(worker.isBusy(), isFalse);
      });
    });

    group('sendExecutorToIsolate', () {
      test('sent executor processes a non-TomCommand message end-to-end',
          () async {
        final context = TestWorkerContext();
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.sendExecutorToIsolate(TestStringExecutor());
        // Give the isolate a moment to register the executor before dispatch.
        await Future.delayed(Duration(milliseconds: 50));

        // A plain String is not a TomCommand, so the isolate routes it through
        // the registered executor, which prefixes "Processed: ".
        final result = await worker.executeCommand('payload');
        expect(result, equals('Processed: payload'));

        worker.close();
      });
    });

    group('unhandled messages', () {
      // A request that is never answered leaves the caller's completer pending
      // forever. Liveness supervision cannot rescue it: the isolate is healthy
      // and answers pings, so nothing observes the hang. The protocol must
      // therefore answer every command, whether or not anything handled it.

      test('answers when the worker has no executors registered', () async {
        final context = TestWorkerContext(namePrefix: 'NoExecutors');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // A plain String is not a TomCommand, and nothing was ever sent with
        // sendExecutorToIsolate, so no handler exists in the worker at all.
        final result = await worker
            .executeCommand('unhandled')
            .timeout(Duration(seconds: 5));
        // `same`, not `equals`: the sentinel carries no value equality, so a
        // caller can only recognise it if the const instance stays canonical
        // across the isolate hop. That is the invariant the answer rests on.
        expect(result, same(TomExecutor.noResult));

        worker.close();
      });

      test('answers when every registered executor declines', () async {
        final context = TestWorkerContext(namePrefix: 'AllDecline');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.sendExecutorToIsolate(NoOpExecutor());
        await Future.delayed(Duration(milliseconds: 50));

        // The executor runs and returns noResult, so the loop exhausts without
        // ever producing a value — the second way to reach an unanswered call.
        final result = await worker
            .executeCommand('declined')
            .timeout(Duration(seconds: 5));
        expect(result, equals(TomExecutor.noResult));

        worker.close();
      });

      test('a later executor still handles what an earlier one declines',
          () async {
        final context = TestWorkerContext(namePrefix: 'Chain');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // Order matters: the declining executor must not short-circuit the
        // chain into the unhandled answer while a later one can still handle
        // the message.
        worker.sendExecutorToIsolate(NoOpExecutor());
        worker.sendExecutorToIsolate(TestStringExecutor());
        await Future.delayed(Duration(milliseconds: 50));

        final result = await worker
            .executeCommand('payload')
            .timeout(Duration(seconds: 5));
        expect(result, equals('Processed: payload'));

        worker.close();
      });

      test('the worker stays usable after an unhandled message', () async {
        final context = TestWorkerContext(namePrefix: 'StillUsable');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        await worker.executeCommand('unhandled').timeout(Duration(seconds: 5));
        // The unhandled answer must consume exactly its own request slot; a
        // stray extra response would resolve the *next* command's completer
        // with the wrong payload.
        final result = await worker
            .executeCommand(ComputeCommand(2, 3))
            .timeout(Duration(seconds: 5));
        expect(result, equals(5));

        worker.close();
      });
    });

    group('back-channel', () {
      test('canSendToCreator is true inside a worker isolate', () async {
        final context = TestWorkerContext(namePrefix: 'CanSend');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // In the main isolate the back-channel is absent...
        expect(TomWorker.canSendToCreator(), isFalse);
        // ...but a command running in the worker sees it present.
        final inWorker = await worker.executeCommand(CanSendProbeCommand());
        expect(inWorker, isTrue);

        worker.close();
      });

      test('sendToCreator delivers a message to a creator-side executor',
          () async {
        final inbox = InboxExecutor();
        TomWorker.executors.add(inbox);

        final context = TestWorkerContext(namePrefix: 'Ping');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        final ack = await worker.executeCommand(PingCreatorCommand('hi'));
        // sendToCreator is one-way; the executor runs after the command returns.
        expect(ack, equals('sent'));
        await Future.delayed(Duration(milliseconds: 30));

        expect(inbox.received, equals(['hi']));

        worker.close();
      });

      test('executeInCreator resolves with a creator-thrown exception as value',
          () async {
        // When the creator-side command throws, the creator sends the exception
        // object back as the response payload (not a RemoteError), so the
        // worker completes normally with that exception as the value — pinning
        // the non-error branch of the shared response-completion helper.
        final context = TestWorkerContext(namePrefix: 'CreatorThrow');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        final result = await worker.executeCommand(DelegateThrowToCreator());
        expect(result, isA<Exception>());

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
        final result = await pool.execute(FixedValueCommand('test'));
        expect(result, equals('test'));

        pool.close();
      });

      test('should create pool with single worker', () async {
        final context = TestWorkerContext(namePrefix: 'Single');

        final pool = await TomWorkerPool.withSize(1, context);

        final result = await pool.execute(ComputeCommand(5, 5));
        expect(result, equals(10));

        pool.close();
      });
    });

    group('execute', () {
      late TomWorkerPool pool;

      setUp(() async {
        final context = TestWorkerContext(namePrefix: 'PoolTest');
        pool = await TomWorkerPool.withSize(2, context);
      });

      tearDown(() {
        pool.close();
      });

      test('should execute command and return result', () async {
        final result = await pool.execute(FixedValueCommand(42));

        expect(result, equals(42));
      });

      test('should execute multiple commands', () async {
        final result1 = await pool.execute(ComputeCommand(1, 1));
        final result2 = await pool.execute(ComputeCommand(2, 2));
        final result3 = await pool.execute(ComputeCommand(3, 3));

        expect(result1, equals(2));
        expect(result2, equals(4));
        expect(result3, equals(6));
      });

      test('should distribute commands across workers', () async {
        // Execute multiple commands in parallel across the pool's workers.
        final futures = <Future<Object?>>[];
        for (int i = 0; i < 4; i++) {
          futures.add(pool.execute(ComputeCommand(i, i)));
        }

        final results = await Future.wait(futures);

        expect(results, containsAll([0, 2, 4, 6]));
      });

      test('should handle commands when all workers are busy', () async {
        // Create a pool with just 1 worker
        final smallContext = TestWorkerContext(namePrefix: 'Small');
        final smallPool = await TomWorkerPool.withSize(1, smallContext);

        // Queue multiple commands; with one worker they run sequentially.
        final futures = [
          smallPool.execute(DelayedCommand(10, 'first')),
          smallPool.execute(DelayedCommand(10, 'second')),
          smallPool.execute(DelayedCommand(10, 'third')),
        ];

        final results = await Future.wait(futures);

        expect(results, containsAll(['first', 'second', 'third']));

        smallPool.close();
      });
    });

    group('liveness supervision', () {
      test('is off by default (opt-in)', () async {
        final context = TestWorkerContext(namePrefix: 'Unsupervised');
        final pool = await TomWorkerPool.withSize(1, context);

        expect(pool.isSupervised, isFalse);

        pool.close();
      });

      test('recovers when a worker isolate dies mid-command', () async {
        final context = TestWorkerContext(namePrefix: 'Supervised');
        final pool = await TomWorkerPool.withSize(
          2,
          context,
          healthCheckInterval: const Duration(milliseconds: 50),
        );

        expect(pool.isSupervised, isTrue);
        expect(pool.workerCount, equals(2));

        // A command that kills its own isolate must surface as a hard failure,
        // not an infinite hang, once supervision fails the in-flight request.
        await expectLater(
          pool.execute(SuicideCommand()),
          throwsA(isA<TomWorkerDiedException>()),
        );

        // The pool respawns a replacement asynchronously; wait for it to return
        // to full capacity.
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (pool.workerCount < 2 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(pool.workerCount, equals(2),
            reason: 'pool should respawn a replacement worker after a death');

        // And the recovered pool still executes work correctly.
        final result = await pool.execute(ComputeCommand(7, 8));
        expect(result, equals(15));

        pool.close();
      });

      test('periodic health checks leave healthy idle workers untouched',
          () async {
        final context = TestWorkerContext(namePrefix: 'HealthyPing');
        final pool = await TomWorkerPool.withSize(
          2,
          context,
          healthCheckInterval: const Duration(milliseconds: 20),
        );

        // Let several health-check ticks run over idle workers.
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(pool.workerCount, equals(2),
            reason: 'healthy workers must not be killed by pings');
        final result = await pool.execute(ComputeCommand(4, 5));
        expect(result, equals(9));

        pool.close();
      });

      test('execute after close throws instead of hanging', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedPool');
        final pool = await TomWorkerPool.withSize(1, context);
        pool.close();

        await expectLater(
          pool.execute(FixedValueCommand('x')),
          throwsA(isA<TomWorkerException>()),
        );
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
      final futures = <Future<Object?>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(pool.execute(ComputeCommand(i, i)));
      }

      final results = await Future.wait(futures);

      // Verify all results are correct
      for (int i = 0; i < 10; i++) {
        expect(results.contains(i * 2), isTrue);
      }

      pool.close();
    });
  });
}
