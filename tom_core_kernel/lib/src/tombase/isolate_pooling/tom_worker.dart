/// Isolate pooling and worker management for concurrent task execution.
///
/// This library provides a robust framework for managing isolates in Dart/Flutter
/// applications. It enables parallel processing by spawning worker isolates that
/// can execute commands independently from the main isolate.
///
/// ## Key Features
///
/// - **Worker Isolates**: Spawn and manage isolated execution contexts
/// - **Bidirectional Communication**: Send commands to workers and receive responses
/// - **Command Pattern**: Execute commands as objects with built-in result handling
/// - **Executor Pattern**: Register handlers to process incoming messages
/// - **Worker Pools**: Manage multiple workers with automatic load distribution
///
/// ## Example Usage
///
/// ```dart
/// // Create a worker context
/// final context = TomWorkerContext(
///   TomEnvironment.development,
///   TomPlatform.mobile,
///   [],
///   'MyWorker',
/// );
///
/// // Spawn a worker
/// final worker = await TomWorker.spawn(
///   TomWorker.startRemoteIsolate,
///   context,
/// );
///
/// // Execute a command
/// final result = await worker.executeCommand(myCommand);
///
/// // Clean up
/// worker.close();
/// ```
///
/// See also:
/// - [TomWorker] for individual worker management
/// - [TomWorkerPool] for managing multiple workers
/// - [TomExecutor] for custom command handlers
/// - [TomCommand] for encapsulated command objects
library;

// =============================================================================
// IMPORTS
// =============================================================================

// Dart SDK imports
import 'dart:async';
import 'dart:isolate';

// Package imports
import 'package:meta/meta.dart';
import 'package:tom_basics/tom_basics.dart';

// Relative imports
import '../little_things/exception_base.dart';
import '../little_things/little_things.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when worker-related operations fail.
///
/// This exception is thrown in scenarios such as:
/// - Attempting to start an isolate without a configured SendPort
/// - Trying to send messages to creator from the creator isolate itself
/// - General worker communication failures
///
/// Example:
/// ```dart
/// try {
///   TomWorker.sendToCreator(message);
/// } on TomWorkerException catch (e) {
///   print('Worker error: ${e.defaultUserMessage}');
/// }
/// ```
class TomWorkerException extends TomException {
  /// Creates a [TomWorkerException] with the given error details.
  ///
  /// - [key]: Unique identifier for this error type
  /// - [defaultUserMessage]: Human-readable error description
  TomWorkerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// Exception used to fail a command whose worker isolate died mid-flight.
///
/// When liveness supervision is enabled on a [TomWorkerPool] (or a worker is
/// supervised directly via [TomWorker.superviseExit]) and the worker's isolate
/// terminates unexpectedly — an uncaught error, [Isolate.kill], or an
/// out-of-memory kill — every request still awaiting a response is completed
/// with this exception rather than hanging forever on its completer.
///
/// The command is **not** re-dispatched: re-running a command that may have
/// already produced side effects before the isolate died would risk executing
/// non-idempotent work twice. Recovery instead means the pool respawns a
/// replacement worker to restore capacity, while the in-flight caller observes
/// this failure and decides how to react.
class TomWorkerDiedException extends TomException {
  /// Creates a [TomWorkerDiedException] with the given error details.
  TomWorkerDiedException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

// =============================================================================
// INTERNAL HELPER CLASSES
// =============================================================================

/// Internal sentinel class to distinguish between "null" and "no result".
///
/// Used to signal that an executor did not process a command, allowing
/// the next executor in the chain to handle it.
class _TomNoResult {
  const _TomNoResult();
}

// =============================================================================
// EXECUTOR PATTERN
// =============================================================================

/// Base class for command executors that handle messages in worker isolates.
///
/// Executors provide a way to define custom handlers for incoming commands.
/// Multiple executors can be registered, and they are called in order until
/// one produces a result (i.e., returns something other than [noResult]).
///
/// ## Pattern Overview
///
/// The executor pattern allows separation of command handling logic from
/// the worker infrastructure. Each executor can focus on a specific type
/// of command or domain.
///
/// ## Example
///
/// ```dart
/// class MyExecutor extends TomExecutor {
///   @override
///   Object execute(Object command) {
///     if (command is MyCommand) {
///       return processMyCommand(command);
///     }
///     return TomExecutor.noResult; // Let next executor handle it
///   }
/// }
///
/// // Register the executor
/// TomWorker.executors.add(MyExecutor());
/// ```
///
/// ## Important Notes
///
/// - Return [noResult] to indicate the command was not handled
/// - Executors exist in both isolates and may handle different commands
/// - The creator-side worker handles responses from the created worker
abstract class TomExecutor {
  /// Sentinel value indicating that an executor did not process a command.
  ///
  /// Return this value from [execute] to allow the next executor in the
  /// chain to handle the command. When the whole chain declines — or when no
  /// executor is registered at all — this same sentinel is what the dispatch
  /// answers with, so it also reaches the caller of
  /// [TomWorker.executeCommand] as the value meaning "nothing handled this".
  ///
  /// It carries no value equality, so recognising it relies on the `const`
  /// instance staying canonical when a response crosses an isolate boundary.
  static const Object noResult = _TomNoResult();

