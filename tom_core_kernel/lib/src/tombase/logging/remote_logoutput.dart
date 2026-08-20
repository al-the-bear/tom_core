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
/// See [TomRemoteLogOutput] for the wiring snippet. It is deliberately not
/// repeated here: this library and its primary class are read together, and
/// when the two carried the same snippet both went stale at once — each
/// showing a `TomServerEndpoint` constructor the class does not have.
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
// Replay Store
// =============================================================================

/// Pluggable backend for [TomRemoteLogOutput]'s replay queue.
///
/// The replay queue buffers records that failed every send attempt so they can
/// be re-sent, oldest-first, once the endpoint recovers. This interface lets
/// the *storage* of that queue be swapped out: the default keeps records in
/// memory (see [TomInMemoryLogReplayStore]), while a durable implementation can
/// persist them so buffered records survive a process restart during an outage.
///
/// Implementations own ordering: records must be returned in the same order
/// they were [append]ed (FIFO). [oldest] / [removeOldest] drive the drain loop;
/// [trim] enforces the bound; [clear] resets the queue.
abstract interface class TomLogReplayStore {
  /// The number of records currently buffered.
  int get length;

  /// Appends [message] to the tail of the queue.
  void append(TomRemoteLogMessage message);

  /// Returns a copy of all buffered records in arrival (FIFO) order.
  List<TomRemoteLogMessage> snapshot();

  /// The oldest buffered record, or `null` when the queue is empty.
  TomRemoteLogMessage? get oldest;

  /// Removes the oldest buffered record. A no-op when the queue is empty.
  void removeOldest();

  /// Drops the oldest records until at most [maxSize] remain.
  ///
  /// A non-positive [maxSize] clears the queue.
  void trim(int maxSize);

  /// Discards every buffered record.
  void clear();
}

/// In-memory [TomLogReplayStore] — the zero-config default.
///
/// Buffered records live in a plain list and are lost if the process exits
/// while the queue is non-empty. This matches the historical behaviour of the
/// replay queue; use a durable store (e.g. a file-backed one) to harden the
/// restart-during-outage edge.
class TomInMemoryLogReplayStore implements TomLogReplayStore {
  final List<TomRemoteLogMessage> _records = [];

  @override
  int get length => _records.length;

  @override
  void append(TomRemoteLogMessage message) => _records.add(message);

  @override
  List<TomRemoteLogMessage> snapshot() => List.of(_records);

  @override
  TomRemoteLogMessage? get oldest => _records.isEmpty ? null : _records.first;

  @override
  void removeOldest() {
    if (_records.isNotEmpty) _records.removeAt(0);
  }

  @override
  void trim(int maxSize) {
    if (maxSize <= 0) {
      _records.clear();
      return;
    }
    while (_records.length > maxSize) {
      _records.removeAt(0);
    }
  }

