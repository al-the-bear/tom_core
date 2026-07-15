/// Remote logging output for sending log messages to a centralized server.
///
/// This library enables applications to send log messages to a remote
/// logging server for centralized collection, analysis, and monitoring.
///
/// ## Features
///
/// - Asynchronous log transmission to remote servers
/// - Automatic fallback to local console on connection failure
/// - Re-entrancy protection to prevent infinite loops
/// - Configurable sender identification
///
/// ## Setup
///
/// ```dart
/// // Configure the remote endpoint
/// TomRemoteLogOutput.remoteEndpoint = TomServerEndpoint<
///     TomRemoteLogMessage, TomRemoteLogResult>(
///   baseUrl: 'https://logs.example.com',
///   path: '/api/logs',
/// );
///
/// // Switch to remote logging
/// tomLog.logOutput = TomRemoteLogOutput();
///
/// // Optional: Set a sender ID for this client
/// TomRemoteLogMessage.globalSettingSenderId = 'client-001';
/// ```
///
/// See also:
/// - [TomRemoteLogServer] for the server-side implementation
/// - [TomRemoteLogMessage] for the message format
/// - [TomRemoteLogResult] for response handling
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:async';

import 'package:tom_basics/tom_basics.dart';

import '../http_connection/server_connection.dart';
import '../little_things/little_things.dart';
import '../reflection/reflection.dart';

// =============================================================================
// Remote Log Message Types
// =============================================================================

/// Message format for transmitting log entries to a remote server.
///
/// This class is serialized and sent over HTTP to the remote logging
/// endpoint. It contains all information needed to reconstruct the
/// original log message on the server.
///
/// ## Sender Identification
///
/// Set [globalSettingSenderId] to identify which client sent the message:
///
/// ```dart
/// TomRemoteLogMessage.globalSettingSenderId = 'web-frontend-01';
/// ```
@tomReflector
class TomRemoteLogMessage {
  /// Global sender identifier prepended to all messages from this client.
  ///
  /// Set this at application startup to identify the source of log messages.
  static String globalSettingSenderId = "RDEF";

  /// The sender ID for this specific message (copied from [globalSettingSenderId]).
  String sender = "";

  /// ISO 8601 formatted timestamp of when the log was created.
  String timeStamp = DateTime.now().toIso8601String();

  /// The logger's configured level (as bit pattern).
  int loggerLevel = 0;

  /// The level of this message (as bit pattern).
  int logLevel = 0;

  /// Human-readable level string (e.g., \"INFO   \").
  String level = "";

  /// The log message content.
  String message = "";

  /// Name of the isolate that generated the log.
  String isolateName = "";

  /// Optional caller information (class.method).
  String? origin;

  /// Default constructor for deserialization.
  TomRemoteLogMessage();

  /// Creates a remote log message with all fields populated.
  TomRemoteLogMessage.of(
    this.loggerLevel,
    this.logLevel,
    this.level,
    this.message,
    this.isolateName,
    this.timeStamp,
    this.origin,
  ) {
    sender = globalSettingSenderId;
  }

  @override
  String toString() {
    return "TomRemoteLogMessage $isolateName $level $message";
  }
}

/// Response from the remote logging server.
///
/// Indicates whether the log message was successfully processed
/// or if an error occurred on the server side.
@tomReflector
class TomRemoteLogResult {
  /// Whether an error occurred during log processing.
  bool hasError = false;

  /// Error message if [hasError] is `true`.
  String errorMessage = "";

  /// Default constructor for successful results.
  TomRemoteLogResult();

  /// Creates an error result with the given message.
  TomRemoteLogResult.withError(this.errorMessage) {
    hasError = true;
  }

  @override
  String toString() {
    return "TomRemoteLogResult $hasError $errorMessage";
  }
}

// =============================================================================
// Logging Context
// =============================================================================

