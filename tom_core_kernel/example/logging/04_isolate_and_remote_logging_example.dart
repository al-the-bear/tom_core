/// Demonstrates the kernel-owned isolate and remote logging surface.
///
/// The first three logging examples (`01`–`03`) cover the `tom_basics`
/// `TomLogger` / `TomLogLevel` foundation. This example covers the types the
/// `tom_core_kernel` logging module *adds* on top of that foundation — the
/// machinery that funnels log output from worker isolates and remote clients
/// into one coherent stream:
///
/// - [TomInterIsolateLogMessage] — the record passed between isolates.
/// - [TomLoggingExecutor] — the logging-isolate handler that replays a record
///   into the local [TomLogOutput].
/// - [TomIsolateLogOutput] / [TomCreatorLogOutput] — the worker-side and
///   creator-side sinks (with level gating and creator fallback).
/// - [TomLoggingWorkerContext] / [TomIsolateLogging] — the setup entry points.
/// - [TomRemoteLogMessage] / [TomRemoteLogResult] / [TomLoggingContext] — the
///   remote-logging wire payloads and re-entrancy context.
/// - [TomRemoteLogOutput] / [TomRemoteLogServer] — the client that ships logs
///   to a server and the server that receives and replays them.
///
/// Every sink here is exercised connection-free: worker pools are created at
/// size zero (which spawn no isolates) and the remote path is driven with its
/// endpoint left unset so it takes the local fallback. This keeps the example
/// deterministic and fast while still touching the real public API.
///
/// Run with:
/// ```bash
/// dart run --enable-asserts example/logging/04_isolate_and_remote_logging_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Capturing log sink used to observe what the isolate/remote outputs emit.
///
/// Mirrors the level gate of the real outputs: it only records a call whose
/// [logLevel] matches the active [loggerLevel], exactly as a live sink would.
class _CapturingOutput extends TomLogOutput {
  String? lastMessage;
  String? lastLevel;
  String? lastIsolateName;
  String? lastOrigin;
  int outputCount = 0;

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
      outputCount++;
      lastLevel = level;
      lastMessage = convertToString(message);
      lastIsolateName = isolateName;
      lastOrigin = origin;
    }
  }
}

/// Builds a logging worker context for zero-size pools (spawns no isolates).
///
/// Uses literal environment / platform values so the example does not depend on
/// the global [TomRuntime] singleton being initialised; a zero-size pool never
/// actually consumes the context.
TomLoggingWorkerContext _emptyLoggingContext() {
  return TomLoggingWorkerContext(
    const TomEnvironment('example', isTest: true),
    platformWeb,
    const <String>[],
    'L',
  );
}

