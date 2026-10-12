/// Server-side implementation for receiving remote log messages.
///
/// This library provides the server component for centralized logging,
/// receiving log messages from remote clients and processing them locally.
///
/// ## Features
///
/// - Receives log messages via HTTP endpoint
/// - Reconstructs original log format with sender identification
/// - Configurable local output destination
///
/// ## Server Setup
///
/// ```dart
/// // Register the log server endpoint
/// final logServer = TomRemoteLogServer();
///
/// // Configure where received logs should be written
/// TomRemoteLogServer.localOutput = TomConsoleLogOutput();
///
/// // The endpoint expects TomRemoteLogMessage and returns TomRemoteLogResult.
/// // Neither type carries fromJson/toJson of its own — both are @tomReflector
/// // types, so serialisation goes through tomReflectionInfo. That is the same
/// // route TomServerEndpoint.send takes on the client, which is what makes a
/// // collector written this way agree with the sender by construction.
/// router.post('/remotelog', (request) async {
///   final message = tomReflectionInfo.convertFromJsonString(
///     TomRemoteLogMessage(),
///     await request.readAsString(),
///   );
///   final result = logServer.receive(message);
///   return Response.ok(tomReflectionInfo.convertToJsonString(result));
/// });
/// ```
///
/// The serialisation half of that snippet is a copy of step 4 of
/// `example/samples/logging/05_isolate_and_remote_logging_example.dart`, where
/// the round-trip runs and is asserted. Change it there and copy it out: prose
/// cannot fail to build, and neither message type carries a `fromJson` or
/// `toJson` for a snippet to reach for by habit.
///
/// See also:
/// - [TomRemoteLogOutput] for the client-side implementation
/// - [TomRemoteLogMessage] for the message format
library;

// =============================================================================
// Imports
// =============================================================================

import 'package:tom_basics/tom_basics.dart';

import '../reflection/reflection.dart';
import 'remote_logoutput.dart';

// =============================================================================
// Remote Log Server
// =============================================================================

/// Server-side handler for receiving remote log messages.
///
/// This class processes incoming [TomRemoteLogMessage] objects from clients
/// and outputs them through [effectiveOutput].
///
/// ## Configuration
///
/// Records go to the application's own sink — whatever `tomLog.logOutput` is
/// when each record arrives — unless [localOutput] is set to override it. Set
/// it to control where received logs are written; it is a [TomLogOutput], so
/// any sink can receive the collected records:
///
/// ```dart
/// // Write to the console.
/// TomRemoteLogServer.localOutput = TomConsoleLogOutput();
///
/// // Or relay onwards to a collector further up the chain.
/// TomRemoteLogServer.localOutput = TomRemoteLogOutput();
/// ```
///
/// The kernel ships no file sink and no composite sink. To write received
/// records to a file, or to fan out to more than one destination, implement
/// [TomLogOutput] and assign an instance here; `doc/logging/logging.md` has a
/// worked file-writing implementation.
///
/// ## Message Processing
///
/// Received messages are prefixed with the sender ID to identify
/// which client generated the log:
///
/// ```
/// 2024-01-15T10:30:00.000Z client-001_main INFO   Application started
/// ```
///
/// ## Bounds on an untrusted record
///
/// Every field of a received message is attacker-controlled, so each one is
/// capped as it is sanitized — 8192 UTF-16 code units, with the cut announced
/// by a `…[truncated]` suffix inside that limit rather than past it.
///
/// The cap is per field, and deliberately so: a record's bound follows from it
/// — four sanitized fields, so at most four times the cap reaches
/// [effectiveOutput] from one [receive] call — and a second, whole-record budget would have to
/// choose which field to sacrifice when the record as a whole is too large, a
/// choice no rule here can make better than the per-field one. What is *not*
/// bounded here is how many records a client may send; that is a property of
/// the transport, and a collector endpoint belongs behind the same
/// authentication and rate limiting as any other write endpoint.
///
/// ## Refusals
///
/// A record can be refused for two independent reasons — the message is
/// undecodable, or [effectiveOutput] is broken. [receive] names which in the
/// [TomRemoteLogResult] it returns *and* logs it locally at error level; see
/// [receive] for why both are needed and why the local half ignores the
/// sender's own logger level.
@tomReflector
class TomRemoteLogServer {
  /// Overrides where received log messages are written.
  ///
  /// `null` — the default — means the collector writes to the application's
  /// own sink, read from `tomLog.logOutput` as each record arrives. Assign a
  /// [TomLogOutput] to send received records somewhere else; assign `null`
  /// again to go back to following the application.
  ///
  /// Nullable rather than initialised to `tomLog.logOutput`, and that is the
  /// point. Dart initialises a static lazily, on first access, so such a
  /// default captures whatever the application's sink happens to be at the
  /// moment something first touches the field — an unspecified time that
  /// depends on program ordering rather than on intent. An application that
  /// configures its logging during startup would get the new sink only if
  /// nothing had read the field first; otherwise the collector writes to the
  /// original sink for the life of the process and nothing reports the
  /// divergence. "The local sink" means the sink the application currently
  /// has, which is what this field's description says.
  ///
  /// [effectiveOutput] answers where records actually go.
  static TomLogOutput? localOutput;

