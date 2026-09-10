/// Isolate-based logging infrastructure for multi-threaded applications.
///
/// This library provides logging support for Dart isolates, enabling:
/// - Log message routing from worker isolates to a central logging isolate
/// - Asynchronous log processing to minimize performance impact
/// - Consistent log output across all isolates in the application
///
/// ## Architecture
///
/// ```
/// ┌─────────────────┐     ┌─────────────────┐
/// │ Worker Isolate  │────▶│ Logging Isolate │────▶ Console/Remote
/// └─────────────────┘     └─────────────────┘
/// ┌─────────────────┐            ▲
/// │ Worker Isolate  │────────────┘
/// └─────────────────┘
/// ```
///
/// ## Usage
///
/// ### Main Isolate Setup
///
/// ```dart
/// void main(List<String> args) async {
///   // Start isolated logging with a single logging worker
///   await TomIsolateLogging.startIsolatedLogging(args);
///
///   // Now all log messages are routed through the logging isolate
///   tomLog.info('This goes through the logging isolate');
/// }
/// ```
///
/// ### Worker Isolate Setup
///
/// ```dart
/// // In worker isolate initialization
/// TomIsolateLogging.startLoggingToCreator();
/// tomLog.info('This message is sent back to the main isolate');
/// ```
///
/// See also:
/// - [TomIsolateLogOutput] for the log output that routes to the logging isolate
/// - [TomCreatorLogOutput] for worker-to-main isolate logging
/// - [TomLoggingExecutor] for the logging isolate's message handler
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:async';

import 'package:tom_basics/tom_basics.dart';

import '../isolate_pooling/tom_worker.dart';
import '../little_things/exception_base.dart';

// =============================================================================
// Logging Isolate Executor
// =============================================================================

/// Executor that processes log messages in the logging isolate.
///
/// This executor runs inside the dedicated logging isolate and receives
/// [TomInterIsolateLogMessage] instances from worker isolates. It delegates
/// the actual output to the configured [TomLogOutput].
///
/// ## Customizing Logging Isolate Output
///
/// The output this executor writes through is the logging isolate's own
/// [tomLog] output, not the main isolate's — statics are per-isolate, so
/// assigning `tomLog.logOutput` in the main isolate cannot reach it. Replace it
/// from [TomLoggingWorkerContext.initializeIsolate], which runs inside the
/// spawned isolate:
///
/// ```dart
/// class CustomLoggingContext extends TomLoggingWorkerContext {
///   CustomLoggingContext(
///     super.tomEnvironment,
///     super.tomPlatform,
///     super.args,
///     super.namePrefix,
///   );
///
///   @override
///   Future<void> initializeIsolate() async {
///     // Registers this executor. Skip the super call and the isolate has no
///     // handler for the records the pool sends it, and drops every one.
///     await super.initializeIsolate();
///     tomLog.logOutput = TomRemoteLogOutput();
///   }
/// }
///
/// await TomIsolateLogging.startIsolatedLogging(
///   args,
///   workerContext: CustomLoggingContext(
///     TomRuntime.getCurrentEnvironment(),
///     TomRuntime.getCurrentPlatform()!,
///     args,
///     'L',
///   ),
/// );
/// ```
///
/// The class is `CustomLoggingContext` in
/// `example/samples/logging/05_isolate_and_remote_logging_example.dart`, where
/// it is compiled and run. Change it there and copy it out: the superclass
/// takes four positional arguments and has no zero-argument constructor to
/// inherit, so a subclass that declares no constructor does not compile, and
/// prose cannot fail to build.
class TomLoggingExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is TomInterIsolateLogMessage) {
      tomLog.logOutput.output(
        command.loggerLevel,
        command.logLevel,
        command.level,
        command.message,
        command.isolateName,
        command.timeStamp,
        command.origin,
      );
      return true;
    }
    return TomExecutor.noResult;
  }
}

// =============================================================================
// Inter-Isolate Message Types
// =============================================================================

/// Message container for passing log entries between isolates.
///
/// This class encapsulates all information needed to reconstruct a log
/// message in the logging isolate, including the original timestamp,
/// log levels, and message content.
///
/// Instances are automatically created by [TomIsolateLogOutput] and
/// [TomCreatorLogOutput] when routing log messages.
class TomInterIsolateLogMessage {
  /// When the log message was originally created.
  DateTime timeStamp;