  /// Executes a command and returns the result.
  ///
  /// This method is called when a command is received by the worker.
  /// The [command] parameter contains the data sent to the isolate.
  ///
  /// Returns:
  /// - The result of processing the command
  /// - [noResult] if this executor cannot handle the command
  ///
  /// Note: This method is called in both creator and worker isolates.
  /// The TomWorker exists in both isolates and both sides can have
  /// different workers with different executor sets.
  Object execute(Object command);
}

// =============================================================================
// COMMAND PATTERN
// =============================================================================

/// Base class for self-executing commands sent to worker isolates.
///
/// Unlike executors which are registered handlers, commands encapsulate
/// both data and behavior. When a command is received by a worker,
/// its [execute] method is called automatically.
///
/// ## When to Use
///
/// Use [TomCommand] when:
/// - The command logic is self-contained
/// - You want to send data and functionality together
/// - Higher isolation between command types is desired
///
/// Use [TomExecutor] when:
/// - Multiple command types share common handling logic
/// - You need a central point for command processing
/// - Commands are simple data objects
///
/// ## Example
///
/// ```dart
/// class ComputeFactorialCommand extends TomCommand {
///   final int number;
///   ComputeFactorialCommand(this.number);
///
///   @override
///   Future<Object?> execute() async {
///     return factorial(number);
///   }
/// }
///
/// // Send to worker
/// final result = await worker.executeCommand(ComputeFactorialCommand(10));
/// ```
abstract class TomCommand {
  /// Executes this command and returns the result.
  ///
  /// Override this method to implement the command's logic.
  /// The result is sent back to the caller.
  Future<Object?> execute() async {
    return "null";
  }
}

// =============================================================================
// INTERNAL MESSAGE TYPES
// =============================================================================

/// Internal command wrapper for messages from creator to isolate.
class _TomCreatorCommand {
  /// Unique identifier for tracking the request/response pair.
  int id;

  /// The actual command payload.
  Object command;

  _TomCreatorCommand(this.id, this.command);
}

/// Internal response wrapper for messages from creator to isolate.
class _TomCreatorResponse {
  /// Matches the id from the corresponding [_TomCreatorCommand].
  int id;

  /// The result of executing the command.
  Object response;

  _TomCreatorResponse(this.id, this.response);
}

/// Internal command wrapper for messages from isolate to creator.
class _TomIsolateCommand {
  /// Unique identifier for tracking the request/response pair.
  int id;

  /// The actual command payload.
  Object command;

  _TomIsolateCommand(this.id, this.command);
}

/// Internal response wrapper for messages from isolate to creator.
class _TomIsolateResponse {
  /// Matches the id from the corresponding [_TomIsolateCommand].
  int id;

  /// The result of executing the command.
  Object response;

  _TomIsolateResponse(this.id, this.response);
}

/// Internal report that a worker isolate failed to initialize itself.
///
/// [TomWorkerContext.initializeIsolate] runs inside the new isolate, so an
/// exception it throws cannot reach the creator by unwinding — it would end
/// the isolate's entry point, leaving the ready signal unsent and the awaiting
/// [TomWorker.spawn] blocked forever. The isolate therefore reports the failure
/// explicitly on the channel the creator is already listening to.
///
/// The error and stack travel as strings because neither is guaranteed to be
/// sendable across an isolate boundary.
class _TomIsolateInitFailure {
  /// The `toString()` of whatever [TomWorkerContext.initializeIsolate] threw.
  final String error;

  /// The stack trace captured where the failure was thrown, as a string.
  final String stack;

  _TomIsolateInitFailure(this.error, this.stack);
}

/// Internal liveness-probe command sent by pool supervision to an idle worker.
///
/// The worker's message loop answers it immediately with [_healthPongMessage],
/// letting the pool confirm the isolate is responsive without running any user
/// command. It is handled before the [TomCommand]/executor dispatch so a
/// worker with no executors registered still answers pings.
class _TomHealthPingCommand {
  const _TomHealthPingCommand();
}

/// Reply payload a worker sends back for a [_TomHealthPingCommand].
const String _healthPongMessage = '--- pong ---';

// =============================================================================
// WORKER CONTEXT
// =============================================================================

/// Configuration context for initializing worker isolates.
///
/// This class holds the configuration and state needed to spawn and
/// initialize a worker isolate. It provides hooks for custom initialization
/// logic in both the isolate and worker contexts.
///
/// ## Lifecycle
///
/// 1. Context is created with environment configuration
/// 2. [initializeIsolate] is called in the new isolate (static context)
/// 3. [initializeWorker] is called on the TomWorker instance
///
/// Both hooks report failure by throwing; see [initializeIsolate].
///
/// ## Example
///
/// ```dart
/// class MyWorkerContext extends TomWorkerContext {
///   MyWorkerContext() : super(
///     TomEnvironment.development,
///     TomPlatform.mobile,
///     [],
///     'MyWorker',
///   );
///
///   @override
///   Future<void> initializeIsolate() async {
///     // Set up isolate-specific resources. Throwing here — directly, or out
///     // of setupDatabase — aborts the spawn instead of producing a worker
///     // with half its setup done.
///     await setupDatabase();
///   }
///
///   @override
///   Future<void> initializeWorker(TomWorker worker) async {
///     // Configure the worker instance
///     worker.sendExecutorToIsolate(MyExecutor());
///   }
/// }
/// ```
class TomWorkerContext {
  /// Internal send port for communication with the creator isolate.
  SendPort? _sendPort;

  /// The environment configuration (development, staging, production).
  TomEnvironment tomEnvironment;

  /// The platform this worker is running on.
  TomPlatform tomPlatform;

  /// Command-line arguments passed to the worker.
  List<String> args;

  /// Prefix for naming worker isolates (e.g., "W" produces "W001", "W002").
  String namePrefix = "W";

  /// Creates a new worker context with the specified configuration.
  ///
  /// - [tomEnvironment]: The runtime environment (dev, staging, prod)
  /// - [tomPlatform]: The target platform
  /// - [args]: Command-line arguments
  /// - [namePrefix]: Prefix for worker isolate names
  TomWorkerContext(
    this.tomEnvironment,
    this.tomPlatform,
    this.args,
    this.namePrefix,
  );

  /// Internal method to attach the send port for creator communication.
  TomWorkerContext _addSendPort(SendPort s) {
    _sendPort = s;
    return this;
  }

  /// Called in a static context inside the newly created isolate.
  ///
  /// Override this method to perform isolate-level initialization such as
  /// setting up global resources, registering services, or configuring
  /// the isolate environment.
  ///
  /// Signal a failure by throwing. [TomWorker.spawn] reports the throw to the
  /// caller as a [TomWorkerException] and tears the half-started isolate down,
  /// so a worker whose setup did not complete never joins a pool and never
  /// takes work.
  Future<void> initializeIsolate() async {}