  /// The sink received records are written to: [localOutput] when one is set,
  /// the application's `tomLog.logOutput` otherwise.
  ///
  /// Resolved per record rather than once, so reconfiguring either side takes
  /// effect on the next record instead of depending on which was touched
  /// first.
  static TomLogOutput get effectiveOutput => localOutput ?? tomLog.logOutput;

  /// Processes an incoming remote log message.
  ///
  /// Reconstructs the log entry from [m] and outputs it through
  /// [effectiveOutput].
  /// The isolate name is prefixed with the sender ID for identification.
  ///
  /// Returns a [TomRemoteLogResult] indicating success or failure. On failure
  /// the caught error is folded into [TomRemoteLogResult.errorMessage] and the
  /// refusal is recorded locally by [_reportRefusal]. Two independent things
  /// can fail here — the message can be undecodable (a malformed
  /// [TomRemoteLogMessage.timeStamp]) or [effectiveOutput] can be broken — and the
  /// caller is a remote process with nothing else to inspect, so a generic
  /// "failed" tells it neither what went wrong nor whether retrying could
  /// help.
  TomRemoteLogResult receive(TomRemoteLogMessage m) {
    try {
      final origin = m.origin;
      effectiveOutput.output(
        TomLogLevel(m.loggerLevel),
        TomLogLevel(m.logLevel),
        _sanitize(m.level),
        _sanitize('${m.message}'),
        _sanitize(_streamName(m)),
        DateTime.parse(m.timeStamp),
        origin == null ? null : _sanitize(origin),
      );
      return TomRemoteLogResult();
    } catch (error) {
      // Sanitized like every other reported field, and for the same reason:
      // the error text is derived from client input. `FormatException` embeds
      // the offending string verbatim, after a newline — so reporting
      // `$error` raw would reopen the CWE-117 hole that sanitizing the fields
      // closed, using the rejection path as the carrier.
      final reason = _sanitize('$error');
      _reportRefusal(m, reason);
      return TomRemoteLogResult.withError(
        "Failed to log message on server side: $reason",
      );
    }
  }