  /// The logger's configured level at the time of logging.
  TomLogLevel loggerLevel;

  /// The level of this specific log message.
  TomLogLevel logLevel;

  /// Human-readable level string (e.g., "INFO   ").
  String level;

  /// The log message content.
  String message;

  /// Name of the isolate that generated the log.
  String isolateName;

  /// Optional caller information (class.method).
  String? origin;

  /// Creates a new inter-isolate log message.
  ///
  /// Named rather than positional, and every field required except [origin],
  /// which is optional in the record itself. Seven arguments of which two are
  /// `TomLogLevel` and three are `String` cannot be checked by the compiler in
  /// positional form: swapping [level] with [message], or [loggerLevel] with
  /// [logLevel], compiles and silently ships the wrong record. Naming them is
  /// what makes the call site both readable and reordering-proof.
  TomInterIsolateLogMessage({
    required this.loggerLevel,
    required this.logLevel,
    required this.level,
    required this.message,
    required this.isolateName,
    required this.timeStamp,
    this.origin,
  });

  @override
  String toString() {
    return "TomInterIsolateLogMessage $isolateName $level $message";
  }
}

// =============================================================================
// Isolate-Aware Log Outputs
// =============================================================================

/// Log output that routes messages to a dedicated logging isolate pool.
///
/// Use this in the main isolate to offload log processing to background
/// isolates, reducing logging overhead in performance-critical code.
///
/// ## Setup
///
/// ```dart
/// // Automatic setup via TomIsolateLogging
/// await TomIsolateLogging.startIsolatedLogging(args);
///
/// // Or manual setup
/// final pool = await TomWorkerPool.withSize(1, loggingContext);
/// tomLog.logOutput = TomIsolateLogOutput(pool);
/// ```
class TomIsolateLogOutput extends TomLogOutput {
  /// The worker pool that processes log messages.
  TomWorkerPool workerPool;

  /// Creates a log output that routes to the given worker pool.
  TomIsolateLogOutput(this.workerPool);

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
      // Log dispatch is intentionally fire-and-forget: an output must never
      // block or fail the caller that emitted the log line, so the pooled
      // delivery future is deliberately not awaited.
      unawaited(
        workerPool.execute(
          TomInterIsolateLogMessage(
            loggerLevel: loggerLevel,
            logLevel: logLevel,
            level: level,
            message: convertToString(message),
            isolateName: isolateName,
            timeStamp: timeStamp,
            origin: origin,
          ),
        ),
      );
    }
  }
}

/// Log output that sends messages back to the creator (main) isolate.
///
/// Use this in worker isolates to route all log messages back to the
/// main isolate for centralized processing.
///
/// If the connection to the creator isolate is not available, falls back to
/// [fallbackOutput] — any [TomLogOutput], defaulting to the console. A worker
/// that cannot reach its creator is precisely the case where the records
/// matter most, so where they land is configurable rather than fixed.
///
/// ## Setup
///
/// ```dart
/// // In worker isolate initialization
/// TomIsolateLogging.startLoggingToCreator();
/// ```
class TomCreatorLogOutput extends TomLogOutput {
  /// Creates a creator-routing log output.
  TomCreatorLogOutput();

  /// Fallback output used when the creator connection is unavailable.
  ///
  /// Declared as the [TomLogOutput] interface, not the concrete console class:
  /// this slot is a substitution point, and nothing in [output] needs more
  /// than the sink contract. Typing it concretely would mean a worker whose
  /// creator channel is missing could only ever fall back to the console —
  /// exactly when its records are least likely to be watched. The default is
  /// still a [TomConsoleLogOutput], so unconfigured behaviour is unchanged;
  /// this mirrors `TomRemoteLogOutput.globalSettingFallbackOutput`, which was
  /// already declared this way.
  static TomLogOutput fallbackOutput = TomConsoleLogOutput();

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
      if (TomWorker.canSendToCreator()) {
        TomWorker.sendToCreator(
          TomInterIsolateLogMessage(
            loggerLevel: loggerLevel,
            logLevel: logLevel,
            level: level,
            message: convertToString(message),
            isolateName: isolateName,
            timeStamp: timeStamp,
            origin: origin,
          ),
        );
      } else {
        fallbackOutput.output(
          loggerLevel,
          logLevel,
          level,
          message,
          isolateName,
          timeStamp,
          origin,
        );
      }
    }
  }
}