  /// Called on the newly created [TomWorker] instance.
  ///
  /// Override this method to configure the worker after creation,
  /// such as registering executors or setting up worker-specific state.
  ///
  /// - [worker]: The newly created worker instance
  ///
  /// Signal a failure by throwing; see [initializeIsolate] for what the throw
  /// does. This is the hook most likely to fail in practice, because acquiring
  /// resources is exactly what it is for.
  Future<void> initializeWorker(TomWorker worker) async {}
}

// =============================================================================
// WORKER IMPLEMENTATION
// =============================================================================

/// Manages communication with a worker isolate.
///
/// [TomWorker] provides the core functionality for spawning isolates and
/// managing bidirectional communication between the main isolate and
/// worker isolates.
///
/// ## Architecture
///
/// ```
/// ┌─────────────────┐         ┌─────────────────┐
/// │  Main Isolate   │◄───────►│ Worker Isolate  │
/// │   (Creator)     │ SendPort│   (TomWorker)   │
/// │                 │◄───────►│                 │
/// │  TomWorker      │ReceiveP │  Executors      │
/// │  instance       │         │                 │
/// └─────────────────┘         └─────────────────┘
/// ```
///
/// ## Example
///
/// ```dart
/// // Spawn a worker
/// final worker = await TomWorker.spawn(
///   TomWorker.startRemoteIsolate,
///   TomWorkerContext(env, platform, [], 'Worker'),
/// );
///
/// // Execute commands
/// final result = await worker.executeCommand(MyCommand());
///
/// // Check if busy
/// if (worker.isBusy()) {
///   print('Worker is processing requests');
/// }
///
/// // Shutdown
/// worker.close();
/// ```
///
/// ## Static Methods for Worker Isolates
///
/// When running inside a worker isolate, use static methods:
/// - [sendToCreator]: Send a message to the creator isolate
/// - [executeInCreator]: Execute a command in the creator and await result
/// - [canSendToCreator]: Check if backchannel communication is available
class TomWorker {
  static int _workerCount = 0;

  /// Number of workers spawned so far, used to generate unique worker names.
  ///
  /// Read-only: writing it would hand two live workers the same name.
  static int get workerCount => _workerCount;

  /// Resets the worker-name counter so generated names start at zero again.
  ///
  /// Exists for tests that assert on the generated names; production code has
  /// no reason to rewind the counter.
  @visibleForTesting
  static void resetWorkerCount() => _workerCount = 0;

  /// Whether this worker is ready to accept commands.
  bool isReady = false;

  /// Whether this worker has been closed.
  bool get isClosed => _closed;

  final Completer<TomWorker> _instanceCompleter = Completer();
  final SendPort _commands;
  final ReceivePort _responses;

  /// The underlying Dart Isolate instance.
  final Isolate isolate;

  /// The debug name this worker's isolate was spawned with, e.g. `W001`.
  ///
  /// Kept here rather than read back from [isolate]: `Isolate.debugName` is
  /// only populated inside the isolate itself, so on this side it is always
  /// `null` and every message built from it would identify nothing.
  final String name;

  /// Tracks pending requests awaiting responses from the worker.
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;

  /// Port registered with [Isolate.addOnExitListener] when this worker is
  /// supervised via [superviseExit]; `null` when supervision is off.
  RawReceivePort? _exitPort;

  /// Callback invoked once when a supervised worker's isolate dies
  /// unexpectedly (not through [close]). Set by [superviseExit].
  void Function()? _onDeath;

  /// Indicates whether the current code is running in the main isolate.
  ///
  /// This is set to `false` when [startRemoteIsolate] is called in a
  /// worker isolate.
  static bool isMainIsolate = true;

  /// Counter for requests sent to the creator isolate.
  static int _idCreatorCounter = 0;

  /// Tracks pending requests awaiting responses from the creator.
  static final Map<int, Completer<Object?>> _activeCreatorRequests = {};

  bool _closed = false;

  /// Private constructor - use [spawn] to create instances.
  TomWorker._(this._responses, this._commands, this.isolate, this.name) {
    _responses.listen(_handleResponsesFromIsolate);
  }

  /// Returns `true` if this worker has pending requests.
  ///
  /// Use this to check if the worker is currently processing commands
  /// before closing or reassigning work.
  bool isBusy() {
    return _activeRequests.isNotEmpty;
  }

  /// Spawns a new worker isolate with the given initializer and context.
  ///
  /// This is the primary factory method for creating workers. It handles
  /// the isolate creation, port setup, and initialization sequence.
  ///
  /// - [initializer]: Function to run in the new isolate (typically
  ///   [startRemoteIsolate])
  /// - [workerContext]: Configuration for the new worker
  ///
  /// Returns a [Future] that completes when the worker is ready.
  ///
  /// Example:
  /// ```dart
  /// final worker = await TomWorker.spawn(
  ///   TomWorker.startRemoteIsolate,
  ///   myContext,
  /// );
  /// ```
  static Future<TomWorker> spawn(
    void Function(TomWorkerContext) initializer,
    TomWorkerContext workerContext,
  ) async {
    // Create a receive port and add its initial message handler.
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        commandPort,
      ));
    };

    // Spawn the isolate.
    Isolate? isolate;
    final workerName =
        "${workerContext.namePrefix}${(_workerCount++).toString().padLeft(3, '0')}";
    try {
      workerContext._addSendPort(initPort.sendPort);
      isolate = await Isolate.spawn<TomWorkerContext>(
        initializer,
        workerContext,
        debugName: workerName,
      );
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    TomWorker worker = TomWorker._(receivePort, sendPort, isolate, workerName);
    tomLog.trace(
      "starting initialization of creator/worker ${Isolate.current.debugName}",
    );
    var timer = Stopwatch()..start();
    // Everything from here on runs with a live isolate that the caller cannot
    // yet reach: spawn has not returned, so no TomWorker reference exists to
    // close(). A failure must therefore tear the isolate down here, or it stays
    // in its message loop holding its ports open for the life of the process.
    try {
      await workerContext.initializeWorker(worker);
      tomLog.info(
        "finished initialization of creator/worker ${Isolate.current.debugName}, took ${timer.elapsedMilliseconds}ms",
      );
      return await worker._instanceCompleter.future;
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      receivePort.close();
      rethrow;
    }
  }

