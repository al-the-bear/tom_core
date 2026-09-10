import 'dart:async';
import 'dart:io';
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

/// Test command that occupies its isolate SYNCHRONOUSLY for [blockMs].
///
/// Unlike [DelayedCommand] it never yields to the event loop, so nothing else
/// in that isolate runs while it works — including the health-ping reply. This
/// is the shape of the CPU-bound work isolate pooling exists for, and the
/// reason supervision must not probe a busy worker.
class BlockingCommand extends TomCommand {
  final int blockMs;

  BlockingCommand(this.blockMs);

  @override
  Future<Object?> execute() async {
    final deadline = DateTime.now().add(Duration(milliseconds: blockMs));
    while (DateTime.now().isBefore(deadline)) {
      // Spin. A Future.delayed here would defeat the point of the command.
    }
    return 'blocked';
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

/// A failure type nothing else in this file throws.
///
/// The type is the point. Both directions promise that the awaiting side can
/// `catch` the very exception the other isolate threw, and only a
/// distinguishable type can show that — an assertion against `Exception` would
/// be satisfied just as well by a stringified stand-in.
class MarkedFailure implements Exception {
  final String marker;

  MarkedFailure(this.marker);

  @override
  String toString() => 'MarkedFailure($marker)';
}

/// A command that throws a [MarkedFailure] inside the WORKER isolate.
class ThrowingMarkedCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw MarkedFailure('worker boom');
}

/// A failure that cannot cross an isolate port, because it holds a
/// [ReceivePort].
///
/// Ports are among the few things `SendPort.send` refuses outright, which makes
/// this the cheapest way to reach the degraded branch of the failure payload —
/// the one that has to exist because a `send` throwing inside a port handler is
/// caught by nobody and would strand the request forever.
class UnsendableFailure implements Exception {
  final ReceivePort port = ReceivePort();

  @override
  String toString() => 'UnsendableFailure(marker: unsendable-boom)';
}

/// A command that throws an [UnsendableFailure] inside the WORKER isolate.
class ThrowingUnsendableCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw UnsendableFailure();
}

/// A command that throws when run on the CREATOR side via the back-channel.
class ThrowingCreatorCommand extends TomCommand {
  @override
  Future<Object?> execute() async => throw MarkedFailure('creator boom');
}

/// Runs in the worker and delegates a throwing command to the creator.
///
/// The creator catches the throw and answers with a failure payload, so
/// [TomWorker.executeInCreator] *rethrows* — the exception does not arrive as
/// an ordinary value that a caller could mistake for a result.
///
/// The throw is caught here rather than allowed to unwind so that the
/// assertion concerns the creator-bound hop alone: letting it escape would send
/// it back over the worker-bound hop too, and a test watching only the far end
/// could not tell which of the two produced what it saw. The three returns name
/// the three outcomes that hop can have.
class DelegateThrowToCreator extends TomCommand {
  @override
  Future<Object?> execute() async {
    try {
      final resolved = await TomWorker.executeInCreator(
        ThrowingCreatorCommand(),
      );
      return 'resolved-normally:${resolved.runtimeType}';
    } on MarkedFailure catch (e) {
      return 'rethrown:${e.marker}';
    } catch (e) {
      return 'wrong-type:${e.runtimeType}';
    }
  }
}

/// A command that resolves to `null` when run on the CREATOR side.
class NullCreatorCommand extends TomCommand {
  @override
  Future<Object?> execute() async => null;
}

/// Runs in the worker and delegates a null-returning command to the creator.
///
/// The creator substitutes [TomExecutor.noResult] for the `null`, unlike the
/// worker-bound direction which substitutes the string `"null"`. The sentinel
/// is not null, so it survives the worker's own substitution unchanged and
/// reaches the original caller as-is.
class DelegateNullToCreator extends TomCommand {
  @override
  Future<Object?> execute() async {
    return await TomWorker.executeInCreator(NullCreatorCommand());
  }
}

/// Runs in the worker and delegates a payload the creator does not handle.
///
/// The payload is a plain `String`, not a [TomCommand], so the creator offers
/// it to its executor chain instead of executing it itself — the only path on
/// which the creator can run out of handlers. The chain then either is empty
/// or declines, and [TomWorker.executeInCreator] resolves with
/// [TomExecutor.notHandled]. The sentinel is not `null`, so it survives the
/// worker's own substitution and reaches the original caller unchanged.
class DelegateUnhandledToCreator extends TomCommand {
  @override
  Future<Object?> execute() async =>
      await TomWorker.executeInCreator('nothing handles this');
}

/// Log output that records every emitted message, so the diagnostics the
/// unhandled path emits can be asserted rather than merely assumed.
class RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      messages.add(convertToString(message));
    }
  }
}

/// Simple test worker context.
///
/// Only [initializeWorker] records anything, and deliberately so: it runs on
/// the creator side against *this* instance, so [workerInitialized] is readable
/// from a test. A matching `isolateInitialized` field would not be — see
/// [IsolateInitProbeContext] for why, and for the pattern that does work.
class TestWorkerContext extends TomWorkerContext {
  bool workerInitialized = false;

  TestWorkerContext({String namePrefix = 'Test'})
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        namePrefix,
      );

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    workerInitialized = true;
  }
}

/// Per-isolate marker filled in by [IsolateInitProbeContext.initializeIsolate].
///
/// Top-level state exists once *per isolate*, so the hook fills the worker's
/// copy and leaves the creator's `false`. That gap is what makes the hook's
/// effect provable in both directions.
bool isolateHookRan = false;

/// Reads [isolateHookRan] from inside the worker isolate.
class ReadIsolateHookFlagCommand extends TomCommand {
  @override
  Future<Object?> execute() async => isolateHookRan;
}

/// Context that records its isolate-side hook where it can actually be read.
///
/// A field on the context cannot work: [initializeIsolate] runs inside the new
/// isolate against the *copy* of the context that travelled there, so mutating
/// it leaves the creator's instance untouched. Writing per-isolate top-level
/// state instead lets a command read the result back out — the same pattern
/// `example/samples/isolate_pooling/03_worker_setup_and_guards_example.dart`
/// demonstrates.
class IsolateInitProbeContext extends TomWorkerContext {
  IsolateInitProbeContext({String namePrefix = 'IsolateInit'})
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        namePrefix,
      );

  @override
  Future<void> initializeIsolate() async {
    isolateHookRan = true;
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
  Future<void> initializeWorker(TomWorker worker) async {
    worker.sendExecutorToIsolate(TestStringExecutor());
  }
}

