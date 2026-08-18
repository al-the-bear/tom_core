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
///
/// ## This file is the source of the documented setup snippets
///
/// Steps 3 and 4 below are the client-wiring and wire-format snippets that
/// `TomRemoteLogOutput`'s and `TomRemoteLogServer`'s dartdoc, and
/// `doc/logging/logging.md`, quote. They live here — compiled, analyzed and
/// asserted — rather than only in prose, because prose does not fail to build:
/// all three documented snippets once showed a `TomServerEndpoint` constructor
/// and `fromJson`/`toJson` methods that do not exist, so the module's own
/// on-ramp did not compile. Change the snippet here and copy it out, never the
/// other way round.
///
/// [CustomLoggingContext] is here for the same reason: it is the subclass
/// `TomLoggingExecutor`'s dartdoc shows for redirecting the logging isolate's
/// output, and only a compiler can confirm it forwards the constructor
/// arguments its superclass requires.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../run_all_samples.reflection.dart';

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

  // --- Client wiring: point the output at a real collector. ------------------
  //
  // This is the documented setup snippet. `TomServerEndpoint` takes a
  // *channel* (host and port) and *call specs* (method and full URL) — it has
  // no `baseUrl`/`path` constructor. Building it opens no connection: the
  // channel creates its HTTP client lazily on the first call, which is why the
  // wiring can be demonstrated here without a server to talk to.
  print('3. Remote logging — wiring the output to a collector:');

  final originalEndpoint = TomRemoteLogOutput.remoteEndpoint;
  final originalLogOutput = tomLog.logOutput;

  final channel = TomServerChannel('logs.example.com', 443);
  TomRemoteLogOutput.remoteEndpoint =
      TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>(
        channel,
        TomServerCallSpecs(
          'POST',
          Uri.parse('https://logs.example.com/api/logs'),
        ),
      );
  tomLog.logOutput = TomRemoteLogOutput();

  // Read the wiring back before restoring, so the assertions below can run
  // against a restored logger. Asserting first would leave `tomLog` pointing
  // at an endpoint nobody is listening on if one ever failed.
  final wiredUrl = TomRemoteLogOutput.remoteEndpoint!.specs.url;
  final wiredPort = TomRemoteLogOutput.remoteEndpoint!.channel.port;
  final wiredOutput = tomLog.logOutput;

  print('   endpoint : ${wiredUrl.host}:$wiredPort${wiredUrl.path}');
  print('   logOutput: ${wiredOutput.runtimeType}\n');

  channel.close();
  tomLog.logOutput = originalLogOutput;
  TomRemoteLogOutput.remoteEndpoint = originalEndpoint;

  // --- Wire format: what the collector has to read and answer with. ----------
  //
  // `TomRemoteLogMessage` and `TomRemoteLogResult` carry no `fromJson`/
  // `toJson` of their own. They are `@tomReflector` types, so serialisation
  // goes through `tomReflectionInfo` — the same route `TomServerEndpoint.send`
  // takes internally, which is what makes a server written this way agree with
  // the client by construction.
  print('4. Remote logging — the wire format a collector implements:');

  final wire = tomReflectionInfo.convertToJsonString(clientMessage);
  final received = tomReflectionInfo.convertFromJsonString(
    TomRemoteLogMessage(),
    wire,
  );
  final wireResult = server.receive(received);
  final responseBody = tomReflectionInfo.convertToJsonString(wireResult);

  print('   request  : ${wire.substring(0, 60)}…');
  print('   response : $responseBody\n');

  // --- Assertions ------------------------------------------------------------
  assert(!result.hasError);
  assert(serverOutput.lastMessage == 'Order 4711 processed');
  // receive() prefixes the isolate name with the sender id.
  assert(serverOutput.lastIsolateName == 'client-001_worker-1');
  assert(fallbackOutput.lastMessage == 'no endpoint configured');
  assert(wiredUrl.path == '/api/logs');
  assert(wiredPort == 443);
  assert(wiredOutput is TomRemoteLogOutput);
  // The decoded message is the one that was sent, and the collector handled it.
  assert(received.message == 'Order 4711 processed');
  assert(received.sender == 'client-001');
  assert(!wireResult.hasError);
  assert(responseBody.contains('"hasError":false'));

  // --- Restore shared statics ------------------------------------------------
  TomRemoteLogServer.localOutput = originalLocal;
  TomRemoteLogMessage.globalSettingSenderId = originalSenderId;
  TomRemoteLogOutput.globalSettingFallbackOutput = originalFallback;
}

