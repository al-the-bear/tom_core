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
/// the round-trip runs and is asserted. Change it there and copy it out: this
/// documentation previously showed `TomRemoteLogMessage.fromJson` and
/// `result.toJson()`, neither of which exists.
///
/// See also:
/// - [TomRemoteLogOutput] for the client-side implementation
/// - [TomRemoteLogMessage] for the message format
library;

// =============================================================================
// Imports
// =============================================================================

import 'package:tom_basics/tom_basics.dart';
import 'package:tom_core_kernel/src/tombase/logging/remote_logoutput.dart';
import 'package:tom_core_kernel/src/tombase/observable/tom_observable_objects.dart';

// =============================================================================
// Remote Log Server
// =============================================================================

/// Server-side handler for receiving remote log messages.
///
/// This class processes incoming [TomRemoteLogMessage] objects from clients
/// and outputs them through the configured [localOutput].
///
/// ## Configuration
///
/// Set [localOutput] to control where received logs are written:
///
/// ```dart
/// // Write to console (default)
/// TomRemoteLogServer.localOutput = TomConsoleLogOutput();
///
/// // Write to file
/// TomRemoteLogServer.localOutput = FileLogOutput('/var/log/app.log');
///
/// // Chain to multiple outputs
/// TomRemoteLogServer.localOutput = MultiLogOutput([
///   TomConsoleLogOutput(),
///   FileLogOutput('/var/log/app.log'),
/// ]);
/// ```
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
/// ## Refusals
///
/// A record can be refused for two independent reasons — the message is
/// undecodable, or [localOutput] is broken. [receive] names which in the
/// [TomRemoteLogResult] it returns *and* logs it locally at error level; see
/// [receive] for why both are needed and why the local half ignores the
/// sender's own logger level.
@tomReflector
class TomRemoteLogServer {
  /// The output destination for received log messages.
  ///
  /// Defaults to the current [tomLog.logOutput] at initialization time.
  static TomLogOutput localOutput = tomLog.logOutput;

  /// Processes an incoming remote log message.
  ///
  /// Reconstructs the log entry from [m] and outputs it through [localOutput].
  /// The isolate name is prefixed with the sender ID for identification.
  ///
  /// Returns a [TomRemoteLogResult] indicating success or failure. On failure
  /// the caught error is folded into [TomRemoteLogResult.errorMessage] and the
  /// refusal is recorded locally by [_reportRefusal]. Two independent things
  /// can fail here — the message can be undecodable (a malformed
  /// [TomRemoteLogMessage.timeStamp]) or [localOutput] can be broken — and the
  /// caller is a remote process with nothing else to inspect, so a generic
  /// "failed" tells it neither what went wrong nor whether retrying could
  /// help.
  TomRemoteLogResult receive(TomRemoteLogMessage m) {
    try {
      final origin = m.origin;
      localOutput.output(
        TomLogLevel(m.loggerLevel),
        TomLogLevel(m.logLevel),
        _sanitize(m.level),
        _sanitize('${m.message}'),
        _sanitize("${m.sender}_${m.isolateName}"),
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
      localOutput.output(
        TomLogLevel.errors,
        TomLogLevel.error,
        TomLogger.ERROR,
        'Refused remote log record: $reason',
        _sanitize("${m.sender}_${m.isolateName}"),
        DateTime.now(),
        'TomRemoteLogServer.receive',
      );
    } catch (_) {
      // A broken [localOutput] is one of the two causes this method exists to
      // report, so the sink may well fail again here. There is no second sink
      // to fall back to — `tomLog.logOutput` is routinely the same object.
      // Rethrowing would escape `receive`'s catch and take down the
      // collector's HTTP handler on input a remote client controls, which is
      // strictly worse than a lost diagnostic. The cause still reaches that
      // client in the returned `errorMessage`.
    }
  }

  /// Maximum length of any single sanitized remote-log field.
  static const int _maxFieldLength = 8192;

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
  static String _sanitize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
        continue; // drop the control character
      }
      buffer.writeCharCode(rune);
      if (buffer.length >= _maxFieldLength) break;
    }
    return buffer.toString();
  }
}