/// A context that starts a worker normally until [failNextSpawn] is set.
///
/// `initializeIsolate` runs inside the new isolate, against the *copy* of this
/// context that travelled there — so the flag a spawn sees is whatever the
/// creator's instance held when that spawn was sent. The pool retains its
/// context for respawns, which is what lets a test start a pool successfully
/// and then make its *replacement* spawn fail.
class FlakySpawnContext extends TomWorkerContext {
  FlakySpawnContext({String namePrefix = 'FlakySpawn'})
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        namePrefix,
      );

  /// Whether the next isolate to start should refuse to initialize.
  bool failNextSpawn = false;

  @override
  Future<void> initializeIsolate() async {
    if (failNextSpawn) throw StateError('this spawn was told to refuse');
  }
}

/// The ways a worker can fail to become ready, as exercised by
/// [FailingInitContext].
///
/// Modelled as one enum rather than a set of flags because the cases are
/// mutually exclusive — a hook cannot both throw and hang — and a bool per case
/// would make most of the combinations meaningless.
enum InitFailure {
  /// Both hooks succeed; the worker reaches ready normally.
  none,

  /// `initializeIsolate` throws inside the worker isolate.
  isolateHookThrows,

  /// `initializeWorker` throws on the creator side.
  workerHookThrows,

  /// `initializeIsolate` never returns. The isolate stays alive and silent, so
  /// no exit signal is ever emitted — only a timeout can end this wait.
  isolateHookHangs,

  /// The isolate terminates itself mid-initialization, standing in for any
  /// external kill between spawn and ready. There is nothing to time out on:
  /// the isolate is gone, and only an exit listener can notice.
  isolateDiesBeforeReady,
}

/// Worker context whose initialization can be made to fail in any of the ways
/// [InitFailure] describes.
///
/// [exitPort] is registered as the isolate's own exit listener *before* the
/// chosen failure is triggered, so a test can observe whether the isolate was
/// torn down — the creator never receives a [TomWorker] on a failed spawn and
/// so has no other handle on it.
class FailingInitContext extends TomWorkerContext {
  final SendPort exitPort;
  final InitFailure failure;

  FailingInitContext(
    this.exitPort, {
    this.failure = InitFailure.none,
    String namePrefix = 'FailInit',
  }) : super(
         const TomEnvironment('test', isTest: true),
         platformLinux,
         [],
         namePrefix,
       );

