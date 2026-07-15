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
/// void main() async {
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
/// During isolate initialization, you can replace the log output:
///
/// ```dart
/// class CustomLoggingContext extends TomLoggingWorkerContext {
///   @override
///   Future<bool> initializeIsolate() async {
///     await super.initializeIsolate();
///     // Redirect all collected logs to a file
///     tomLog.logOutput = FileLogOutput();
///     return true;
///   }
/// }
/// ```
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
  TomInterIsolateLogMessage(
    this.loggerLevel,
    this.logLevel,
    this.level,
    this.message,
    this.isolateName,
    this.timeStamp,
    this.origin,
  );

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
            loggerLevel,
            logLevel,
            level,
            convertToString(message),
            isolateName,
            timeStamp,
            origin,
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
/// If the connection to the creator isolate is not available, falls back
/// to console output via [fallbackOutput].
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
  static TomConsoleLogOutput fallbackOutput = TomConsoleLogOutput();

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
            loggerLevel,
            logLevel,
            level,
            convertToString(message),
            isolateName,
            timeStamp,
            origin,
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
///   Future<bool> initializeIsolate() async {
///     await super.initializeIsolate();
///     tomLog.logOutput = TomRemoteLogOutput();
///     return true;
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
  Future<bool> initializeIsolate() async {
    TomWorker.executors.add(TomLoggingExecutor());
    return true;
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
  /// Returns `true` when logging is successfully initialized.
  static Future<bool> startIsolatedLogging(
    List<String> args, {
    int poolSize = 1,
    TomLoggingWorkerContext? workerContext,
  }) async {
    TomWorkerContext context =
        workerContext ??
        TomLoggingWorkerContext(
          TomRuntime.getCurrentEnvironment(),
          TomRuntime.getCurrentPlatform()!,
          args,
          "L",
        );
    tomLog.logOutput = TomIsolateLogOutput(
      await TomWorkerPool.withSize(poolSize, context),
    );
    return true;
  }

  /// Configures logging to send all messages to the creator isolate.
  ///
  /// Call this in worker isolate initialization to route all log
  /// messages back to the main isolate for centralized processing.
  static void startLoggingToCreator() {
    tomLog.logOutput = TomCreatorLogOutput();
  }
}