  /// Handles incoming messages from the worker isolate.
  ///
  /// This method processes:
  /// - Ready signals from newly spawned isolates
  /// - Responses to commands sent via [executeCommand]
  /// - Commands from the worker requesting execution in the creator
  /// - General messages processed by registered executors
  void _handleResponsesFromIsolate(dynamic message) async {
    if (message is String && message == readyMessage) {
      isReady = true;
      _instanceCompleter.complete(this);
    } else if (message is _TomIsolateInitFailure) {
      // The isolate could not set itself up, so it will never send the ready
      // signal. Fail the spawn with the isolate-side reason rather than let
      // the caller wait for a message that is not coming.
      _instanceCompleter.completeError(
        TomWorkerException(
          'isolate.initialize_isolate_failed.spawn',
          'initializeIsolate failed for TomWorker $name: ${message.error}',
          parameters: {
            'isolateName': name,
            'error': message.error,
            'isolateStack': message.stack,
          },
        ),
      );
    } else if (message is _TomIsolateResponse) {
      // The request may already be gone: a timed-out [ping] abandons its
      // completer and removes the id before the (late) pong arrives, so a
      // missing entry is expected and must not crash the handler.
      final completer = _activeRequests.remove(message.id);
      if (completer != null) {
        _completeFromResponse(completer, message.response);
      }
      // If close() was requested while requests were still in flight, the
      // response port could not be closed then; close it now that the last
      // pending request has resolved so the ReceivePort does not leak (bug §5).
      if (_closed && _activeRequests.isEmpty) {
        _responses.close();
      }
    } else if (message is _TomCreatorCommand) {
      TomExecutor? executor;
      Object? result;
      try {
        if (message.command is TomCommand) {
          TomCommand command = message.command as TomCommand;
          result = command.execute();
          if (result is Future) {
            result = await result;
          }
        } else {
          for (executor in executors) {
            result = executor.execute(message.command);
            if (result is Future) {
              result = await result;
            }
            if (result == TomExecutor.noResult) {
              continue;
            }
            break;
          }
        }
        if (result == TomExecutor.noResult) {
          tomLog.warn(
            "TomCreatorCommand resulting in NO_RESULT ${message.command}",
          );
        }
        _commands.send(
          _TomCreatorResponse(message.id, result ?? TomExecutor.noResult),
        );
      } catch (exception, s) {
        tomLog.error(
          "Failed execute message from Isolate $message $executor from $name to ${Isolate.current.debugName}",
        );
        tomPrintStackTrace(s);
        _commands.send(_TomCreatorResponse(message.id, exception));
      }
    } else if (executors.isNotEmpty) {
      TomExecutor? executor;
      Object? result;
      try {
        for (executor in executors) {
          result = executor.execute(message);
          if (result is Future) {
            result = await result;
          }
          if (result == TomExecutor.noResult) {
            continue;
          }
          break;
        }
      } catch (e) {
        tomLog.error(
          "Failed to execute message from Isolate $message $executor from $name to ${Isolate.current.debugName}: $e",
        );
      }
    } else {
      tomLog.error(
        "Received invalid message from Isolate $name $message and no Executor has been set",
      );
    }
  }