  @override
  Future<void> initializeIsolate() async {
    Isolate.current.addOnExitListener(exitPort, response: 'exited');
    switch (failure) {
      case InitFailure.isolateHookThrows:
        throw StateError('initializeIsolate refused');
      case InitFailure.isolateHookHangs:
        // A future nothing ever completes: the exact shape of a hook awaiting
        // a resource that is not there.
        await Completer<void>().future;
      case InitFailure.isolateDiesBeforeReady:
        // The beat before the kill is not cosmetic. addOnExitListener is a
        // control *message*, so the creator's listener only takes effect once
        // this isolate processes it; killing synchronously here outruns that
        // registration and the death goes unannounced. An external kill — the
        // case this stands in for — cannot arrive that early anyway, and the
        // unobservable window is what the ready timeout is the backstop for.
        await Future<void>.delayed(Duration(milliseconds: 200));
        Isolate.current.kill(priority: Isolate.immediate);
        // Give the kill a turn to take effect; if it somehow does not, the
        // hook still never returns, so the worker cannot reach ready either
        // way and the test's assertion stays honest.
        await Completer<void>().future;
      case InitFailure.none:
      case InitFailure.workerHookThrows:
        break;
    }
  }

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    if (failure == InitFailure.workerHookThrows) {
      throw StateError('initializeWorker refused');
    }
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // Reset static state between tests
  setUp(() {
    TomWorker.clearExecutors();
    // `workerCount` and `isMainIsolate` are read-only; both are reset through
    // their declared test seams so the generated worker names stay predictable
    // and every test starts on the creator side.
    TomWorker.resetWorkerCount();
    TomWorker.resetIsMainIsolate();
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

    group('notHandled', () {
      test('should be a constant sentinel value', () {
        expect(TomExecutor.notHandled, isNotNull);
        expect(TomExecutor.notHandled, same(TomExecutor.notHandled));
      });

      test('should be distinguishable from null', () {
        expect(TomExecutor.notHandled, isNot(equals(null)));
      });

      test('should be distinguishable from noResult', () {
        // The whole point of the second sentinel. `==` as well as `same`,
        // because both are const instances with no value equality: two
        // instances of *one* type would satisfy `isNot(same(...))` and still
        // compare equal after a copy across a port.
        expect(TomExecutor.notHandled, isNot(same(TomExecutor.noResult)));
        expect(TomExecutor.notHandled, isNot(equals(TomExecutor.noResult)));
        expect(
          TomExecutor.notHandled.runtimeType,
          isNot(TomExecutor.noResult.runtimeType),
        );
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
        expect(await FixedValueCommand([1, 2, 3]).execute(), equals([1, 2, 3]));
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

    group('initialization hooks', () {
      /// Spawns with [context] and returns the exit responses the isolate's own
      /// exit listener produced, so a test can tell a torn-down isolate from a
      /// leaked one.
      Future<List<Object?>> exitsWhileSpawning(
        Future<void> Function() attempt,
        ReceivePort exits,
      ) async {
        final seen = <Object?>[];
        exits.listen(seen.add);
        await attempt();
        // The kill is asynchronous; give the exit message a chance to arrive.
        await Future<void>.delayed(Duration(milliseconds: 300));
        exits.close();
        return seen;
      }

      test('the base hooks do nothing and complete', () async {
        // The contract is "override to do work, throw to refuse" — the base
        // implementations exist only so a subclass may override just one.
        final context = TomWorkerContext(
          const TomEnvironment('test'),
          platformLinux,
          [],
          'Test',
        );

        await expectLater(context.initializeIsolate(), completes);
      });

      test('initializeIsolate runs in the worker, not in the creator', () async {
        // The other initializeIsolate tests all pin a refusal — a throw aborts
        // the spawn, a hang trips readyTimeout. This one pins the success path,
        // and with it the asymmetry that makes the success path awkward to
        // observe at all.
        final context = IsolateInitProbeContext();
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );
        addTearDown(worker.close);

        final ranInWorker = await worker.executeCommand(
          ReadIsolateHookFlagCommand(),
        );
        expect(
          ranInWorker,
          isTrue,
          reason: 'the hook must have run before the worker accepts work',
        );

        // The same top-level variable, read here, is still false: top-level
        // state is per-isolate. This is the half that traps readers — a field
        // on the context would look identical from the creator's side, which
        // is to say indistinguishable from a hook that never ran.
        expect(
          isolateHookRan,
          isFalse,
          reason: 'the creator must not see the worker isolate\'s state',
        );
      });

      test('a throwing initializeWorker aborts the spawn', () async {
        final exits = ReceivePort();
        addTearDown(() {
          try {
            exits.close();
          } on Object {
            // Already closed by the helper.
          }
        });

        // Throwing is the only way either hook can refuse: they return void.
        await expectLater(
          TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            FailingInitContext(
              exits.sendPort,
              failure: InitFailure.workerHookThrows,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('a throwing initializeWorker leaves no live isolate behind', () async {
        // spawn never returns a TomWorker here, so the caller has no handle to
        // close(). If spawn did not tear the isolate down itself, it would sit
        // in its message loop holding its ports for the life of the process.
        final exits = ReceivePort();
        final seen = await exitsWhileSpawning(() async {
          try {
            await TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.workerHookThrows,
              ),
            );
          } on StateError {
            // The refusal itself is asserted by the previous test.
          }
        }, exits);

        expect(seen, contains('exited'));
      });

      test(
        'a throwing initializeIsolate aborts the spawn instead of hanging',
        () async {
          final exits = ReceivePort();
          addTearDown(() {
            try {
              exits.close();
            } on Object {
              // Already closed by the helper.
            }
          });

          // initializeIsolate runs inside the worker isolate, where a throw
          // cannot unwind to the creator: it ends the isolate's entry point, the
          // ready signal is never sent, and an unguarded spawn would wait for it
          // forever. The failure has to travel back as a message instead.
          await expectLater(
            TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.isolateHookThrows,
              ),
            ).timeout(Duration(seconds: 10)),
            throwsA(isA<TomWorkerException>()),
          );
        },
      );

      test(
        'the isolate-side refusal carries the reason and the worker name',
        () async {
          final exits = ReceivePort();
          addTearDown(() {
            try {
              exits.close();
            } on Object {
              // Already closed by the helper.
            }
          });

          // The exception is rebuilt in the creator, so without the isolate's own
          // message the caller would be told only that initialization failed —
          // not by what, nor in which of several workers.
          try {
            await TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.isolateHookThrows,
                namePrefix: 'NamedFail',
              ),
            ).timeout(Duration(seconds: 10));
            fail('a throwing initializeIsolate must abort the spawn');
          } on TomWorkerException catch (e) {
            expect(e.key, equals('isolate.initialize_isolate_failed.spawn'));
            expect(
              e.parameters?['error'],
              contains('initializeIsolate refused'),
            );
            expect(e.parameters?['isolateName'], startsWith('NamedFail'));
          }
        },
      );

      test(
        'a throwing initializeIsolate leaves no live isolate behind',
        () async {
          final exits = ReceivePort();
          final seen = await exitsWhileSpawning(() async {
            try {
              await TomWorker.spawn(
                TomWorker.startRemoteIsolate,
                FailingInitContext(
                  exits.sendPort,
                  failure: InitFailure.isolateHookThrows,
                ),
              ).timeout(Duration(seconds: 10));
            } on TomWorkerException {
              // The refusal itself is asserted by the previous tests.
            }
          }, exits);

          expect(seen, contains('exited'));
        },
      );

      test('a hanging initializeIsolate fails the spawn once readyTimeout '
          'expires', () async {
        final exits = ReceivePort();
        addTearDown(() {
          try {
            exits.close();
          } on Object {
            // Already closed by the helper.
          }
        });

        // A hook that never returns emits nothing at all: no ready signal, no
        // failure message, and no exit signal either, because the isolate is
        // still perfectly alive. Only a bound on the wait can end it.
        await expectLater(
          TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            FailingInitContext(
              exits.sendPort,
              failure: InitFailure.isolateHookHangs,
            ),
            readyTimeout: Duration(milliseconds: 500),
          ).timeout(Duration(seconds: 10)),
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              equals('isolate.ready_timeout.spawn'),
            ),
          ),
        );
      });

      test(
        'the ready timeout names the worker and the bound it exceeded',
        () async {
          final exits = ReceivePort();
          addTearDown(() {
            try {
              exits.close();
            } on Object {
              // Already closed by the helper.
            }
          });

          // "Timed out" on its own tells the caller nothing actionable: which of
          // several workers stalled, and whether the bound was simply too tight
          // for this workload, are the two questions the message has to answer.
          try {
            await TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.isolateHookHangs,
                namePrefix: 'SlowInit',
              ),
              readyTimeout: Duration(milliseconds: 500),
            ).timeout(Duration(seconds: 10));
            fail('a hanging initializeIsolate must abort the spawn');
          } on TomWorkerException catch (e) {
            expect(e.key, equals('isolate.ready_timeout.spawn'));
            expect(e.parameters?['isolateName'], startsWith('SlowInit'));
            expect(e.parameters?['readyTimeout'], equals('0:00:00.500000'));
          }
        },
      );

      test('a timed-out spawn leaves no live isolate behind', () async {
        // The hung isolate is unreachable — spawn returned no TomWorker — so if
        // the timeout only failed the future, the isolate would stay parked in
        // its hook for the life of the process.
        final exits = ReceivePort();
        final seen = await exitsWhileSpawning(() async {
          try {
            await TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.isolateHookHangs,
              ),
              readyTimeout: Duration(milliseconds: 500),
            ).timeout(Duration(seconds: 10));
          } on TomWorkerException {
            // The refusal itself is asserted by the previous tests.
          }
        }, exits);

