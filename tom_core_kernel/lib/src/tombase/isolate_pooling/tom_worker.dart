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
  /// chain to handle the command.
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
///   Future<bool> initializeIsolate() async {
///     // Set up isolate-specific resources
///     await setupDatabase();
///     return true;
///   }
///
///   @override
///   Future<bool> initializeWorker(TomWorker worker) async {
///     // Configure the worker instance
///     worker.sendExecutorToIsolate(MyExecutor());
///     return true;
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
  /// Returns `true` if initialization was successful.
  Future<bool> initializeIsolate() async {
    return true;
  }

  /// Called on the newly created [TomWorker] instance.
  ///
  /// Override this method to configure the worker after creation,
  /// such as registering executors or setting up worker-specific state.
  ///
  /// - [worker]: The newly created worker instance
  ///
  /// Returns `true` if initialization was successful.
  Future<bool> initializeWorker(TomWorker worker) async {
    return true;
  }
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
  /// Counter for generating unique worker names.
  static int workerCount = 0;

  /// Whether this worker is ready to accept commands.
  bool isReady = false;

  /// Whether this worker has been closed.
  bool get isClosed => _closed;

  final Completer<TomWorker> _instanceCompleter = Completer();
  final SendPort _commands;
  final ReceivePort _responses;

  /// The underlying Dart Isolate instance.
  final Isolate isolate;

  /// Tracks pending requests awaiting responses from the worker.
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;

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
  TomWorker._(this._responses, this._commands, this.isolate) {
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
    try {
      workerContext._addSendPort(initPort.sendPort);
      isolate = await Isolate.spawn<TomWorkerContext>(
        initializer,
        workerContext,
        debugName:
            "${workerContext.namePrefix}${(workerCount++).toString().padLeft(3, '0')}",
      );
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    TomWorker worker = TomWorker._(receivePort, sendPort, isolate);
    tomLog.trace(
      "starting initialization of creator/worker ${Isolate.current.debugName}",
    );
    var timer = Stopwatch()..start();
    await workerContext.initializeWorker(worker);
    tomLog.info(
      "finished initialization of creator/worker ${Isolate.current.debugName}, took ${timer.elapsedMilliseconds}ms",
    );

    return worker._instanceCompleter.future;
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
    } else if (message is _TomIsolateResponse) {
      final completer = _activeRequests.remove(message.id)!;
      _completeFromResponse(completer, message.response);
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
          "Failed execute message from Isolate $message $executor from ${isolate.debugName} to ${Isolate.current.debugName}",
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
          "Failed to execute message from Isolate $message $executor from ${isolate.debugName} to ${Isolate.current.debugName}: $e",
        );
      }
    } else {
      tomLog.error(
        "Received invalid message from Isolate ${isolate.debugName} $message and no Executor has been set",
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
        try {
          if (message.command is TomCommand) {
            var command = message.command as TomCommand;
            var result = await command.execute();
            sendPort.send(_TomIsolateResponse(message.id, result ?? "null"));
            return;
          } else if (executors.isNotEmpty) {
            TomExecutor? executor;
            Object? result;
            for (executor in executors) {
              result = executor.execute(message.command);
              if (result is Future) {
                result = await result;
              }
              if (result != TomExecutor.noResult) {
                sendPort.send(_TomIsolateResponse(message.id, result ?? "null"));
                break;
              }
            }
          }
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
    await context.initializeIsolate();
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
  /// Returns the result of executing the command.
  ///
  /// Example:
  /// ```dart
  /// final result = await worker.executeCommand(ProcessDataCommand(data));
  /// ```
  Future<Object?> executeCommand(Object command) async {
    final completer = Completer<Object?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send(_TomIsolateCommand(id, command));
    return await completer.future;
  }

  /// Sends an executor to the worker isolate.
  ///
  /// The executor will be added to the worker's executor list and will
  /// process subsequent commands. Use this to dynamically add command
  /// handlers to running workers.
  ///
  /// - [te]: The executor to send
  void sendExecutorToIsolate(TomExecutor te) {
    _commands.send(te);
  }

  /// Closes this worker and shuts down the isolate.
  ///
  /// After calling this method:
  /// - No new commands can be sent
  /// - The worker isolate receives a shutdown signal
  /// - Resources are released
  ///
  /// Check [isClosed] to verify the worker's state.
  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send('shutdown');
      if (_activeRequests.isEmpty) _responses.close();
      tomLog.trace(
        '--- port closed  ${isolate.debugName}  ${Isolate.current.debugName} --- ',
      );
    }
  }
}

// =============================================================================
// WORKER POOL
// =============================================================================

// Note: this pool has no liveness supervision. A worker whose isolate dies
// (uncaught error, `Isolate.kill`) is not detected or replaced, and a command
// dispatched to it would never complete. Adding periodic health pings with
// automatic restart is tracked as a follow-up enhancement (quest todo RCJ1).

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
/// ## Notes
///
/// - Workers are created during pool initialization
/// - Commands wait if all workers are busy (polling every 1ms)
/// - Consider pool size based on CPU cores and task characteristics
class TomWorkerPool {
  /// All workers in this pool.
  final List<TomWorker> _workers = [];

  /// Workers currently available for new tasks.
  final List<TomWorker> _free = [];

  /// Workers currently processing tasks.
  final List<TomWorker> _busy = [];

  /// Private constructor - use [withSize] to create instances.
  TomWorkerPool._();

  /// Creates a worker pool with the specified number of workers.
  ///
  /// Each worker is spawned using [TomWorker.spawn] with the provided
  /// context. The method waits for all workers to be ready before
  /// returning.
  ///
  /// - [size]: Number of workers to create
  /// - [context]: Configuration for each worker
  ///
  /// Returns a [Future] that completes when all workers are ready.
  static Future<TomWorkerPool> withSize(
    int size,
    TomWorkerContext context,
  ) async {
    TomWorkerPool twp = TomWorkerPool._();
    for (int i = 0; i < size; i++) {
      tomLog.info(
        'Creating worker #$i for workerpool in  ${Isolate.current.debugName}',
      );
      TomWorker tw = await TomWorker.spawn(
        TomWorker.startRemoteIsolate,
        context,
      );
      tomLog.info(
        'Done creating worker #$i for workerpool in  ${Isolate.current.debugName}',
      );
      twp._workers.add(tw);
      twp._free.add(tw);
    }
    return twp;
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
  /// Example:
  /// ```dart
  /// final result = await pool.execute(MyCommand());
  /// ```
  Future<Object?> execute(Object command) async {
    while (_free.isEmpty) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    TomWorker tw = _free.removeAt(0);
    _busy.add(tw);
    Object? result = await tw.executeCommand(command);
    _busy.remove(tw);
    _free.add(tw);
    return result;
  }

  /// Shuts down every worker in this pool and releases their isolates.
  ///
  /// After calling this method the pool is empty and must not be reused.
  /// Each worker is closed via [TomWorker.close]; workers still processing
  /// in-flight commands close their response ports once those commands
  /// resolve (see [TomWorker.close]).
  void close() {
    for (final TomWorker tw in _workers) {
      tw.close();
    }
    _free.clear();
    _busy.clear();
    _workers.clear();
  }
}