  /// Resolves [completer] from a command [response] received over a port.
  ///
  /// A [RemoteError] payload signals that the command threw in the other
  /// isolate, so the awaiting future is completed with an error; any other
  /// payload is the successful result. Shared by the two response handlers
  /// (worker→creator and creator→worker) so both channels resolve pending
  /// requests identically.
  static void _completeFromResponse(
    Completer<Object?> completer,
    Object response,
  ) {
    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response);
    }
  }

  /// Message sent when a worker isolate is ready to accept commands.
  static const readyMessage = "--- ready ---";

  /// List of executors registered to handle incoming commands.
  ///
  /// Executors are called in order until one produces a result.
  /// Register executors using `TomWorker.executors.add(myExecutor)`.
  static List<TomExecutor> executors = [];

  /// Internal send port for communication back to the creator isolate.
  ///
  /// This is only set in worker isolates, not in the main isolate.
  static SendPort? _backChannel;

  /// Internal handler for commands received by a worker isolate.
  ///
  /// This method runs the main message loop in worker isolates,
  /// processing incoming commands and sending responses.
  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    SendPort sendPort,
  ) async {
    tomLog.info(
      "Isolate ready to handle messages: ${Isolate.current.debugName}",
    );
    sendPort.send(readyMessage);
    isMainIsolate = false;
    receivePort.listen((message) async {
      if (message == 'shutdown') {
        receivePort.close();
        return;
      }
      if (message is TomExecutor) {
        executors.add(message);
        return;
      }
      if (message is _TomIsolateCommand) {
        // Liveness probe: answer immediately, before any executor dispatch, so
        // even a worker with no executors registered proves it is responsive.
        if (message.command is _TomHealthPingCommand) {
          sendPort.send(_TomIsolateResponse(message.id, _healthPongMessage));
          return;
        }
        try {
          if (message.command is TomCommand) {
            var command = message.command as TomCommand;
            var result = await command.execute();
            sendPort.send(_TomIsolateResponse(message.id, result ?? "null"));
            return;
          }
          // Not self-executing: offer the message to each registered executor
          // in turn until one claims it. Starting from the sentinel makes an
          // empty [executors] list take the same exit as a chain that declined.
          Object? result = TomExecutor.noResult;
          for (final executor in executors) {
            final candidate = executor.execute(message.command);
            result = candidate is Future ? await candidate : candidate;
            if (result != TomExecutor.noResult) break;
          }
          if (result == TomExecutor.noResult) {
            // Nothing handled it. Answer anyway, as the creator side does:
            // staying silent leaves the caller's completer pending forever,
            // and liveness supervision cannot see that hang because the
            // isolate is perfectly healthy and still answers pings.
            tomLog.warn(
              "Isolate command resulting in NO_RESULT in "
              "${Isolate.current.debugName}: ${message.command}",
            );
            sendPort.send(
              _TomIsolateResponse(message.id, TomExecutor.noResult),
            );
            return;
          }
          sendPort.send(_TomIsolateResponse(message.id, result ?? "null"));
        } catch (e) {
          sendPort.send(
            _TomIsolateResponse(message.id, RemoteError(e.toString(), '')),
          );
        }
      } else if (message is _TomCreatorResponse) {
        final completer = _activeCreatorRequests.remove(message.id);
        if (completer != null) {
          _completeFromResponse(completer, message.response);
        }
      }
    });
  }

  /// Initializes a worker isolate and starts the message handling loop.
  ///
  /// This method should be passed as the initializer to [spawn].
  /// It sets up the communication channels and calls the context's
  /// initialization hooks.
  ///
  /// - [context]: The worker context containing configuration
  ///
  /// Throws [TomWorkerException] if the context's sendPort is null.
  ///
  /// If [TomWorkerContext.initializeIsolate] throws, the failure is reported to
  /// the creator and the isolate stops without ever signalling readiness — it
  /// cannot be reported by unwinding, because nothing in this isolate awaits
  /// this entry point.
  ///
  /// Example:
  /// ```dart
  /// final worker = await TomWorker.spawn(
  ///   TomWorker.startRemoteIsolate, // Use this method
  ///   context,
  /// );
  /// ```
  static void startRemoteIsolate(TomWorkerContext context) async {
    //tomLog.trace("starting remote isolate ${Isolate.current.debugName}");
    if (context._sendPort == null) {
      throw TomWorkerException(
        "isolate.state_error.attempt_to_start_isolate_but_sendport_is_null",
        "sendPort must be set in TomWorkerContext to start an isolate.",
      );
    }
    final receivePort = ReceivePort();
    context._sendPort!.send(receivePort.sendPort);
    //tomLog.trace("starting initialization of isolate ${Isolate.current.debugName}");
    try {
      await context.initializeIsolate();
    } on Object catch (e, s) {
      // This entry point was invoked by the isolate runtime, so a rethrow ends
      // the isolate as an unhandled error and the creator simply never hears
      // the ready signal — it would wait forever. Reporting the failure on the
      // channel the creator already listens to is the only way out.
      context._sendPort!.send(_TomIsolateInitFailure(e.toString(), s.toString()));
      receivePort.close();
      return;
    }
    tomLog.trace(
      "finished initialization of isolate ${Isolate.current.debugName}",
    );
    _backChannel = context._sendPort;
    _handleCommandsToIsolate(receivePort, context._sendPort!);
  }

  /// Returns `true` if backchannel communication to the creator is available.
  ///
  /// This returns `true` only when called from within a worker isolate.
  /// In the main isolate, this always returns `false`.
  static bool canSendToCreator() {
    return _backChannel != null;
  }

  /// Sends a message to the creator isolate (fire-and-forget).
  ///
  /// Use this for one-way communication from a worker to the main isolate.
  /// For request-response patterns, use [executeInCreator] instead.
  ///
  /// - [o]: The object to send to the creator
  ///
  /// Throws [TomWorkerException] if called from the main isolate.
  ///
  /// **Note**: Do not add logging in this method to avoid stack overflow
  /// when using separate isolates for logging.
  static void sendToCreator(Object o) {
    if (_backChannel != null) {
      _backChannel!.send(o);
    } else {
      throw TomWorkerException(
        "isolate.state_error.attempt_to_send_to_creator_in_creator",
        "You can't send to creator from the creator side. There is no backchannel here. ${Isolate.current.debugName}",
        parameters: {"isolateName": Isolate.current.debugName},
      );
    }
  }

  /// Executes a command in the creator isolate and awaits the result.
  ///
  /// Use this for request-response communication from a worker to the
  /// main isolate. The command will be processed by executors registered
  /// on the creator's [TomWorker] instance.
  ///
  /// - [command]: The command to execute in the creator
  ///
  /// Returns the result of executing the command.
  ///
  /// Throws [TomWorkerException] if called from the main isolate.
  ///
  /// Example:
  /// ```dart
  /// // From within a worker isolate:
  /// final config = await TomWorker.executeInCreator(GetConfigCommand());
  /// ```
  static Future<Object?> executeInCreator(Object command) async {
    if (_backChannel != null) {
      final completer = Completer<Object?>.sync();
      final id = _idCreatorCounter++;
      _activeCreatorRequests[id] = completer;
      _backChannel!.send(_TomCreatorCommand(id, command));
      return await completer.future;
    } else {
      throw TomWorkerException(
        "isolate.state_error.attempt_to_execute_in_creator_in_creator",
        "You can't execute in creator from the creator side. There is no backchannel here. ${Isolate.current.debugName}",
        parameters: {"isolateName": Isolate.current.debugName},
      );
    }
  }

  /// Sends a command to the worker isolate and awaits the result.
  ///
  /// This is the primary method for executing work in a worker isolate.
  /// The command can be either a [TomCommand] subclass (which executes
  /// its own logic) or any object that will be processed by registered
  /// executors.
  ///
  /// - [command]: The command to execute
  ///
  /// Returns the result of executing the command, or [TomExecutor.noResult]
  /// when nothing in the worker handled it — because no executor is registered
  /// there, or because every registered executor declined. Every command is
  /// answered: an unanswered one would leave this future pending forever, and
  /// liveness supervision could not rescue it, since the isolate is healthy and
  /// still answers pings. Compare the result against [TomExecutor.noResult] if
  /// "nothing handled this" is a case the caller must distinguish.
  ///
  /// Throws [TomWorkerException] if this worker has been closed — the same
  /// fail-fast [TomWorkerPool.execute] gives for the identical mistake one
  /// layer up. The closed worker's isolate has already been told to shut down,
  /// so a dispatch accepted here would never be answered.
  ///
  /// A command accepted *before* [close] is unaffected: it was accepted while
  /// the worker was open and still resolves normally.
  ///
  /// Example:
  /// ```dart
  /// final result = await worker.executeCommand(ProcessDataCommand(data));
  /// ```
  Future<Object?> executeCommand(Object command) async {
    if (_closed) {
      throw _closedException('execute_after_close', 'execute a command on');
    }
    final completer = Completer<Object?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send(_TomIsolateCommand(id, command));
    return await completer.future;
  }

  /// Builds the refusal thrown when this worker is used after [close].
  ///
  /// [site] names the rejected operation in the key and [attempt] describes it
  /// in the message; both carry the isolate name, because a pool closes many
  /// workers at once and "which one" is the first question to answer.
  TomWorkerException _closedException(String site, String attempt) =>
      TomWorkerException(
        'isolate.worker_closed.$site',
        'Cannot $attempt TomWorker $name: it has been closed.',
        parameters: {'isolateName': name},
      );

  /// Registers a one-shot [onDeath] callback for unexpected isolate exit.
  ///
  /// Uses [Isolate.addOnExitListener] as the primary death signal: it fires for
  /// every way the isolate can terminate — an uncaught error, [Isolate.kill],
  /// or an out-of-memory kill — which a request-response ping alone cannot
  /// observe once a command is already hung.
  ///
  /// A normal [close] is **not** an unexpected death: [close] sets [isClosed]
  /// and tears down the exit port before the isolate terminates, so
  /// [onDeath] does not fire for orderly shutdowns.
  ///
  /// Idempotent: calling it again while already supervised is a no-op.
  void superviseExit(void Function() onDeath) {
    if (_closed || _exitPort != null) return;
    _onDeath = onDeath;
    final port = RawReceivePort();
    port.handler = (_) => _handleUnexpectedDeath();
    _exitPort = port;
    isolate.addOnExitListener(port.sendPort);
  }

  /// Handles an unexpected isolate exit reported by the [superviseExit] port.
  ///
  /// Marks the worker closed, fails every in-flight request with a
  /// [TomWorkerDiedException] (so callers stop hanging on their completers),
  /// releases the ports, and finally invokes the supervisor callback so the
  /// owning pool can respawn a replacement.
  void _handleUnexpectedDeath() {
    if (_closed) return;
    _closed = true;
    _exitPort?.close();
    _exitPort = null;

    final pending = List<Completer<Object?>>.of(_activeRequests.values);
    _activeRequests.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          TomWorkerDiedException(
            'isolate.worker_died.in_flight_request',
            'Worker isolate $name died while a command was '
                'in flight; the request was failed rather than re-dispatched.',
            parameters: {'isolateName': name},
          ),
        );
      }
    }
    _responses.close();

    final callback = _onDeath;
    _onDeath = null;
    callback?.call();
  }

  /// Sends a liveness probe to the worker and awaits its pong within [timeout].
  ///
  /// Returns `true` if the worker answered in time, `false` on timeout. A
  /// timed-out probe abandons its request slot so a late pong is silently
  /// ignored (see the null-safe branch in [_handleResponsesFromIsolate]); it
  /// deliberately does **not** kill the isolate — that decision belongs to the
  /// supervisor, which only pings idle workers.
  Future<bool> ping(Duration timeout) async {
    if (_closed) return false;
    final completer = Completer<Object?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send(_TomIsolateCommand(id, const _TomHealthPingCommand()));
    try {
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _activeRequests.remove(id);
      return false;
    }
  }

  /// Force-kills the worker's isolate at [Isolate.immediate] priority.
  ///
  /// Intended for supervisors that detected an unresponsive (hung) worker via
  /// [ping]. The kill triggers the [superviseExit] listener, which fails any
  /// in-flight requests and notifies the pool to respawn a replacement.
  void killUnresponsive() {
    isolate.kill(priority: Isolate.immediate);
  }

  /// Sends an executor to the worker isolate.
  ///
  /// The executor will be added to the worker's executor list and will
  /// process subsequent commands. Use this to dynamically add command
  /// handlers to running workers.
  ///
  /// - [te]: The executor to send
  ///
  /// Throws [TomWorkerException] if this worker has been closed: the send would
  /// land on a port whose isolate is shutting down, losing the executor while
  /// the caller believes it registered.
  void sendExecutorToIsolate(TomExecutor te) {
    if (_closed) {
      throw _closedException(
        'send_executor_after_close',
        'send an executor to',
      );
    }
    _commands.send(te);
  }

  /// Closes this worker and shuts down the isolate.
  ///
  /// After calling this method:
  /// - No new commands can be sent — [executeCommand] and
  ///   [sendExecutorToIsolate] throw [TomWorkerException] rather than
  ///   dispatching to an isolate that will never answer
  /// - The worker isolate receives a shutdown signal
  /// - Resources are released
  ///
  /// Commands already in flight are **not** cancelled: they were accepted while
  /// the worker was open, so the response port stays open until the last of
  /// them resolves.
  ///
  /// Idempotent. Check [isClosed] to verify the worker's state.
  void close() {
    if (!_closed) {
      _closed = true;
      // Tear down exit supervision first so the imminent (orderly) isolate
      // termination is not mistaken for an unexpected death.
      _exitPort?.close();
      _exitPort = null;
      _onDeath = null;
      _commands.send('shutdown');
      if (_activeRequests.isEmpty) _responses.close();
      tomLog.trace(
        '--- port closed  $name  ${Isolate.current.debugName} --- ',
      );
    }
  }
}