// =============================================================================
// ISOLATE LOGGING (spawns a real isolate; standalone main only)
// =============================================================================

/// Worker context that replaces the logging isolate's own log output.
///
/// [initializeIsolate] runs *inside* the spawned isolate, which is the only
/// place the output can be set for the isolate that does the writing: statics
/// are per-isolate, so assigning `tomLog.logOutput` in the main isolate would
/// change the main isolate's output and leave the logging isolate's untouched.
///
/// This is the class [TomLoggingExecutor]'s dartdoc quotes. It lives here so
/// the compiler checks it — in particular that it forwards the four positional
/// arguments of [TomLoggingWorkerContext], which has no zero-argument
/// constructor for a subclass to inherit.
class CustomLoggingContext extends TomLoggingWorkerContext {
  /// Creates the context, forwarding the superclass's four arguments.
  CustomLoggingContext(
    super.tomEnvironment,
    super.tomPlatform,
    super.args,
    super.namePrefix,
  );

  @override
  Future<void> initializeIsolate() async {
    // Registers TomLoggingExecutor. Skip the super call and the isolate has no
    // handler for the records the pool sends it, and drops every one.
    await super.initializeIsolate();
    // No remoteEndpoint is configured here, so this output forwards to
    // TomRemoteLogOutput.globalSettingFallbackOutput — the console. That keeps
    // the demo server-free while still exercising the real redirect.
    tomLog.logOutput = TomRemoteLogOutput();
    print('   [logging isolate] its own logOutput is now '
        '${tomLog.logOutput.runtimeType}');
  }
}

/// Demonstrates offloading log processing to a dedicated background isolate.
///
/// [TomIsolateLogging.startIsolatedLogging] installs a [TomIsolateLogOutput]
/// that routes every record to a worker pool, so formatting and I/O happen off
/// the main isolate. Worker isolates, in turn, call
/// [TomIsolateLogging.startLoggingToCreator] to install a [TomCreatorLogOutput]
/// that ships their records back to the creator for centralized handling.
///
/// The pool is given a [CustomLoggingContext], so this also demonstrates
/// replacing the logging isolate's own output during its initialization.
Future<void> runIsolateLoggingDemo(List<String> args) async {
  print('5. Isolate logging — routing records through a background isolate:');

  final originalOutput = tomLog.logOutput;

  // Main isolate: send all logging to a one-worker logging pool. Supplying an
  // explicit worker context (built from barrel-exported consts) means the demo
  // needs no `TomRuntime` platform initialization to spawn the isolate. An
  // application would normally pass TomRuntime.getCurrentEnvironment() and
  // TomRuntime.getCurrentPlatform()!, which is what the default context uses.
  await TomIsolateLogging.startIsolatedLogging(
    args,
    poolSize: 1,
    workerContext: CustomLoggingContext(
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
///
/// Reflection *is* initialized: step 4 serialises through `tomReflectionInfo`,
/// and without the generated registrations it would have no mirror for
/// [TomRemoteLogMessage]. The aggregate runner does this for its own path, so
/// this call is what makes the file runnable on its own.
Future<void> main(List<String> args) async {
  print('=== 05: Isolate and Remote Logging Example ===\n');
  initializeReflection();
  run();
  await runIsolateLoggingDemo(args);
  print('All isolate/remote logging demonstrations completed.');
}