  /// Records a refused record in this server's own log stream.
  ///
  /// Without this the refusal is visible only to the client that caused it:
  /// the operator of the collector just sees a record never arrive.
  ///
  /// The refusal is the *server's* event, so it is emitted at
  /// [TomLogLevel.error] against [TomLogLevel.errors] rather than against
  /// `m.loggerLevel`. That field is client-supplied and defaults to `0` — log
  /// nothing — so honouring it would let a malformed message suppress the
  /// record of its own rejection. [DateTime.now] for the same class of
  /// reason: parsing `m.timeStamp` is one of the two things that can fail
  /// here, and the refusal happened now regardless of when the record claims
  /// to have been written.
  void _reportRefusal(TomRemoteLogMessage m, String reason) {
    try {
      effectiveOutput.output(
        TomLogLevel.errors,
        TomLogLevel.error,
        TomLogger.ERROR,
        'Refused remote log record: $reason',
        _sanitize(_streamName(m)),
        DateTime.now(),
        'TomRemoteLogServer.receive',
      );
    } catch (_) {
      // A broken sink is one of the two causes this method exists to report,
      // so it may well fail again here. There is no second sink to fall back
      // to — `tomLog.logOutput` is routinely the same object, and is the sink
      // itself whenever [localOutput] is unset.
      // Rethrowing would escape `receive`'s catch and take down the
      // collector's HTTP handler on input a remote client controls, which is
      // strictly worse than a lost diagnostic. The cause still reaches that
      // client in the returned `errorMessage`.
    }
  }

  /// The stream name a record is filed under: the sender and the isolate that
  /// wrote it, or the isolate alone when the sender said nothing.
  ///
  /// This is what a collector's per-client files are named after, so it is the
  /// only thing separating two servers of one deployment. Dropping the
  /// separator for an unnamed sender is not cosmetic: `_main` and `auth_main`
  /// sort apart while looking like the same shape, and a reader of the
  /// directory cannot tell whether the empty half was a sender called nothing
  /// or a field that never arrived. `main` says plainly that only the isolate
  /// is known.
  static String _streamName(TomRemoteLogMessage m) =>
      m.sender.isEmpty ? m.isolateName : '${m.sender}_${m.isolateName}';

  /// Maximum length of any single sanitized remote-log field, in UTF-16 code
  /// units.
  ///
  /// Code units rather than runes because that is the unit the cap is meant to
  /// bound — what the field costs the sink — and the unit `String.length`
  /// reports, so the value a caller measures is the value checked here.
  static const int _maxFieldLength = 8192;

  /// Appended in place of the cut text when a field exceeds [_maxFieldLength].
  ///
  /// Counted against the cap rather than added to it, so the returned field is
  /// never longer than [_maxFieldLength].
  static const String _truncationMarker = '…[truncated]';

  /// Removes control characters from an untrusted remote-log field and bounds
  /// its length.
  ///
  /// A remote log message arrives from another process and is reconstructed
  /// into this server's local log stream. Without sanitization a client could
  /// embed CR/LF to forge additional log lines (log spoofing) or ESC and other
  /// terminal control codes to inject escape sequences into a console viewing
  /// the log — CWE-117 (improper output neutralization for logs). This strips
  /// the C0 controls (`0x00`–`0x1F`, including CR/LF/TAB/ESC) and the C1
  /// controls (`0x7F`–`0x9F`), and caps the field at [_maxFieldLength] so a
  /// single oversized field cannot exhaust the sink.
  ///
  /// A capped field ends in [_truncationMarker]: a silently shortened record
  /// reads as a complete one that happens to end where it does, and the reader
  /// has no way to tell a client that sent 8 KB from one that sent 8 MB. Only
  /// length truncation is marked — dropping a control character neutralizes
  /// the field without shortening what it says.
  ///
  /// Iteration is by rune so a surrogate pair is never split, but each rune's
  /// width is added to the running total *before* it is written, so the cap
  /// cannot be overshot by the second half of an astral character. Runes are
  /// buffered in two parts: [head] holds what still fits once the marker is
  /// reserved, [tail] the rest, which is kept only if the input ends before
  /// anything has to be cut.
  static String _sanitize(String value) {
    final head = StringBuffer();
    final tail = StringBuffer();
    final headLimit = _maxFieldLength - _truncationMarker.length;
    var length = 0;
    for (final rune in value.runes) {
      if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
        continue; // drop the control character
      }
      final width = rune > 0xFFFF ? 2 : 1;
      if (length + width > _maxFieldLength) {
        // Stop reading here: the rest of a hostile field must not be walked,
        // let alone materialized.
        return '$head$_truncationMarker';
      }
      (length + width <= headLimit ? head : tail).writeCharCode(rune);
      length += width;
    }
    return '$head$tail';
  }
}