Future<void> run() async {
  print('=== 04: Isolate and Remote Logging Example ===\n');

  final fixedTime = DateTime(2026, 1, 2, 9, 30, 0);

  // ===========================================================================
  // Example 1: TomInterIsolateLogMessage — the cross-isolate record
  // ===========================================================================

  print('1. TomInterIsolateLogMessage (the record passed between isolates):');

  final record = TomInterIsolateLogMessage(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'worker started',
    'worker-1',
    fixedTime,
    'App.boot',
  );

  print('   isolateName: ${record.isolateName}');
  print('   level:       "${record.level}"');
  print('   message:     ${record.message}');
  print('   origin:      ${record.origin}');
  print('   toString():  ${record.toString()}');
  print('');

  // ===========================================================================
  // Example 2: TomLoggingExecutor — replay a record into the local output
  // ===========================================================================

  print('2. TomLoggingExecutor (logging-isolate handler):');

  final originalOutput = tomLog.logOutput;
  final executorSink = _CapturingOutput();
  tomLog.logOutput = executorSink;

  final executor = TomLoggingExecutor();
  final handled = executor.execute(record);
  final ignoredString = executor.execute('not a log record');
  final ignoredInt = executor.execute(42);

  tomLog.logOutput = originalOutput;

  print('   execute(record)         -> $handled (routed to local output)');
  print('   captured message        -> ${executorSink.lastMessage}');
  print('   execute("...")          -> $ignoredString (TomExecutor.noResult)');
  print('   execute(42)             -> $ignoredInt (TomExecutor.noResult)');
  print('');

  // ===========================================================================
  // Example 3: TomIsolateLogOutput — worker-side pooled sink (level gating)
  // ===========================================================================

  print('3. TomIsolateLogOutput (routes to a worker pool; gated by level):');

  // A zero-size pool spawns no isolates, so it is safe here while still
  // exercising the real constructor and field wiring.
  final pool = await TomWorkerPool.withSize(0, _emptyLoggingContext());
  final isolateOutput = TomIsolateLogOutput(pool);
  final poolIsWired = identical(isolateOutput.workerPool, pool);

  print('   workerPool wired?        $poolIsWired');

  // trace does not match a production logger level, so the gate short-circuits
  // BEFORE touching the (blocking, zero-size) pool — it returns immediately.
  var gatedOutReturned = true;
  isolateOutput.output(
    TomLogLevel.production,
    TomLogLevel.trace,
    TomLogger.TRACE,
    'gated out — never reaches the pool',
    'worker-1',
    fixedTime,
    null,
  );
  print('   gated-out output returned without blocking? $gatedOutReturned');
  print('');

  // ===========================================================================
  // Example 4: TomCreatorLogOutput — creator-side sink with fallback
  // ===========================================================================

  print('4. TomCreatorLogOutput (worker→creator; falls back off-isolate):');

  final originalCreatorFallback = TomCreatorLogOutput.fallbackOutput;
  final creatorFallback = _CapturingConsoleOutput();
  TomCreatorLogOutput.fallbackOutput = creatorFallback;

  final creatorOutput = TomCreatorLogOutput();
  // In the main isolate there is no creator to send to, so the output routes to
  // its fallback sink instead.
  creatorOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'creator message',
    'main',
    fixedTime,
    null,
  );
  final creatorFallbackMessage = creatorFallback.lastMessage;

  // A gated-out level is dropped before the fallback is even consulted.
  creatorFallback.lastMessage = null;
  creatorOutput.output(
    TomLogLevel.production,
    TomLogLevel.trace,
    TomLogger.TRACE,
    'gated out',
    'main',
    fixedTime,
    null,
  );
  final creatorGatedMessage = creatorFallback.lastMessage;

  TomCreatorLogOutput.fallbackOutput = originalCreatorFallback;

  print('   off-isolate message ->  fallback captured: $creatorFallbackMessage');
  print('   gated-out message   ->  fallback captured: $creatorGatedMessage');
  print('');

  // ===========================================================================
  // Example 5: TomLoggingWorkerContext / TomIsolateLogging setup entry points
  // ===========================================================================

  print('5. Setup entry points:');

  final context = _emptyLoggingContext();
  // A logging worker context IS a worker context (it extends TomWorkerContext),
  // so a runtime instance check confirms the inheritance the pool relies on.
  final contextIsWorkerContext = (context as Object) is TomWorkerContext;
  print('   TomLoggingWorkerContext is a TomWorkerContext? '
      '$contextIsWorkerContext');

  // startLoggingToCreator swaps the global output to a creator-routing sink.
  final beforeSwap = tomLog.logOutput;
  TomIsolateLogging.startLoggingToCreator();
  final swappedToCreator = tomLog.logOutput is TomCreatorLogOutput;
  tomLog.logOutput = beforeSwap; // restore
  print('   startLoggingToCreator installs TomCreatorLogOutput? '
      '$swappedToCreator');
  print('   (startIsolatedLogging spawns a real logging pool — shown in tests)');
  print('');

  // ===========================================================================
  // Example 6: Remote payloads — TomRemoteLogMessage / Result / Context
  // ===========================================================================

  print('6. Remote-logging payloads:');

  final emptyRemote = TomRemoteLogMessage();
  final originalSenderId = TomRemoteLogMessage.globalSettingSenderId;
  TomRemoteLogMessage.globalSettingSenderId = 'edge-node-7';
  final remoteMessage = TomRemoteLogMessage.of(
    TomLogLevel.production.levelPattern,
    TomLogLevel.info.levelPattern,
    TomLogger.INFO,
    'remote hello',
    'main',
    fixedTime.toIso8601String(),
    'App.ping',
  );
  TomRemoteLogMessage.globalSettingSenderId = originalSenderId;

  print('   default sender:         "${emptyRemote.sender}"');
  print('   configured sender:      ${remoteMessage.sender}');
  print('   message.toString():     ${remoteMessage.toString()}');

  final okResult = TomRemoteLogResult();
  final errResult = TomRemoteLogResult.withError('sink unavailable');
  print('   ok result   -> hasError=${okResult.hasError}');
  print('   err result  -> hasError=${errResult.hasError} '
      '"${errResult.errorMessage}"');

  final ctx = TomLoggingContext(inRemoteLogging: true);
  print('   TomLoggingContext.inRemoteLogging: ${ctx.inRemoteLogging}');
  print('');

  // ===========================================================================
  // Example 7: TomRemoteLogOutput — client falls back when no endpoint
  // ===========================================================================

  print('7. TomRemoteLogOutput (client; falls back with no endpoint):');

  final originalRemoteFallback = TomRemoteLogOutput.globalSettingFallbackOutput;
  final remoteFallback = _CapturingOutput();
  TomRemoteLogOutput.globalSettingFallbackOutput = remoteFallback;
  TomRemoteLogOutput.remoteEndpoint = null;

  final remoteOutput = TomRemoteLogOutput();
  remoteOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'no endpoint configured',
    'main',
    fixedTime,
    null,
  );
  final remoteFallbackMessage = remoteFallback.lastMessage;

  TomRemoteLogOutput.globalSettingFallbackOutput = originalRemoteFallback;

  print('   endpoint unset -> fallback captured: $remoteFallbackMessage');
  print('');

  // ===========================================================================
  // Example 8: TomRemoteLogServer — receive, replay, and sanitize
  // ===========================================================================

  print('8. TomRemoteLogServer (receives remote records, sanitizes them):');

  final originalServerOutput = TomRemoteLogServer.localOutput;
  final serverSink = _CapturingOutput();
  TomRemoteLogServer.localOutput = serverSink;

  final server = TomRemoteLogServer();
  final cleanMessage = TomRemoteLogMessage.of(
    TomLogLevel.production.levelPattern,
    TomLogLevel.info.levelPattern,
    TomLogger.INFO,
    'from a remote client',
    'worker-2',
    fixedTime.toIso8601String(),
    'Remote.emit',
  );
  cleanMessage.sender = 'client-42';
  final cleanResult = server.receive(cleanMessage);
  final serverIsolateName = serverSink.lastIsolateName;

  // A hostile client can embed CR/LF/ESC to forge log lines or inject terminal
  // escapes (CWE-117). The server strips control characters before replay.
  final hostileMessage = TomRemoteLogMessage.of(
    TomLogLevel.production.levelPattern,
    TomLogLevel.info.levelPattern,
    TomLogger.INFO,
    'line one\r\nFORGED INFO injected',
    'main',
    fixedTime.toIso8601String(),
    null,
  );
  final hostileResult = server.receive(hostileMessage);
  final sanitizedMessage = serverSink.lastMessage;

  TomRemoteLogServer.localOutput = originalServerOutput;

  print('   receive(clean)  -> hasError=${cleanResult.hasError}, '
      'isolate="$serverIsolateName" (sender prefixed)');
  print('   receive(hostile)-> hasError=${hostileResult.hasError}, '
      'sanitized="$sanitizedMessage"');
  print('');

  // ===========================================================================
  // Assertions (run under --enable-asserts)
  // ===========================================================================

  // Example 1: inter-isolate record
  assert(record.isolateName == 'worker-1');
  assert(record.level == TomLogger.INFO);
  assert(record.message == 'worker started');
  assert(record.origin == 'App.boot');
  assert(record.toString() == 'TomInterIsolateLogMessage worker-1 INFO    worker started');

  // Example 2: executor
  assert(handled == true);
  assert(executorSink.lastMessage == 'worker started');
  assert(executorSink.lastIsolateName == 'worker-1');
  assert(ignoredString == TomExecutor.noResult);
  assert(ignoredInt == TomExecutor.noResult);

  // Example 3: isolate output — pool wired, gated-out returns without blocking
  assert(poolIsWired);
  assert(gatedOutReturned);

  // Example 4: creator output — fallback off-isolate, gated-out dropped
  assert(creatorFallbackMessage == 'creator message');
  assert(creatorGatedMessage == null);

  // Example 5: setup entry points
  assert(contextIsWorkerContext);
  assert(swappedToCreator);

  // Example 6: remote payloads
  assert(emptyRemote.sender == '');
  assert(remoteMessage.sender == 'edge-node-7');
  assert(remoteMessage.message == 'remote hello');
  assert(remoteMessage.origin == 'App.ping');
  assert(remoteMessage.toString() == 'TomRemoteLogMessage main INFO    remote hello');
  assert(okResult.hasError == false);
  assert(errResult.hasError == true);
  assert(errResult.errorMessage == 'sink unavailable');
  assert(ctx.inRemoteLogging == true);

  // Example 7: remote output falls back with no endpoint
  assert(remoteFallbackMessage == 'no endpoint configured');

  // Example 8: server receives, prefixes sender, sanitizes control chars
  assert(cleanResult.hasError == false);
  assert(serverIsolateName == 'client-42_worker-2');
  assert(hostileResult.hasError == false);
  assert(sanitizedMessage == 'line oneFORGED INFO injected');
  assert(sanitizedMessage != null && !sanitizedMessage.contains('\r'));
  assert(sanitizedMessage != null && !sanitizedMessage.contains('\n'));
}

/// Console-typed capturing sink for slots statically typed
/// [TomConsoleLogOutput] (e.g. [TomCreatorLogOutput.fallbackOutput]).
class _CapturingConsoleOutput extends TomConsoleLogOutput {
  String? lastMessage;

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
      lastMessage = convertToString(message);
    }
  }
}

Future<void> main() async {
  await run();
}