  @override
  void clear() => _records.clear();
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
/// // Optional: identify this client in the collector's log stream.
/// TomRemoteLogMessage.globalSettingSenderId = 'client-001';
///
/// // Set up the remote endpoint. TomServerEndpoint takes a channel (host and
/// // port) and call specs (method and full URL) — there is no baseUrl/path
/// // constructor. Building it opens no connection: the channel creates its
/// // HTTP client lazily, on the first call.
/// TomRemoteLogOutput.remoteEndpoint =
///     TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>(
///       TomServerChannel('logs.example.com', 443),
///       TomServerCallSpecs(
///         'POST',
///         Uri.parse('https://logs.example.com/api/logs'),
///       ),
///     );
///
/// // Activate remote logging
/// tomLog.logOutput = TomRemoteLogOutput();
/// ```
///
/// That snippet is a copy of step 3 of
/// `example/samples/logging/05_isolate_and_remote_logging_example.dart`, where
/// it is compiled, analyzed and asserted. Change it there and copy it out: it
/// previously showed a `baseUrl`/`path` constructor that does not exist, and
/// documentation has no build to fail.
///
/// ## Fallback Behavior
///
/// If the remote endpoint is unavailable or not configured, messages
/// are written to [globalSettingFallbackOutput] (console by default).
///
/// The fallback is the last sink in the chain, so if it throws — a full disk
/// for a file sink, a closed port, a misconfigured custom output — the record
/// is lost. It is never lost *silently*: the failure is announced once per
/// installed fallback on [TomPlatformUtils.outError], which sits below the
/// logging stack and so cannot be broken by the same misconfiguration. The
/// throw itself never reaches the caller.
///
/// ## Error Handling and Resilience
///
/// A send is considered *failed* whenever it does not reach a server that
/// accepted it: the endpoint could not be reached at all, the server answered
/// with an error, or the send threw. In every case the record is never silently
/// dropped, and the accompanying warning names which of the three happened —
/// an unreachable endpoint is not reported as a rejection.
///
/// "The server answered with an error" covers **both** channels the endpoint
/// can report one on, because a record is equally lost either way: a
/// transport-level failure ([TomServerCallError] — a non-2xx status, an
/// internal error) and an application-level refusal carried in the response
/// body ([TomRemoteLogResult.hasError]) on an otherwise perfect HTTP 200. The
/// second is what a healthy collector uses to say "received, not stored", and
/// the server's own [TomRemoteLogResult.errorMessage] is reproduced in the
/// warning.
///
/// On failure the output:
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
/// Delivery is serialised: records are handed to the endpoint one at a time,
/// in the order [output] was called, however many callers or instances there
/// are. [output] returns before its record has been sent (see its signature),
/// so overlapping calls are the normal case rather than the exception — and
/// without serialisation each of them would run its own drain over the shared
/// replay queue, re-sending records another drain had read but not yet
/// removed. The guarantee covers one isolate, which is exactly the scope of
/// the queue it protects: both are statics, and Dart statics are per-isolate.
///
/// Serialisation is between *records*, not the whole logging call: [output]
/// still returns immediately, and the caller is never blocked.
///
/// The defaults (no retries, no backoff, no replay queue) keep behaviour
/// predictable and testable without a live server: one attempt, fall back on
/// failure. Opt into resilience by setting the `globalSetting*` knobs.
class TomRemoteLogOutput extends TomLogOutput {
  /// Fallback output used when remote logging fails or is not configured.
  ///
  /// Assigning a new output re-arms the one-shot report described in
  /// [_reportFallbackFailure]: the previous output's brokenness says nothing
  /// about its replacement.
  static TomLogOutput get globalSettingFallbackOutput =>
      _globalSettingFallbackOutput;

  static set globalSettingFallbackOutput(TomLogOutput output) {
    _globalSettingFallbackOutput = output;
    _fallbackFailureReported = false;
  }

  static TomLogOutput _globalSettingFallbackOutput = TomConsoleLogOutput();

  /// Whether the "the fallback itself failed" report has already been written
  /// for the currently installed [globalSettingFallbackOutput].
  static bool _fallbackFailureReported = false;

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

  /// Backend that stores records awaiting replay after failing every send
  /// attempt.
  ///
  /// Defaults to an in-memory store ([TomInMemoryLogReplayStore]), so the
  /// replay queue is zero-config and stays entirely in process. Assign a
  /// durable implementation (e.g. a file-backed store) to make buffered
  /// records survive a restart while the endpoint is down. Bounded by
  /// [globalSettingReplayQueueMaxSize]; drained oldest-first on the next
  /// successful send. Shared across instances since a single remote endpoint
  /// is assumed.
  static TomLogReplayStore globalSettingReplayStore =
      TomInMemoryLogReplayStore();

  /// The number of records currently buffered for replay (for diagnostics
  /// and tests).
  static int get replayQueueLength => globalSettingReplayStore.length;

  /// Discards every buffered record.
  ///
  /// Use when reconfiguring [remoteEndpoint] so records queued for a previous
  /// endpoint are not replayed to the new one.
  static void clearReplayQueue() => globalSettingReplayStore.clear();