// =============================================================================
// WORKER POOL
// =============================================================================

/// Manages a pool of worker isolates for parallel task execution.
///
/// [TomWorkerPool] provides automatic load balancing by distributing
/// commands across multiple workers. When all workers are busy, requests
/// are queued until a worker becomes available.
///
/// ## Use Cases
///
/// - CPU-intensive computations that benefit from parallelization
/// - Batch processing of independent tasks
/// - Request handling where isolation is required
///
/// ## Example
///
/// ```dart
/// // Create a pool with 4 workers
/// final pool = await TomWorkerPool.withSize(4, context);
///
/// // Execute commands - automatically distributed
/// final results = await Future.wait([
///   pool.execute(ProcessCommand(data1)),
///   pool.execute(ProcessCommand(data2)),
///   pool.execute(ProcessCommand(data3)),
///   pool.execute(ProcessCommand(data4)),
/// ]);
/// ```
///
/// ## Liveness supervision (opt-in)
///
/// By default the pool performs **no** liveness supervision — behaviour is
/// unchanged from an unsupervised pool. Pass a [healthCheckInterval] to
/// [withSize] to enable it. When enabled:
///
/// - Every worker is watched via [TomWorker.superviseExit]. If an isolate
///   dies for any reason (uncaught error, [Isolate.kill], OOM), each in-flight
///   command on it is **failed** with a [TomWorkerDiedException] instead of
///   hanging forever, and the pool respawns a replacement worker (via
///   [TomWorker.spawn] with the pool's stored context) to restore capacity.
/// - A periodic timer pings **idle** workers to catch hangs that never emit an
///   exit signal. Only idle workers are probed: a ping queued behind a busy
///   worker's in-flight command cannot be distinguished from legitimately slow
///   work, and busy-worker crashes are already covered by the exit listener. A
///   worker that fails to answer within [healthCheckTimeout] is force-killed,
///   which routes it through the same death/respawn path.
///
/// A failed in-flight command is deliberately **not** re-dispatched:
/// re-running a command that may have already produced side effects before the
/// isolate died would risk executing non-idempotent work twice. The caller
/// observes the [TomWorkerDiedException] and decides how to react.
///
/// ## Notes
///
/// - Workers are created during pool initialization
/// - A pool needs at least one worker; [withSize] rejects a smaller size
///   rather than returning a pool on which every command would wait forever
/// - Commands wait if all workers are busy (polling every 1ms)
/// - Consider pool size based on CPU cores and task characteristics
class TomWorkerPool {
  /// All workers in this pool.
  final List<TomWorker> _workers = [];