// =============================================================================
// Logging Isolate Configuration
// =============================================================================

/// Worker context for the logging isolate.
///
/// Extend this class to customize logging isolate initialization,
/// such as configuring custom output destinations.
///
/// ## Example
///
/// ```dart
/// class RemoteLoggingContext extends TomLoggingWorkerContext {
///   RemoteLoggingContext(super.env, super.platform, super.args, super.prefix);
///
///   @override
///   Future<void> initializeIsolate() async {
///     await super.initializeIsolate();
///     tomLog.logOutput = TomRemoteLogOutput();
///   }
/// }
/// ```
class TomLoggingWorkerContext extends TomWorkerContext {
  /// Creates a logging worker context.
  TomLoggingWorkerContext(
    super.tomEnvironment,
    super.tomPlatform,
    super.args,
    super.namePrefix,
  );

  @override
  Future<void> initializeIsolate() async {
    TomWorker.addExecutor(TomLoggingExecutor());
  }
}

/// Utility class for setting up isolate-based logging.
///
/// Provides convenient methods to initialize logging infrastructure
/// for both the main isolate and worker isolates.
///
/// ## Main Isolate
///
/// ```dart
/// await TomIsolateLogging.startIsolatedLogging(args);
/// ```
///
/// ## Worker Isolates
///
/// ```dart
/// TomIsolateLogging.startLoggingToCreator();
/// ```
class TomIsolateLogging {
  /// Initializes isolated logging with a dedicated worker pool.
  ///
  /// Creates a pool of logging workers and redirects all [tomLog] output
  /// to them for asynchronous processing.
  ///
  /// Parameters:
  /// - [args]: Command line arguments (passed to worker context)
  /// - [poolSize]: Number of logging workers (default: 1)
  /// - [workerContext]: Optional custom worker context for initialization
  ///
  /// ## Failure
  /// Returns nothing. Completing is the success signal: there is no partial
  /// outcome to report, because the pool is either spawned and installed or the
  /// call throws on the way. A `bool` here promised a failure report that no
  /// path ever produced — every return was `true` — so
  /// `if (!await startIsolatedLogging(args))` was dead code at every call site.
  ///
  /// Throws [TomException] (`logging.isolate.runtime_not_initialized`) when the
  /// runtime platform has not been registered and no [workerContext] was
  /// supplied, since the default context cannot be built without it. That is a
  /// startup-ordering mistake rather than a condition to recover from, which is
  /// why it is raised rather than reported: a boot step that cannot proceed
  /// should say so loudly, and a value callers would ignore is how a silent
  /// misconfiguration starts.
  static Future<void> startIsolatedLogging(
    List<String> args, {
    int poolSize = 1,
    TomLoggingWorkerContext? workerContext,
  }) async {
    final TomWorkerContext context =
        workerContext ?? _defaultWorkerContext(args);
    tomLog.logOutput = TomIsolateLogOutput(
      await TomWorkerPool.withSize(poolSize, context),
    );
  }

  /// The context [startIsolatedLogging] builds when the caller supplies none.
  ///
  /// Separate so the platform it needs is read in one place and refused with a
  /// sentence. Reading it as `TomRuntime.getCurrentPlatform()!` raised a bare
  /// `TypeError` naming the null check and nothing else — during application
  /// startup, where the reader has no context at all for what a null check
  /// operator has to do with logging.
  static TomLoggingWorkerContext _defaultWorkerContext(List<String> args) {
    final platform = TomRuntime.getCurrentPlatform();
    if (platform == null) {
      throw TomException(
        "logging.isolate.runtime_not_initialized",
        "Isolated logging cannot build its worker context because the runtime "
            "platform has not been registered. Register it during application "
            "startup — normally TomRuntime.setCurrentPlatform(...) — before "
            "calling startIsolatedLogging, or pass a workerContext of your "
            "own.",
      );
    }
    return TomLoggingWorkerContext(
      TomRuntime.getCurrentEnvironment(),
      platform,
      args,
      "L",
    );
  }

  /// Configures logging to send all messages to the creator isolate.
  ///
  /// Call this in worker isolate initialization to route all log
  /// messages back to the main isolate for centralized processing.
  static void startLoggingToCreator() {
    tomLog.logOutput = TomCreatorLogOutput();
  }
}
