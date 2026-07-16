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
/// ## Error Handling and Resilience
///
/// A send is considered *failed* both when the transport throws and when the
/// server answers with an error result ([TomRemoteLogResult.hasError]) — in
/// either case the record is never silently dropped. On failure the output:
///
/// 1. retries the send up to [globalSettingMaxSendRetries] additional times,
///    waiting [globalSettingRetryBackoff] × attempt between tries (linear
///    backoff; a zero backoff retries immediately);
/// 2. if every attempt fails, writes the original record to
///    [globalSettingFallbackOutput] (console by default) so it is not lost;
/// 3. if a replay queue is enabled ([globalSettingReplayQueueMaxSize] > 0),
///    enqueues the record for a later retry. The queue is bounded and drops
///    the *oldest* record on overflow.
///
/// Whenever a subsequent record is sent, the output first drains the replay
/// queue oldest-first, stopping as soon as a queued record fails again (the
/// endpoint is still down). This lets records that piled up during an outage
/// flush in order once the endpoint recovers.
///
/// The defaults (no retries, no backoff, no replay queue) keep behaviour
/// predictable and testable without a live server: one attempt, fall back on
/// failure. Opt into resilience by setting the `globalSetting*` knobs.
class TomRemoteLogOutput extends TomLogOutput {
  /// Fallback output used when remote logging fails or is not configured.
  static TomLogOutput globalSettingFallbackOutput = TomConsoleLogOutput();

  /// The configured remote endpoint for log transmission.
  ///
  /// Must be set before remote logging will work. If `null`, all messages
  /// fall back to [globalSettingFallbackOutput].
  static TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>?
  remoteEndpoint;

  /// Number of *additional* send attempts after the first one fails.
  ///
  /// A value of `0` (the default) means a single attempt with no retry. A
  /// value of `n` means up to `n + 1` total attempts before the record is
  /// routed to the fallback / replay queue.
  static int globalSettingMaxSendRetries = 0;

  /// Base delay between retries; the wait before retry *k* is `backoff × k`.
  ///
  /// [Duration.zero] (the default) retries immediately with no delay, which
  /// keeps tests fast and behaviour deterministic.
  static Duration globalSettingRetryBackoff = Duration.zero;

  /// Maximum number of records held in the in-memory replay queue.
  ///
  /// `0` (the default) disables the queue entirely. When greater than zero,
  /// records that exhaust their retries are enqueued (dropping the oldest on
  /// overflow) and re-sent, oldest-first, on the next successful transmission.
  static int globalSettingReplayQueueMaxSize = 0;

  /// Records awaiting replay after failing every send attempt.
  ///
  /// Bounded by [globalSettingReplayQueueMaxSize]; drained oldest-first on the
  /// next successful send. Shared across instances since a single remote
  /// endpoint is assumed.
  static final List<TomRemoteLogMessage> _replayQueue = [];

  /// The number of records currently buffered for replay (for diagnostics
  /// and tests).
  static int get replayQueueLength => _replayQueue.length;

  /// Discards every buffered record.
  ///
  /// Use when reconfiguring [remoteEndpoint] so records queued for a previous
  /// endpoint are not replayed to the new one.
  static void clearReplayQueue() => _replayQueue.clear();

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
        final remoteMessage = TomRemoteLogMessage.of(
          loggerLevel.levelPattern,
          logLevel.levelPattern,
          level,
          convertToString(message),
          isolateName,
          timeStamp.toIso8601String(),
          origin,
        );
        // Flush anything that piled up while the endpoint was unreachable
        // before sending the current record, preserving arrival order.
        await _drainReplayQueue();
        final failure = await _sendWithRetry(remoteMessage);
        if (failure != null) {
          _logToFallback(
            loggerLevel,
            logLevel,
            level,
            message,
            isolateName,
            timeStamp,
            origin,
            failure,
          );
          _enqueueForReplay(remoteMessage);
        }
      },
    );
  }

  /// Sends [remoteMessage] once, translating both a thrown transport error and
  /// a returned server-rejection into a failure.
  ///
  /// Returns `null` on success, or a human-readable failure description.
  Future<String?> _sendOnce(TomRemoteLogMessage remoteMessage) async {
    try {
      var (_, error) = await remoteEndpoint!.send(
        remoteMessage,
        TomRemoteLogResult(),
      );
      if (error == null || !error.hasError) return null;
      return "server rejected record: $error";
    } catch (error) {
      return "transport error: $error";
    }
  }

  /// Sends [remoteMessage] with bounded retry and linear backoff.
  ///
  /// Returns `null` once a send succeeds, or the last failure description if
  /// every attempt (the first plus [globalSettingMaxSendRetries] retries)
  /// fails.
  Future<String?> _sendWithRetry(TomRemoteLogMessage remoteMessage) async {
    final maxRetries =
        globalSettingMaxSendRetries < 0 ? 0 : globalSettingMaxSendRetries;
    String? lastFailure;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0 && globalSettingRetryBackoff > Duration.zero) {
        await Future.delayed(globalSettingRetryBackoff * attempt);
      }
      lastFailure = await _sendOnce(remoteMessage);
      if (lastFailure == null) return null;
    }
    return lastFailure ?? "unknown send failure";
  }

  /// Re-sends buffered records oldest-first, stopping at the first one that
  /// still fails (the endpoint is presumed down again).
  Future<void> _drainReplayQueue() async {
    while (_replayQueue.isNotEmpty) {
      if (await _sendWithRetry(_replayQueue.first) == null) {
        _replayQueue.removeAt(0);
      } else {
        break;
      }
    }
  }

  /// Buffers [remoteMessage] for later replay, dropping the oldest record when
  /// the queue exceeds [globalSettingReplayQueueMaxSize]. A non-positive size
  /// disables buffering.
  void _enqueueForReplay(TomRemoteLogMessage remoteMessage) {
    final maxSize = globalSettingReplayQueueMaxSize;
    if (maxSize <= 0) return;
    _replayQueue.add(remoteMessage);
    while (_replayQueue.length > maxSize) {
      _replayQueue.removeAt(0);
    }
  }

  /// Writes the original record (and a warning describing [cause]) to the
  /// fallback output so a failed transmission never loses data.
  void _logToFallback(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp,
    String? origin,
    String cause,
  ) {
    try {
      globalSettingFallbackOutput.output(
        TomLogLevel.warn,
        TomLogLevel.warn,
        "WARN  ",
        "Could not send log message to remote server ($cause)",
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
    } catch (_) {
      // The fallback output itself failed; nothing more we can safely do.
    }
  }
}
