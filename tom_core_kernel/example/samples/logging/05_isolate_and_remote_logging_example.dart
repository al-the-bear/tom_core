/// Demonstrates the logging submodule's distinctive feature: routing log
/// records **off the current isolate** — either to a centralized remote server
/// or to a dedicated background logging isolate.
///
/// Unlike the basic-logging examples (01–04), which exercise `TomLogger`
/// behaviour that lives in `tom_basics`, this example wires the types that are
/// actually defined in `tom_core_kernel`'s `logging` submodule:
///
/// - [TomRemoteLogOutput] → [TomRemoteLogServer] — ship log records to a remote
///   collector over an HTTP endpoint, with a local fallback when none is
///   configured.
/// - [TomIsolateLogging.startIsolatedLogging] / [TomCreatorLogOutput] — offload
///   log processing to a background isolate so the main isolate stays
///   responsive, and route worker-isolate logs back to the creator.
///
/// The remote round-trip ([run]) is deterministic and assertion-backed, so it
/// participates in the aggregate sample runner. The isolate demonstration spawns
/// a real background isolate and is therefore exposed through the standalone
/// [main] only (see the file-level note on the runner below).
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// REMOTE LOGGING ROUND-TRIP (deterministic; runs in the aggregate runner)
// =============================================================================

/// Captures log records instead of writing them, so the example can assert on
/// what a configured output actually received.
class _CapturingLogOutput extends TomLogOutput {
  String? lastMessage;
  String? lastIsolateName;

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
    lastMessage = convertToString(message);
    lastIsolateName = isolateName;
  }
}

/// Demonstrates the remote-logging round-trip entirely in-process.
///
/// A client builds the same [TomRemoteLogMessage] that [TomRemoteLogOutput]
/// would transmit, the server [TomRemoteLogServer.receive]s it, and the record
/// surfaces through the server's configured local output — prefixed with the
/// client's sender id so the origin is identifiable.
void run() {
  print('1. Remote logging — client message received and re-emitted by server:');

  // --- Server side: capture what the collector writes locally. ---------------
  final serverOutput = _CapturingLogOutput();
  final originalLocal = TomRemoteLogServer.localOutput;
  TomRemoteLogServer.localOutput = serverOutput;
  final server = TomRemoteLogServer();

  // --- Client side: identify this client and build a record to transmit. -----
  final originalSenderId = TomRemoteLogMessage.globalSettingSenderId;
  TomRemoteLogMessage.globalSettingSenderId = 'client-001';
  final clientMessage = TomRemoteLogMessage.of(
    TomLogLevel.production.levelPattern,
    TomLogLevel.info.levelPattern,
    'INFO   ',
    'Order 4711 processed',
    'worker-1',
    DateTime(2026, 1, 2, 9, 30).toIso8601String(),
    'OrderService.process',
  );

  final result = server.receive(clientMessage);

  print('   sender prefix : ${serverOutput.lastIsolateName}');
  print('   message       : ${serverOutput.lastMessage}');
  print('   result.hasError: ${result.hasError}\n');

  // --- Client fallback: with no endpoint configured, records stay local. -----
  print('2. Remote logging — falls back locally when no endpoint is configured:');
  final fallbackOutput = _CapturingLogOutput();
  final originalFallback = TomRemoteLogOutput.globalSettingFallbackOutput;
  TomRemoteLogOutput.globalSettingFallbackOutput = fallbackOutput;
  TomRemoteLogOutput.remoteEndpoint = null;

  TomRemoteLogOutput().output(
    TomLogLevel.production,
    TomLogLevel.info,
    'INFO   ',
    'no endpoint configured',
    'main',
    DateTime(2026, 1, 2, 9, 31),
    null,
  );

  print('   fallback message: ${fallbackOutput.lastMessage}\n');

  // --- Assertions ------------------------------------------------------------
  assert(!result.hasError);
  assert(serverOutput.lastMessage == 'Order 4711 processed');
  // receive() prefixes the isolate name with the sender id.
  assert(serverOutput.lastIsolateName == 'client-001_worker-1');
  assert(fallbackOutput.lastMessage == 'no endpoint configured');

  // --- Restore shared statics ------------------------------------------------
  TomRemoteLogServer.localOutput = originalLocal;
  TomRemoteLogMessage.globalSettingSenderId = originalSenderId;
  TomRemoteLogOutput.globalSettingFallbackOutput = originalFallback;
}

// =============================================================================
// ISOLATE LOGGING (spawns a real isolate; standalone main only)
// =============================================================================

/// Demonstrates offloading log processing to a dedicated background isolate.
///
/// [TomIsolateLogging.startIsolatedLogging] installs a [TomIsolateLogOutput]
/// that routes every record to a worker pool, so formatting and I/O happen off
/// the main isolate. Worker isolates, in turn, call
/// [TomIsolateLogging.startLoggingToCreator] to install a [TomCreatorLogOutput]
/// that ships their records back to the creator for centralized handling.
Future<void> runIsolateLoggingDemo(List<String> args) async {
  print('3. Isolate logging — routing records through a background isolate:');

  final originalOutput = tomLog.logOutput;

  // Main isolate: send all logging to a one-worker logging pool. Supplying an
  // explicit worker context (built from barrel-exported consts) means the demo
  // needs no `TomRuntime` platform initialization to spawn the isolate.
  await TomIsolateLogging.startIsolatedLogging(
    args,
    poolSize: 1,
    workerContext: TomLoggingWorkerContext(
      defaultTomEnvironment,
      platformLinux,
      args,
      'L',
    ),
  );
  print('   logOutput is now: ${tomLog.logOutput.runtimeType}');

  tomLog.info('Processed asynchronously in the logging isolate');
  tomLog.warn('The main isolate stays responsive while logs are handled');

  // Let the asynchronous routing drain before tearing the pool down.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  final isolateOutput = tomLog.logOutput;
  if (isolateOutput is TomIsolateLogOutput) {
    isolateOutput.workerPool.close();
  }
  tomLog.logOutput = originalOutput;

  print('   (worker isolates would call '
      'TomIsolateLogging.startLoggingToCreator() to route their logs back)\n');
}

/// Standalone entry point.
///
/// Runs the deterministic remote round-trip, then demonstrates isolate logging.
/// The isolate demo supplies its own worker context, so no `TomRuntime`
/// platform initialization is required here.
Future<void> main(List<String> args) async {
  print('=== 05: Isolate and Remote Logging Example ===\n');
  run();
  await runIsolateLoggingDemo(args);
  print('All isolate/remote logging demonstrations completed.');
}