        expect(seen, contains('exited'));
      });

      test('an isolate that dies before ready fails the spawn without waiting '
          'for the timeout', () async {
        final exits = ReceivePort();
        addTearDown(() {
          try {
            exits.close();
          } on Object {
            // Already closed by the helper.
          }
        });

        // The bound here is a minute, and the test allows ten seconds: passing
        // therefore proves the exit listener — not the timeout — noticed the
        // death. A dead isolate is knowable immediately, so making the caller
        // serve out the full timeout for it would be a needless stall.
        await expectLater(
          TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            FailingInitContext(
              exits.sendPort,
              failure: InitFailure.isolateDiesBeforeReady,
              namePrefix: 'DyingInit',
            ),
            readyTimeout: Duration(minutes: 1),
          ).timeout(Duration(seconds: 10)),
          throwsA(
            isA<TomWorkerException>()
                .having(
                  (e) => e.key,
                  'key',
                  equals('isolate.died_before_ready.spawn'),
                )
                .having(
                  (e) => e.parameters?['isolateName'],
                  'isolateName',
                  startsWith('DyingInit'),
                ),
          ),
        );
      });

      test('a non-positive readyTimeout is rejected', () async {
        final exits = ReceivePort();
        addTearDown(exits.close);

        // A zero or negative bound would expire before the isolate could
        // possibly answer, so every spawn would fail. Refusing it up front
        // beats spawning an isolate only to abandon it.
        for (final bound in [Duration.zero, Duration(seconds: -1)]) {
          await expectLater(
            TomWorker.spawn(
              TomWorker.startRemoteIsolate,
              FailingInitContext(exits.sendPort),
              readyTimeout: bound,
            ),
            throwsA(
              isA<TomWorkerException>().having(
                (e) => e.key,
                'key',
                equals('isolate.invalid_ready_timeout.spawn'),
              ),
            ),
            reason: 'readyTimeout $bound must be rejected',
          );
        }
      });

      test(
        'the pool passes its readyTimeout down to the workers it spawns',
        () async {
          final exits = ReceivePort();
          addTearDown(exits.close);

          // The pool owns every spawn its callers ever make, so a bound it did
          // not forward would be a bound nobody could set.
          await expectLater(
            TomWorkerPool.withSize(
              1,
              FailingInitContext(
                exits.sendPort,
                failure: InitFailure.isolateHookHangs,
              ),
              readyTimeout: Duration(milliseconds: 500),
            ).timeout(Duration(seconds: 10)),
            throwsA(
              isA<TomWorkerException>().having(
                (e) => e.key,
                'key',
                equals('isolate.ready_timeout.spawn'),
              ),
            ),
          );
        },
      );
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

        TomWorker.addExecutor(executor);

        expect(TomWorker.executors.length, equals(1));
        expect(TomWorker.executors.first, same(executor));
      });

      test('should allow adding multiple executors', () {
        TomWorker.addExecutor(TestStringExecutor());
        TomWorker.addExecutor(TestIntExecutor());

        expect(TomWorker.executors.length, equals(2));
      });

      test('should allow removing a single executor', () {
        final kept = TestStringExecutor();
        final dropped = TestIntExecutor();
        TomWorker.addExecutor(kept);
        TomWorker.addExecutor(dropped);

        expect(TomWorker.removeExecutor(dropped), isTrue);

        expect(TomWorker.executors, equals([kept]));
      });

      test('removing an unregistered executor reports false', () {
        expect(TomWorker.removeExecutor(TestStringExecutor()), isFalse);
      });

      test('should allow clearing executors', () {
        TomWorker.addExecutor(TestStringExecutor());
        TomWorker.addExecutor(TestIntExecutor());

        TomWorker.clearExecutors();

        expect(TomWorker.executors, isEmpty);
      });

      test('the exposed list rejects mutation', () {
        // The registry is handed out as an unmodifiable view so a caller
        // cannot bypass the explicit operations — and, more importantly,
        // cannot replace the list the message handlers dispatch through.
        expect(
          () => TomWorker.executors.add(TestStringExecutor()),
          throwsUnsupportedError,
        );
        expect(TomWorker.executors.clear, throwsUnsupportedError);
      });

      test('the exposed list is a live view, not a snapshot', () {
        final view = TomWorker.executors;
        expect(view, isEmpty);

        TomWorker.addExecutor(TestStringExecutor());

        // A copy taken at read time would still read empty here, which would
        // make a caller that held the list dispatch against stale contents.
        expect(view.length, equals(1));
      });
    });

    group('isMainIsolate', () {
      test('simulateWorkerIsolate marks the isolate as a worker', () {
        TomWorker.simulateWorkerIsolate();

        expect(TomWorker.isMainIsolate, isFalse);
      });

      test('resetIsMainIsolate restores the creator marking', () {
        TomWorker.simulateWorkerIsolate();

        TomWorker.resetIsMainIsolate();

        expect(TomWorker.isMainIsolate, isTrue);
      });
    });

    group('canSendToCreator', () {
      test('should return false in main isolate', () {
        expect(TomWorker.canSendToCreator(), isFalse);
      });
    });

    group('sendToCreator', () {
      test('should throw TomWorkerException when called from main isolate', () {
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
      test(
        'should throw TomWorkerException when called from main isolate',
        () async {
          expect(
            () => TomWorker.executeInCreator('test'),
            throwsA(isA<TomWorkerException>()),
          );
        },
      );

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

      test('should name workers prefix + zero-based 3-digit counter', () async {
        // The counter is read before it is incremented and `setUp` resets it,
        // so the first worker of a test is `<prefix>000`, not `<prefix>001`.
        final first = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          TestWorkerContext(namePrefix: 'Seq'),
        );
        final second = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          TestWorkerContext(namePrefix: 'Seq'),
        );

        expect(first.name, equals('Seq000'));
        expect(second.name, equals('Seq001'));

        first.close();
        second.close();
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
      test(
        'throws TomWorkerException when the context has no send port',
        () async {
          // A context built directly (not through spawn) has no send port, so
          // starting an isolate with it must fail with the documented key. The
          // guard fires inside an async body, surfacing as a zone error rather
          // than a synchronous throw, so capture it with runZonedGuarded.
          final context = TestWorkerContext(namePrefix: 'NoPort');
          Object? asyncError;

          await runZonedGuarded(
            () async {
              TomWorker.startRemoteIsolate(context);
              await Future.delayed(const Duration(milliseconds: 10));
            },
            (error, stack) {
              asyncError = error;
            },
          );

          expect(asyncError, isA<TomWorkerException>());
          expect(
            (asyncError as TomWorkerException).key,
            equals(
              'isolate.state_error.attempt_to_start_isolate_but_sendport_is_null',
            ),
          );
        },
      );
    });

    group('executeCommand', () {
      late TomWorker worker;

      setUp(() async {
        final context = TestWorkerContext();
        worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);
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
        worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);
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

    group('ping', () {
      // These two tests pin the reason supervision probes idle workers only.
      // It is NOT that a probe queues behind in-flight work — the worker
      // answers a ping before any dispatch, so asynchronous work does not
      // delay it at all. It is that synchronous work blocks the isolate's
      // event loop, which is exactly the CPU-bound workload this module
      // exists for.

      test('is answered while an asynchronous command is in flight', () async {
        final context = TestWorkerContext(namePrefix: 'PingAsync');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // DelayedCommand awaits, so the worker's message loop stays free.
        final pending = worker.executeCommand(DelayedCommand(300, 'done'));
        expect(worker.isBusy(), isTrue);

        expect(await worker.ping(const Duration(milliseconds: 100)), isTrue);
        // The probe does not disturb the command it overtook.
        expect(await pending, equals('done'));

        worker.close();
      });

      test(
        'is NOT answered while a synchronous command blocks the isolate',
        () async {
          final context = TestWorkerContext(namePrefix: 'PingBlocked');
          final worker = await TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            context,
          );

          // A tight compute loop never yields, so the ping cannot be read until
          // the loop ends. This is why supervision probes idle workers only —
          // probing here would force-kill a worker that is healthy and computing.
          // ping() itself makes no isBusy check, so a direct caller meets it.
          final pending = worker.executeCommand(BlockingCommand(1000));

          expect(await worker.ping(const Duration(milliseconds: 150)), isFalse);
          // The worker was healthy all along: its command still resolves, and a
          // later ping is answered once the isolate is free again.
          expect(await pending, equals('blocked'));
          expect(await worker.ping(const Duration(seconds: 5)), isTrue);

          worker.close();
        },
      );
    });

    group('superviseExit', () {
      // TomWorkerPool is a CLIENT of this mechanism, not its source: the pool
      // calls superviseExit on each worker and TomWorker itself raises the
      // TomWorkerDiedException. These tests pin the primitive on a bare worker,
      // with no pool involved, because that is the supported answer for a
      // caller who is not using a pool.

      test(
        'fails an in-flight command on a bare worker when the isolate dies',
        () async {
          final context = TestWorkerContext(namePrefix: 'SupervisedBare');
          final worker = await TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            context,
          );

          final order = <String>[];
          worker.superviseExit(() => order.add('onDeath'));

          // Without supervision this future would never complete.
          try {
            await worker.executeCommand(SuicideCommand());
            fail('a command on a dead isolate must not resolve');
          } on TomWorkerDiedException {
            order.add('caller');
          }

          // Ordering is load-bearing, not incidental. The request completers are
          // Completer.sync(), so completeError resumes the awaiting caller
          // BEFORE _handleUnexpectedDeath reaches the onDeath callback three
          // lines later. A caller that inspects supervisor-maintained state the
          // instant it catches this exception therefore reads it stale — which
          // is why the pool's recovery is polled rather than checked once.
          expect(
            order,
            equals(['caller']),
            reason: 'the caller resumes before the supervisor callback runs',
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(
            order,
            equals(['caller', 'onDeath']),
            reason: 'the onDeath callback must run on an unexpected exit',
          );
          expect(
            worker.isClosed,
            isTrue,
            reason: 'an unexpectedly dead worker marks itself closed',
          );
        },
      );

      test('does not fire onDeath for an orderly close', () async {
        final context = TestWorkerContext(namePrefix: 'SupervisedOrderly');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        var deaths = 0;
        worker.superviseExit(() => deaths++);

        worker.close();
        // close() tears the exit port down before the isolate terminates, so
        // the listener must stay silent; otherwise every clean shutdown would
        // look like a crash to a supervisor.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(deaths, isZero);
        expect(worker.isClosed, isTrue);
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

      test('executeCommand after close throws instead of hanging', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedExec');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.close();

        // The isolate has already been told to shut down, so nothing will ever
        // answer. Registering a completer and sending anyway would deadlock the
        // caller; refusing outright is the same fail-fast the pool one layer up
        // has always offered for the identical mistake.
        await expectLater(
          worker
              .executeCommand(ComputeCommand(1, 2))
              .timeout(Duration(seconds: 5)),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test(
        'sendExecutorToIsolate after close throws instead of dropping',
        () async {
          final context = TestWorkerContext(namePrefix: 'ClosedExecutor');
          final worker = await TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            context,
          );

          worker.close();

          // The send would land on a port whose isolate is shutting down: the
          // executor is silently lost and the caller believes it registered.
          expect(
            () => worker.sendExecutorToIsolate(TestStringExecutor()),
            throwsA(isA<TomWorkerException>()),
          );
        },
      );

      test('the refusal names the worker whose command was rejected', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedNamed');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        worker.close();

        // A pool closes many workers at once, so "which one" is the first
        // question the message has to answer. Assert against the prefix the
        // caller chose rather than against `worker.isolate.debugName`, which is
        // null on this side of the boundary and would make the check vacuous.
        try {
          await worker.executeCommand(ComputeCommand(1, 2));
          fail('executeCommand on a closed worker must throw');
        } on TomWorkerException catch (e) {
          expect(e.key, equals('isolate.worker_closed.execute_after_close'));
          expect(e.parameters?['isolateName'], equals(worker.name));
          expect(worker.name, startsWith('ClosedNamed'));
        }
      });

      test('a command in flight when close is called still resolves', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedInFlight');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // The guard must reject only *new* dispatch. Work already accepted was
        // accepted before the worker closed, and close() deliberately defers
        // tearing down the response port until such requests have resolved.
        final inFlight = worker.executeCommand(DelayedCommand(120, 'done'));
        worker.close();

        expect(await inFlight.timeout(Duration(seconds: 5)), equals('done'));
      });
    });

    group('error propagation', () {
      test('surfaces a thrown command as an error on the future', () async {
        final context = TestWorkerContext(namePrefix: 'Throwing');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        // The worker isolate catches the throw and answers with a failure
        // payload, which must complete the awaiting future with an error.
        await expectLater(
          worker.executeCommand(ThrowingCommand('boom')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains('boom'),
            ),
          ),
        );

        worker.close();
      });

      test('the caller catches the type the worker threw', () async {
        // Not merely "an error": the failure payload carries the exception
        // object, so `on MarkedFailure` matches on this side. A caller that can
        // only inspect a string cannot branch on which failure it was.
        final context = TestWorkerContext(namePrefix: 'ThrowingTyped');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        await expectLater(
          worker.executeCommand(ThrowingMarkedCommand()),
          throwsA(
            isA<MarkedFailure>().having(
              (e) => e.marker,
              'marker',
              'worker boom',
            ),
          ),
        );

        worker.close();
      });

      test('an unsendable exception degrades to a RemoteError', () async {
        // The object cannot cross the port, and the send that discovers this
        // happens inside a port handler where a throw would be caught by
        // nobody — the request would simply never be answered. So the failure
        // is re-packaged as strings and the caller still gets an error, just a
        // less specific one, with the original `toString` preserved so the
        // report still names what went wrong.
        final context = TestWorkerContext(namePrefix: 'ThrowingUnsendable');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        await expectLater(
          worker
              .executeCommand(ThrowingUnsendableCommand())
              .timeout(Duration(seconds: 5)),
          throwsA(
            isA<RemoteError>().having(
              (e) => e.toString(),
              'toString',
              contains('unsendable-boom'),
            ),
          ),
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
        // to this caller.
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
        // The response port can only be closed once this request resolves; the
        // awaiting caller must still receive the result.
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
      test(
        'sent executor processes a non-TomCommand message end-to-end',
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
        },
      );
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
        expect(result, same(TomExecutor.notHandled));

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
        // The chain's decline and the dispatch's answer are different
        // sentinels: `noResult` goes *in* to mean "try the next", and
        // `notHandled` comes *out* to mean "nobody did".
        final result = await worker
            .executeCommand('declined')
            .timeout(Duration(seconds: 5));
        expect(result, same(TomExecutor.notHandled));

        worker.close();
      });

      test(
        'a later executor still handles what an earlier one declines',
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
        },
      );

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

      test(
        'sendToCreator delivers a message to a creator-side executor',
        () async {
          final inbox = InboxExecutor();
          TomWorker.addExecutor(inbox);

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
        },
      );

      test('executeInCreator rethrows a creator-thrown exception', () async {
        // A creator-side throw must reach the worker as a throw. The two
        // outcomes the other returns rule out are the ones that matter: an
        // exception arriving as an ordinary *value* is indistinguishable from a
        // result, and a stringified stand-in cannot be caught by type — which
        // is how a caller tells one failure apart from another.
        final context = TestWorkerContext(namePrefix: 'CreatorThrow');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        final result = await worker.executeCommand(DelegateThrowToCreator());
        expect(result, equals('rethrown:creator boom'));

        worker.close();
      });

      test(
        'a null creator result comes back as the noResult sentinel',
        () async {
          // The two directions substitute different things for a null result:
          // worker-bound gives the string "null", creator-bound gives the
          // sentinel. Pinning the creator side keeps the pair from silently
          // converging on one of the two.
          final context = TestWorkerContext(namePrefix: 'CreatorNull');
          final worker = await TomWorker.spawn(
            TomWorker.startRemoteIsolate,
            context,
          );

          final result = await worker.executeCommand(DelegateNullToCreator());
          expect(result, same(TomExecutor.noResult));

          worker.close();
        },
      );

      test('executeInCreator resolves with notHandled when the creator has no '
          'executor registered', () async {
        // The mirror image of the worker-side unhandled answer: the creator
        // also replies rather than staying silent, so the worker's await
        // resolves instead of hanging. `same`, not `equals` — the sentinel
        // carries no value equality, so a caller can only recognise it if the
        // const instance stays canonical across both isolate hops.
        final context = TestWorkerContext(namePrefix: 'CreatorNoExec');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        final result = await worker
            .executeCommand(DelegateUnhandledToCreator())
            .timeout(Duration(seconds: 5));
        expect(result, same(TomExecutor.notHandled));
        // Not `noResult`, which on this call means the handler answered
        // `null`. The two were one value until a process that forgot an
        // addExecutor was found reporting plausible answers for ever.
        expect(result, isNot(same(TomExecutor.noResult)));

        worker.close();
      });

      test('executeInCreator resolves with notHandled when every creator '
          'executor declines', () async {
        final declining = NoOpExecutor();
        TomWorker.addExecutor(declining);

        final context = TestWorkerContext(namePrefix: 'CreatorDecline');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        final result = await worker
            .executeCommand(DelegateUnhandledToCreator())
            .timeout(Duration(seconds: 5));
        expect(result, same(TomExecutor.notHandled));
        // The chain really was consulted — otherwise the assertion above would
        // also pass for a creator that never dispatched at all.
        expect(declining.executeCallCount, equals(1));

        worker.close();
      });

      test('the creator warns whenever nothing handled the message', () async {
        // Both ways of reaching the unhandled answer must be diagnosable. The
        // empty-chain case is the one that matters most — it is the shape a
        // forgotten addExecutor takes — so it must not be the silent one.
        final recorder = RecordingLogOutput();
        final previousOutput = tomLog.logOutput;
        tomLog.logOutput = recorder;
        addTearDown(() => tomLog.logOutput = previousOutput);

        final context = TestWorkerContext(namePrefix: 'CreatorWarn');
        final worker = await TomWorker.spawn(
          TomWorker.startRemoteIsolate,
          context,
        );

        await worker
            .executeCommand(DelegateUnhandledToCreator())
            .timeout(Duration(seconds: 5));

        expect(
          recorder.messages.where((m) => m.contains('NOT_HANDLED')),
          isNotEmpty,
        );

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

      test('rejects a zero size instead of building an unusable pool', () async {
        final context = TestWorkerContext(namePrefix: 'ZeroSize');

        // A pool with no workers can never acquire one: workers are added at
        // construction and on respawn-after-death only, so execute() would
        // poll its 1 ms wait loop forever on a pool that is permanently empty.
        await expectLater(
          TomWorkerPool.withSize(0, context),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('rejects a negative size', () async {
        final context = TestWorkerContext(namePrefix: 'NegSize');

        // The spawn loop simply does not execute for a negative size, so the
        // failure is identical to zero — reject it at the same door.
        await expectLater(
          TomWorkerPool.withSize(-1, context),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('the rejection names the invalid size', () async {
        final context = TestWorkerContext(namePrefix: 'NamedSize');

        // The caller's mistake is usually an arithmetic slip such as
        // `numberOfProcessors - 1` on a single-core container. Echoing the
        // computed value is what connects the error back to that expression.
        try {
          await TomWorkerPool.withSize(0, context);
          fail('withSize(0, ...) must throw');
        } on TomWorkerException catch (e) {
          expect(e.key, equals('isolate.invalid_pool_size.with_size'));
          expect(e.parameters?['size'], equals(0));
          expect(e.toString(), contains('0'));
        }
      });

      test('rejects a non-positive healthCheckInterval', () async {
        final context = TestWorkerContext(namePrefix: 'ZeroInterval');

        // Duration.zero is not a supervision cadence: Timer.periodic would run
        // a health pass on every event-loop turn, pinning the CPU for probes
        // no caller asked to repeat that often.
        await expectLater(
          TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: Duration.zero,
          ),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('rejects a non-positive healthCheckTimeout', () async {
        final context = TestWorkerContext(namePrefix: 'ZeroTimeout');

        // A zero timeout gives every worker zero time to answer, so each probe
        // declares a healthy worker dead and force-kills it. The pool respawns
        // and probes again: an endless kill/respawn treadmill whose
        // workerCount still reads healthy the whole time.
        await expectLater(
          TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: Duration(seconds: 1),
            healthCheckTimeout: Duration.zero,
          ),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test(
        'a supervision timeout is only validated when supervision is on',
        () async {
          final context = TestWorkerContext(namePrefix: 'UnsupTimeout');

          // healthCheckTimeout has a default, so an unsupervised caller never
          // chose it and must not be failed by it. Nothing reads it here.
          final pool = await TomWorkerPool.withSize(
            1,
            context,
            healthCheckTimeout: Duration.zero,
          );

          expect(pool.isSupervised, isFalse);
          expect(await pool.execute(ComputeCommand(2, 3)), equals(5));

          pool.close();
        },
      );
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

      test(
        'serves callers queued on a saturated pool in arrival order',
        () async {
          // One worker, six callers: the first takes it, the other five park. The
          // order they are served in is the whole point of a queue — a design
          // that leaves a released worker in the free list for waiters to find
          // serves whoever happens to look next, and under sustained load one
          // caller can be passed over indefinitely.
          final smallContext = TestWorkerContext(namePrefix: 'Fifo');
          final smallPool = await TomWorkerPool.withSize(1, smallContext);
          addTearDown(smallPool.close);

          final served = <int>[];
          final pending = <Future<void>>[];
          for (var caller = 0; caller < 6; caller++) {
            // `execute` runs synchronously up to its first await, so the calls
            // enqueue in loop order — which is what makes "arrival order"
            // well-defined here rather than a race the test would be asserting.
            pending.add(
              smallPool
                  .execute(DelayedCommand(5, caller))
                  .then((result) => served.add(result! as int)),
            );
          }
          await Future.wait(pending);

          expect(served, equals([0, 1, 2, 3, 4, 5]));
        },
      );

      test('closing the pool releases the callers waiting on it', () async {
        // A parked caller has no timer of its own, so nothing but the close can
        // wake it: without this, closing a saturated pool would leave every
        // queued caller awaiting a worker that will never be released.
        final smallContext = TestWorkerContext(namePrefix: 'CloseWaiters');
        final smallPool = await TomWorkerPool.withSize(1, smallContext);

        final running = smallPool.execute(DelayedCommand(50, 'running'));
        // One turn of the event loop, so the first command actually reaches its
        // worker: `execute` reserves the worker synchronously but dispatches
        // only after its first await, and closing in the same turn would close
        // the pool with nothing yet in flight.
        await Future<void>.delayed(Duration.zero);
        final queued = smallPool.execute(DelayedCommand(5, 'queued'));

        smallPool.close();

        await expectLater(
          queued,
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.pool_closed.execute_after_close',
            ),
          ),
        );
        // The command already dispatched is not cancelled by the close; it is
        // the *waiting* that ends.
        expect(await running, equals('running'));
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

    group('dispatch mechanism', () {
      test('the pool waits on a completer, never on a clock', () {
        // Dispatch used to wait for a free worker by polling
        // `Future.delayed(Duration(milliseconds: 1))`, waking the event loop a
        // thousand times a second per waiting caller. The ordering test above
        // pins the queue's *behaviour*; this pins the mechanism, because a poll
        // that then served the queue head would satisfy that test while putting
        // the busy-wait back.
        //
        // Read out of the source because there is no runtime surface for "how
        // this waits": the only observable difference is timing, and a timing
        // assertion is the flakiest thing that could stand here.
        final path = 'lib/src/tombase/isolate_pooling/tom_worker.dart';
        final source = File(path).readAsStringSync();
        final start = source.indexOf('class TomWorkerPool {');
        expect(
          start,
          greaterThanOrEqualTo(0),
          reason: 'TomWorkerPool moved or was renamed — retarget this guard',
        );

        expect(
          source.substring(start).contains('Future.delayed'),
          isFalse,
          reason:
              'TomWorkerPool must not wait by sleeping. Park the caller on a '
              'completer and hand a released worker to it; a genuine deadline '
              'is a Timer or .timeout(), not a poll.',
        );
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
        expect(
          pool.workerCount,
          equals(2),
          reason: 'pool should respawn a replacement worker after a death',
        );

        // And the recovered pool still executes work correctly.
        final result = await pool.execute(ComputeCommand(7, 8));
        expect(result, equals(15));

        pool.close();
      });

      test('stops replacing workers once the respawn budget is spent', () async {
        // A command that reliably kills its worker is the shape this bounds: a
        // pool that replaces unconditionally hands the next such command to
        // each replacement forever, reporting healthy capacity all the while.
        final context = TestWorkerContext(namePrefix: 'Churn');
        final pool = await TomWorkerPool.withSize(
          1,
          context,
          healthCheckInterval: const Duration(milliseconds: 50),
          respawnLimit: 2,
        );
        addTearDown(pool.close);

        // Three deaths: the first two are replaced, the third finds the budget
        // spent. Each caller is served by the replacement the previous death
        // produced, so the loop needs no waiting of its own.
        for (var attempt = 1; attempt <= 3; attempt++) {
          await expectLater(
            pool.execute(SuicideCommand()),
            throwsA(isA<TomWorkerDiedException>()),
            reason: 'attempt $attempt should die with its worker',
          );
        }

        // The give-up runs on the (unawaited) death path.
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!pool.isRespawnExhausted && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        expect(
          pool.isRespawnExhausted,
          isTrue,
          reason: 'the third death exceeded a budget of two',
        );
        expect(
          pool.workerCount,
          isZero,
          reason: 'the third worker was not replaced',
        );

        // And a later command is refused rather than parked: waiting would be
        // waiting for a worker that cannot arrive.
        await expectLater(
          pool.execute(FixedValueCommand(1)),
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.respawn_exhausted.execute_without_workers',
            ),
          ),
        );
      });

      test('releases the callers parked when it gives up', () async {
        // The hazard the refusal exists for: a caller queued behind the command
        // that kills the last worker has no timer of its own, so without an
        // explicit release it waits forever on a pool that has stopped
        // replacing.
        final context = TestWorkerContext(namePrefix: 'ChurnQueue');
        final pool = await TomWorkerPool.withSize(
          1,
          context,
          healthCheckInterval: const Duration(milliseconds: 50),
          respawnLimit: 1,
        );
        addTearDown(pool.close);

        // First death: replaced, spending the budget of one.
        await expectLater(
          pool.execute(SuicideCommand()),
          throwsA(isA<TomWorkerDiedException>()),
        );

        // Second death, with a caller queued behind it. `execute` takes the
        // free worker synchronously, so the second call parks.
        final fatal = pool.execute(SuicideCommand());
        final parked = pool.execute(FixedValueCommand(7));

        await expectLater(fatal, throwsA(isA<TomWorkerDiedException>()));
        await expectLater(
          parked,
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.respawn_exhausted.execute_without_workers',
            ),
          ),
        );
      });

      test('spends the budget on churn, not on wear', () async {
        // The budget is a rate. A pool that loses one worker a week to an
        // ordinary cause must not exhaust a counter that never resets; only
        // deaths close together are churn.
        final context = TestWorkerContext(namePrefix: 'Rate');
        final pool = await TomWorkerPool.withSize(
          1,
          context,
          healthCheckInterval: const Duration(milliseconds: 50),
          respawnLimit: 1,
          respawnWindow: const Duration(milliseconds: 50),
        );
        addTearDown(pool.close);

        await expectLater(
          pool.execute(SuicideCommand()),
          throwsA(isA<TomWorkerDiedException>()),
        );
        // Comfortably past the window, so the first replacement no longer
        // counts against the second.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await expectLater(
          pool.execute(SuicideCommand()),
          throwsA(isA<TomWorkerDiedException>()),
        );

        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (pool.workerCount < 1 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        expect(
          pool.isRespawnExhausted,
          isFalse,
          reason: 'the two deaths were a whole window apart',
        );
        expect(pool.workerCount, equals(1));
        expect(await pool.execute(ComputeCommand(2, 3)), equals(5));
      });

      test(
        'gives up when a replacement spawn fails and nothing is left',
        () async {
          // The quieter half of unbounded respawn: the spawn itself fails, is
          // caught and logged, and is not retried — because only a death
          // triggers a respawn and a pool with no workers can have none. Before
          // this, the pool sat there empty and every caller waited forever on the
          // strength of one log line.
          final context = FlakySpawnContext();
          final pool = await TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: const Duration(milliseconds: 50),
          );
          addTearDown(pool.close);

          // The replacement will refuse to initialize. The budget is untouched:
          // this is the *spawn* failing, not the churn.
          context.failNextSpawn = true;
          final fatal = pool.execute(SuicideCommand());
          final parked = pool.execute(FixedValueCommand(7));

          await expectLater(fatal, throwsA(isA<TomWorkerDiedException>()));
          await expectLater(
            parked,
            throwsA(
              isA<TomWorkerException>().having(
                (e) => e.key,
                'key',
                'isolate.respawn_exhausted.execute_without_workers',
              ),
            ),
          );
          expect(pool.isRespawnExhausted, isTrue);
          expect(pool.workerCount, isZero);
        },
      );

      test('rejects a respawn budget that would never replace anything', () {
        final context = TestWorkerContext(namePrefix: 'BadBudget');

        expect(
          TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: const Duration(milliseconds: 50),
            respawnLimit: 0,
          ),
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.invalid_respawn_limit.with_size',
            ),
          ),
        );
        expect(
          TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: const Duration(milliseconds: 50),
            respawnWindow: Duration.zero,
          ),
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.invalid_respawn_window.with_size',
            ),
          ),
        );
      });

      test(
        'periodic health checks leave healthy idle workers untouched',
        () async {
          final context = TestWorkerContext(namePrefix: 'HealthyPing');
          final pool = await TomWorkerPool.withSize(
            2,
            context,
            healthCheckInterval: const Duration(milliseconds: 20),
          );

          // Let several health-check ticks run over idle workers.
          await Future<void>.delayed(const Duration(milliseconds: 120));

          expect(
            pool.workerCount,
            equals(2),
            reason: 'healthy workers must not be killed by pings',
          );
          final result = await pool.execute(ComputeCommand(4, 5));
          expect(result, equals(9));

          pool.close();
        },
      );

      test(
        'supervision never probes a worker running synchronous work',
        () async {
          // The payoff of probing idle workers only. A busy worker is out of the
          // free list, so the health pass cannot reserve it — even though the
          // command blocks the isolate for eight times the ping timeout, which
          // would force-kill the worker if it were probed while busy.
          final context = TestWorkerContext(namePrefix: 'BusySync');
          final pool = await TomWorkerPool.withSize(
            1,
            context,
            healthCheckInterval: const Duration(milliseconds: 20),
            healthCheckTimeout: const Duration(milliseconds: 100),
          );

          final result = await pool.execute(BlockingCommand(800));

          expect(
            result,
            equals('blocked'),
            reason: 'a computing worker must not be killed as unresponsive',
          );
          expect(pool.workerCount, equals(1));

          pool.close();
        },
      );
    });

    group('close', () {
      // The pool's counterpart to `TomWorker > close`, and deliberately not
      // part of `liveness supervision`: the closed-pool guard stands whether
      // or not a healthCheckInterval was ever passed. Every pool here is
      // built unsupervised, so a failure in this group can only mean the
      // lifecycle guard broke.

      test('execute after close throws instead of hanging', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedPool');
        final pool = await TomWorkerPool.withSize(1, context);
        pool.close();

        await expectLater(
          pool.execute(FixedValueCommand('x')),
          throwsA(isA<TomWorkerException>()),
        );
      });

      test('a caller already waiting for a free worker fails when the pool '
          'closes', () async {
        // The guard sits in two places, and this is the branch that actually
        // rescues a caller: `execute` re-checks `_closed` on every turn of the
        // loop it parks in while all workers are busy. Without that check the
        // caller would spin forever, because close() clears the free list and
        // nothing will ever refill it — the entry check above cannot help
        // someone who got past it before the close.
        final context = TestWorkerContext(namePrefix: 'ClosedWhileWaiting');
        final pool = await TomWorkerPool.withSize(1, context);

        // Occupy the only worker, so the next call has to wait for it.
        final inFlight = pool.execute(DelayedCommand(200, 'first'));
        final waiting = pool.execute(FixedValueCommand('second'));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        pool.close();

        await expectLater(
          waiting.timeout(const Duration(seconds: 5)),
          throwsA(
            isA<TomWorkerException>().having(
              (e) => e.key,
              'key',
              'isolate.pool_closed.execute_after_close',
            ),
          ),
        );
        // Work already accepted is unaffected: close() only refuses new
        // dispatch, so the command that had a worker still resolves.
        expect(await inFlight, equals('first'));
      });

      test('isClosed answers before and after close, and stays true', () async {
        // The pool's counterpart to `TomWorker > close > should set isClosed
        // to true`. Before this getter existed the only way to learn a pool
        // would refuse work was to call execute() and catch — to perform the
        // operation you were deciding whether to perform.
        final context = TestWorkerContext(namePrefix: 'PoolIsClosed');
        final pool = await TomWorkerPool.withSize(2, context);

        expect(pool.isClosed, isFalse);

        pool.close();
        expect(pool.isClosed, isTrue);

        // Idempotent like close() itself: a pool is commonly closed from both
        // a tearDown and the code under test.
        pool.close();
        expect(pool.isClosed, isTrue);
      });

      test('isClosed says what workerCount cannot', () async {
        // workerCount is not a substitute. Both readings agree here — two
        // workers and open, then zero and closed — but only isClosed carries
        // the lifecycle fact: a supervised pool whose workers have all died
        // and whose replacements have not yet spawned also reads zero, so
        // workerCount alone cannot separate "shut down" from "momentarily
        // empty". This pins the pair a caller reads, not that race.
        final context = TestWorkerContext(namePrefix: 'PoolCountVsClosed');
        final pool = await TomWorkerPool.withSize(2, context);

        expect(pool.workerCount, equals(2));
        expect(pool.isClosed, isFalse);

        pool.close();

        expect(pool.workerCount, isZero);
        expect(pool.isClosed, isTrue);
      });

      test('close empties the pool and is idempotent', () async {
        final context = TestWorkerContext(namePrefix: 'ClosedTwice');
        final pool = await TomWorkerPool.withSize(2, context);

        expect(pool.workerCount, equals(2));

        pool.close();
        pool.close();
        pool.close();

        // A pool is commonly closed from both a tearDown and the code under
        // test, so a second call must be a no-op rather than an error.
        expect(pool.workerCount, isZero);
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