  /// Tail of the delivery lane: completes when the most recently claimed
  /// record has finished draining, sending and (if it failed) being buffered.
  ///
  /// Shared with [globalSettingReplayStore], whose scope it matches: both are
  /// per-isolate statics, so the lane serialises every record an isolate
  /// produces against the same isolate's queue.
  static Future<void> _deliveryLane = Future<void>.value();

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
      } catch (error, stackTrace) {
        // This branch runs before the first await, so an escaping throw does
        // not merely lose the record: it propagates straight back into the
        // caller's `tomLog.info(...)` line and takes down whatever was being
        // logged about. A logging sink must never do that.
        _reportFallbackFailure(message, error, stackTrace);
      }
      return;
    }
    // Claim a slot in the delivery lane *before the first await*, so slots are
    // ordered by call order rather than by whichever caller happens to resume
    // first. Without this, two records emitted back to back race each other to
    // the endpoint, and each runs its own drain over the shared replay store —
    // re-sending records the other has already taken but not yet removed.
    final predecessor = _deliveryLane;
    final slot = Completer<void>();
    _deliveryLane = slot.future;
    try {
      await predecessor;
      await runZoned(
        zoneValues: {
          TomLoggingContext: TomLoggingContext(inRemoteLogging: true),
        },
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
    } finally {
      // Always completed, never completed with an error: the lane is a
      // chain, so a failed slot would fail every record queued behind it.
      // Delivery failures are already handled inside the zone above.
      slot.complete();
    }
  }

  /// Sends [remoteMessage] once, translating every way the send can fail into
  /// a single failure description.
  ///
  /// Returns `null` only when a server accepted the record, or a human-readable
  /// failure description naming which kind of failure it was: the server was
  /// never reached, the server answered with an error, or the endpoint threw.
  ///
  /// The endpoint reports failure on two independent channels and both are
  /// read here. [TomServerCallError] is purely transport-level — it knows the
  /// status code and nothing about the payload — so a collector that answers
  /// HTTP 200 carrying a [TomRemoteLogResult.hasError] body signals no
  /// transport error at all. Testing only the transport channel treated such a
  /// rejection as a complete success and dropped the record without retry,
  /// fallback or replay.
  Future<String?> _sendOnce(TomRemoteLogMessage remoteMessage) async {
    try {
      var (result, error) = await remoteEndpoint!.send(
        remoteMessage,
        TomRemoteLogResult(),
      );
      if (error != null && error.hasError) {
        if (_isUnreachable(error)) {
          // No server ever saw this record, so it was not rejected. The cause
          // is only in `exception` — TomServerCallError.toString() reports the
          // status and the body, and an unreachable endpoint has neither.
          return "server unreachable: ${error.exception ?? error}";
        }
        return "server rejected record: $error";
      }
      // The transport is clean, so whatever the endpoint returned is what the
      // server decided — and a refusal in the payload is still a refusal: the
      // record did not land.
      if (result.hasError) {
        // The reason is the only thing the server said about the refusal, so
        // it is what the fallback line has to carry. An error result with no
        // message is possible (the field defaults to empty when the server
        // omits it), and reporting that as a blank reason would reproduce the
        // silence this whole method exists to break.
        final reason = result.errorMessage.isEmpty
            ? "no reason given"
            : result.errorMessage;
        return "server rejected record: $reason";
      }
      return null;
    } catch (error) {
      return "transport error: $error";
    }
  }

  /// Whether [error] means the request never produced a response, as opposed to
  /// producing one that failed.
  ///
  /// The internal code alone cannot decide this: `noResponseError` and
  /// `serverError` currently share the value `2`. A delivered response always
  /// carries a status, so a status of `0` is what separates them. Once the two
  /// codes differ, the status test becomes redundant and can go.
  bool _isUnreachable(TomServerCallError error) =>
      error.internalError == TomServerCallError.noResponseError &&
      error.statusCode == 0;

  /// Sends [remoteMessage] with bounded retry and linear backoff.
  ///
  /// Returns `null` once a send succeeds, or the last failure description if
  /// every attempt (the first plus [globalSettingMaxSendRetries] retries)
  /// fails.
  Future<String?> _sendWithRetry(TomRemoteLogMessage remoteMessage) async {
    final maxRetries = globalSettingMaxSendRetries < 0
        ? 0
        : globalSettingMaxSendRetries;
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
  ///
  /// A record is removed only once the server has accepted it, so a crash
  /// mid-drain replays it rather than losing it. That leaves the record
  /// readable by anyone else draining at the same time, which is why callers
  /// must hold a delivery-lane slot (see [output]): the lane, not this loop,
  /// is what stops a second drain from re-sending what this one has in flight.
  Future<void> _drainReplayQueue() async {
    final store = globalSettingReplayStore;
    for (var next = store.oldest; next != null; next = store.oldest) {
      if (await _sendWithRetry(next) == null) {
        store.removeOldest();
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
    globalSettingReplayStore.append(remoteMessage);
    globalSettingReplayStore.trim(maxSize);
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
        // The fallback is alive but refused this one record — an over-long
        // line, an unencodable character, a message whose `toString` throws.
        // That is a per-record fault, so it is announced through the fallback
        // itself and repeats for every record that hits it. If the fallback is
        // in fact dead, this write throws too and lands in the catch below.
        globalSettingFallbackOutput.output(
          TomLogLevel.warn,
          TomLogLevel.warn,
          "WARN  ",
          "Exception occurred when trying to log problematic message locally: $error",
          TomPlatformUtils.current.getIsolateName(),
          DateTime.now(),
          origin,
        );
      }
    } catch (error, stackTrace) {
      _reportFallbackFailure(message, error, stackTrace);
    }
  }

  /// Announces on the platform's error channel that
  /// [globalSettingFallbackOutput] itself failed, and that [record] is
  /// therefore lost.
  ///
  /// The record cannot be saved — the fallback is the last sink in the chain,
  /// so there is nowhere left to write it. That makes discarding the failure
  /// tempting, but "must not throw" and "must not tell anyone" are different
  /// requirements, and only the first one is a property of a well-behaved
  /// logging sink. Silence here would make every other guarantee in this class
  /// unverifiable in production: a process with a misconfigured fallback would
  /// report perfect health while losing every record.
  ///
  /// The report goes to [TomPlatformUtils.outError] rather than to any
  /// [TomLogOutput], because the logging stack is the thing that just failed;
  /// routing the news through it would be the same mistake one level up.
  ///
  /// It is written **once per installed fallback**. A fallback that is broken
  /// is normally broken for every record, so a per-record report would turn one
  /// misconfiguration into exactly the flood the fallback exists to prevent.
  /// Installing a different output re-arms it (see
  /// [globalSettingFallbackOutput]).
  static void _reportFallbackFailure(
    Object record,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_fallbackFailureReported) return;
    _fallbackFailureReported = true;
    // Rendered separately: a message whose `toString` throws is one of the
    // reasons a sink refuses a record, so interpolating it inline would let the
    // report be lost by the very fault it is reporting.
    String rendered;
    try {
      rendered = "$record";
    } catch (renderError) {
      rendered =
          "<a ${record.runtimeType} that could not be rendered: "
          "$renderError>";
    }
    try {
      TomPlatformUtils.current.outError(
        "TomRemoteLogOutput: the fallback log output "
        "(${globalSettingFallbackOutput.runtimeType}) failed, so the record "
        "below could not be written anywhere and is lost. Further failures of "
        "this fallback are not reported.\n"
        "  Error:  $error\n"
        "  Record: $rendered\n"
        "$stackTrace",
      );
    } catch (_) {
      // Below the platform's own error channel there is nothing left to try,
      // and this method exists precisely so that a broken sink cannot become
      // a thrown exception.
    }
  }
}