/// Zone-local context to prevent recursive logging.
///
/// Used internally by [TomRemoteLogOutput] to detect when we're already
/// inside a remote logging operation, preventing infinite loops.
class TomLoggingContext {
  /// Whether we're currently inside a remote logging operation.
  bool inRemoteLogging;

  /// Creates a logging context.
  TomLoggingContext({this.inRemoteLogging = false});
}

// =============================================================================
// Remote Log Output
// =============================================================================

/// Log output that sends messages to a remote logging server.
///
/// This output implementation transmits log messages over HTTP to a
/// centralized logging server for collection and analysis.
///
/// ## Configuration
///
/// ```dart
/// // Set up the remote endpoint
/// TomRemoteLogOutput.remoteEndpoint = TomServerEndpoint<
///     TomRemoteLogMessage, TomRemoteLogResult>(
///   baseUrl: 'https://logs.example.com',
///   path: '/api/logs',
/// );
///
/// // Activate remote logging
/// tomLog.logOutput = TomRemoteLogOutput();
/// ```
///
/// ## Fallback Behavior
///
/// If the remote endpoint is unavailable or not configured, messages
/// are written to [globalSettingFallbackOutput] (console by default).
///
/// ## Error Handling
///
/// Connection errors are caught and logged locally. The original
/// message is also written to the fallback output to prevent data loss.
class TomRemoteLogOutput extends TomLogOutput {
  /// Fallback output used when remote logging fails or is not configured.
  static TomLogOutput globalSettingFallbackOutput = TomConsoleLogOutput();

  /// The configured remote endpoint for log transmission.
  ///
  /// Must be set before remote logging will work. If `null`, all messages
  /// fall back to [globalSettingFallbackOutput].
  static TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>?
  remoteEndpoint;

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) async {
    var tlc = getFromCurrentZone<TomLoggingContext>();
    if (remoteEndpoint == null || (tlc != null && tlc.inRemoteLogging)) {
      globalSettingFallbackOutput.output(
        loggerLevel,
        logLevel,
        level,
        message,
        isolateName,
        timeStamp,
        origin,
      );
      return;
    }
    await runZoned(
      zoneValues: {TomLoggingContext: TomLoggingContext(inRemoteLogging: true)},
      () async {
        var response = TomRemoteLogResult();
        final remoteMessage = TomRemoteLogMessage.of(
          loggerLevel.levelPattern,
          logLevel.levelPattern,
          level,
          convertToString(message),
          isolateName,
          timeStamp.toIso8601String(),
          origin,
        );
        try {
          var (result, error) = await remoteEndpoint!.send(
            remoteMessage,
            response,
          );
          // A *returned* (non-thrown) transport error means the endpoint
          // answered but rejected the record; surface it locally so it is not
          // silently dropped. Resilience beyond this (retry-with-backoff, a
          // bounded replay queue of the last N records) is a deliberate
          // enhancement tracked separately — see RCI residual in the tom_core
          // quest todos — and is intentionally not attempted inline here.
          if (error != null && error.hasError) {
            print(
              "Sending log message to endpoint returned $result, error: $error",
            );
          }
        } catch (error) {
          try {
            globalSettingFallbackOutput.output(
              TomLogLevel.warn,
              TomLogLevel.warn,
              "WARN  ",
              "Exception occured when trying to send log message to server: $error",
              TomPlatformUtils.current.getIsolateName(),
              DateTime.now(),
              origin,
            );
            try {
              globalSettingFallbackOutput.output(
                loggerLevel,
                logLevel,
                level,
                message,
                isolateName,
                timeStamp,
                origin,
              );
            } catch (error) {
              globalSettingFallbackOutput.output(
                TomLogLevel.warn,
                TomLogLevel.warn,
                "WARN  ",
                "Exception occured when trying to log problematic message locally: $error",
                TomPlatformUtils.current.getIsolateName(),
                DateTime.now(),
                origin,
              );
            }
          } catch (e2) {
            // ignore now
          }
        }
      },
    );
  }
}
