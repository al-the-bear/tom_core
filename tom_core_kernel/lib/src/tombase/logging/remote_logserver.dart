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
/// // The endpoint expects TomRemoteLogMessage and returns TomRemoteLogResult
/// router.post('/remotelog', (request) async {
///   final message = TomRemoteLogMessage.fromJson(await request.json);
///   final result = logServer.receive(message);
///   return Response.ok(result.toJson());
/// });
/// ```
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
  /// Returns a [TomRemoteLogResult] indicating success or failure.
  TomRemoteLogResult receive(TomRemoteLogMessage m) {
    try {
      localOutput.output(
        TomLogLevel(m.loggerLevel),
        TomLogLevel(m.logLevel),
        m.level,
        m.message,
        "${m.sender}_${m.isolateName}",
        DateTime.parse(m.timeStamp),
        m.origin,
      );
      return TomRemoteLogResult();
    } catch (error) {
      return TomRemoteLogResult.withError(
        "Failed to log message on server side",
      );
    }
  }
}