  /// Workers currently available for new tasks.
  final List<TomWorker> _free = [];

  /// Workers currently processing tasks.
  final List<TomWorker> _busy = [];

  /// Context used to (re)spawn workers; stored so dead workers can be replaced.
  late final TomWorkerContext _context;

  /// Interval between liveness probes; `null` disables supervision entirely.
  Duration? _healthCheckInterval;

  /// Maximum time a probed idle worker has to answer before being force-killed.
  Duration _healthCheckTimeout = const Duration(seconds: 5);

  /// Periodic supervision timer; `null` when supervision is off or closed.
  Timer? _healthTimer;

  /// Guards against overlapping health-check passes (a slow pass must not be
  /// re-entered by the next timer tick).
  bool _healthCheckRunning = false;

  /// Whether [close] has been called; stops supervision and new dispatch.
  bool _closed = false;

  /// Private constructor - use [withSize] to create instances.
  TomWorkerPool._();

  /// Whether liveness supervision is enabled for this pool.
  bool get isSupervised => _healthCheckInterval != null;

  /// Number of live workers currently registered in the pool.
  int get workerCount => _workers.length;

  /// Creates a worker pool with the specified number of workers.
  ///
  /// Each worker is spawned using [TomWorker.spawn] with the provided
  /// [context]. The method waits for all workers to be ready before
  /// returning.
  ///
  /// - [size]: Number of workers to create; must be at least 1
  /// - [context]: Configuration for each worker (also retained to respawn
  ///   workers that die when supervision is enabled)
  /// - [healthCheckInterval]: opt-in; when non-null, enables liveness
  ///   supervision (exit detection + idle-worker pings) and must be positive.
  ///   Defaults to `null` (supervision off).
  /// - [healthCheckTimeout]: how long a probed idle worker has to answer a
  ///   ping before it is treated as hung and force-killed. Only used — and
  ///   only validated — when [healthCheckInterval] is set; must be positive.
  ///
  /// Returns a [Future] that completes when all workers are ready.
  ///
  /// Throws [TomWorkerException] if any argument would produce a pool that
  /// cannot do useful work. Each such value is a caller bug — an unvalidated
  /// config entry, or an arithmetic slip like `numberOfProcessors - 1` on a
  /// single-core container — and accepting it defers the symptom to a
  /// dispatch far from the mistake. The rejection carries the offending value
  /// so the error points back at the expression that produced it.
  static Future<TomWorkerPool> withSize(
    int size,
    TomWorkerContext context, {
    Duration? healthCheckInterval,
    Duration healthCheckTimeout = const Duration(seconds: 5),
  }) async {
    if (size < 1) {
      // A pool with no workers can never acquire one: workers are added at
      // construction and on respawn-after-death only, so execute() would spin
      // its 1 ms wait loop forever against a permanently empty free list.
      throw TomWorkerException(
        'isolate.invalid_pool_size.with_size',
        'Cannot create a TomWorkerPool with $size workers: at least 1 is '
            'required, because a pool that starts empty can never acquire a '
            'worker and every execute() would wait forever.',
        parameters: {'size': size},
      );
    }
    if (healthCheckInterval != null) {
      // Only meaningful when supervision is on. healthCheckTimeout has a
      // default, so an unsupervised caller never chose it and must not be
      // failed by it.
      if (healthCheckInterval <= Duration.zero) {
        // Timer.periodic would then run a health pass on every event-loop
        // turn, pinning the CPU with probes no caller asked to repeat.
        throw TomWorkerException(
          'isolate.invalid_health_check_interval.with_size',
          'Cannot supervise a TomWorkerPool with a healthCheckInterval of '
              '$healthCheckInterval: it must be positive.',
          parameters: {'healthCheckInterval': healthCheckInterval.toString()},
        );
      }
      if (healthCheckTimeout <= Duration.zero) {
        // Every probe would expire before a healthy worker could answer, so
        // supervision would force-kill and respawn the whole pool on every
        // pass — an endless treadmill whose workerCount still reads healthy.
        throw TomWorkerException(
          'isolate.invalid_health_check_timeout.with_size',
          'Cannot supervise a TomWorkerPool with a healthCheckTimeout of '
              '$healthCheckTimeout: it must be positive, or every probe '
              'declares a healthy worker dead.',
          parameters: {'healthCheckTimeout': healthCheckTimeout.toString()},
        );
      }
    }
    final twp = TomWorkerPool._();
    twp._context = context;
    twp._healthCheckInterval = healthCheckInterval;
    twp._healthCheckTimeout = healthCheckTimeout;
    for (int i = 0; i < size; i++) {
      tomLog.info(
        'Creating worker #$i for workerpool in  ${Isolate.current.debugName}',
      );
      await twp._spawnAndRegister();
      tomLog.info(
        'Done creating worker #$i for workerpool in  ${Isolate.current.debugName}',
      );
    }
    if (healthCheckInterval != null) {
      twp._healthTimer =
          Timer.periodic(healthCheckInterval, (_) => twp._runHealthCheck());
    }
    return twp;
  }

  /// Spawns a worker, registers it as free, and (when supervised) attaches the
  /// exit listener. If the pool was closed while the spawn was in flight, the
  /// fresh worker is closed immediately instead of being added.
  Future<void> _spawnAndRegister() async {
    final tw = await TomWorker.spawn(TomWorker.startRemoteIsolate, _context);
    if (_closed) {
      tw.close();
      return;
    }
    _workers.add(tw);
    _free.add(tw);
    if (_healthCheckInterval != null) {
      tw.superviseExit(() => _handleWorkerDeath(tw));
    }
  }

  /// Removes a dead [worker] from every list and respawns a replacement.
  ///
  /// Invoked from [TomWorker.superviseExit]'s callback when an isolate dies
  /// unexpectedly. The dead worker's in-flight request (if any) has already
  /// been failed with a [TomWorkerDiedException] by the worker itself.
  void _handleWorkerDeath(TomWorker worker) {
    if (_closed) return;
    _workers.remove(worker);
    _free.remove(worker);
    _busy.remove(worker);
    unawaited(_replaceDeadWorker());
  }

  /// Restores pool capacity by spawning one replacement worker.
  Future<void> _replaceDeadWorker() async {
    if (_closed) return;
    try {
      await _spawnAndRegister();
    } catch (e) {
      tomLog.error(
        'TomWorkerPool: failed to respawn a worker after an isolate death: $e',
      );
    }
  }

  /// Pings every idle worker; force-kills any that do not answer in time.
  ///
  /// Each probed worker is reserved (pulled out of [_free]) for the duration of
  /// its ping so [execute] cannot dispatch real work onto it mid-probe — that
  /// would make a timed-out ping kill a worker that just started legitimate
  /// work. Responsive workers are returned to rotation; unresponsive ones are
  /// killed, which routes them through [_handleWorkerDeath] for respawn.
  Future<void> _runHealthCheck() async {
    if (_closed || _healthCheckRunning) return;
    _healthCheckRunning = true;
    try {
      final idle = List<TomWorker>.of(_free);
      for (final tw in idle) {
        if (_closed) break;
        // Atomically reserve; skip if execute() already took it.
        if (!_free.remove(tw)) continue;
        bool alive;
        try {
          alive = await tw.ping(_healthCheckTimeout);
        } catch (_) {
          alive = false;
        }
        if (_closed) break;
        if (alive) {
          _free.add(tw);
        } else {
          tw.killUnresponsive();
        }
      }
    } finally {
      _healthCheckRunning = false;
    }
  }

  /// Executes a command using an available worker from the pool.
  ///
  /// If all workers are busy, this method waits (polling every 1ms)
  /// until a worker becomes available. The command is then executed
  /// and the worker is returned to the pool.
  ///
  /// - [command]: The command to execute
  ///
  /// Returns the result of executing the command.
  ///
  /// Throws [TomWorkerException] if the pool has been closed, and (when
  /// supervision is enabled) [TomWorkerDiedException] if the worker handling
  /// this command dies before it completes.
  ///
  /// Example:
  /// ```dart
  /// final result = await pool.execute(MyCommand());
  /// ```
  Future<Object?> execute(Object command) async {
    if (_closed) throw _closedException();
    while (_free.isEmpty) {
      if (_closed) throw _closedException();
      await Future.delayed(Duration(milliseconds: 1));
    }
    final TomWorker tw = _free.removeAt(0);
    _busy.add(tw);
    try {
      return await tw.executeCommand(command);
    } finally {
      // Only recycle a worker that is still alive. A worker that died mid-
      // command has already been pulled from [_busy] by [_handleWorkerDeath];
      // in that case the removal below returns false and we do not re-add it.
      if (_busy.remove(tw) && !tw.isClosed) {
        _free.add(tw);
      }
    }
  }

  TomWorkerException _closedException() => TomWorkerException(
        'isolate.pool_closed.execute_after_close',
        'Cannot execute on a TomWorkerPool that has been closed.',
      );

  /// Shuts down every worker in this pool and releases their isolates.
  ///
  /// After calling this method the pool is empty and must not be reused.
  /// Supervision (if enabled) is stopped first. Each worker is closed via
  /// [TomWorker.close]; workers still processing in-flight commands close their
  /// response ports once those commands resolve (see [TomWorker.close]).
  void close() {
    _closed = true;
    _healthTimer?.cancel();
    _healthTimer = null;
    for (final TomWorker tw in _workers) {
      tw.close();
    }
    _free.clear();
    _busy.clear();
    _workers.clear();
  }
}
