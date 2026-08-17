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
/// - [TomLogReplayStore] / [TomInMemoryLogReplayStore] /
///   [TomFileLogReplayStore] — the pluggable replay-queue backend (in-memory by
///   default, or file-backed to survive a restart during an outage).
///
/// Every sink here is exercised connection-free: worker pools are created at
/// size zero (which spawn no isolates) and the remote path is driven with its
/// endpoint left unset so it takes the local fallback. This keeps the example
/// deterministic and fast while still touching the real public API.
///
/// Run with:
/// ```bash
/// dart run --enable-asserts example/samples/logging/06_log_replay_and_isolate_plumbing_example.dart
/// ```
library;

import 'dart:async';
import 'dart:io';

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

  // A pool needs at least one worker, so this sample builds a real one and
  // closes it again: a closed pool refuses dispatch, which is what makes the
  // level gate below observable at all.
  final pool = await TomWorkerPool.withSize(1, _emptyLoggingContext());
  pool.close();
  final isolateOutput = TomIsolateLogOutput(pool);
  final poolIsWired = identical(isolateOutput.workerPool, pool);

  print('   workerPool wired?        $poolIsWired');

  // output() never awaits its pooled delivery, so it always returns normally.
  // Watching the zone for the closed pool's refusal is what actually shows
  // whether a line reached the pool: trace does not match a production logger
  // level, so the gate short-circuits and nothing is dispatched.
  final escaped = <Object>[];
  runZonedGuarded(() {
    isolateOutput.output(
      TomLogLevel.production,
      TomLogLevel.trace,
      TomLogger.TRACE,
      'gated out — never reaches the pool',
      'worker-1',
      fixedTime,
      null,
    );
  }, (e, _) => escaped.add(e));
  await Future<void>.delayed(Duration(milliseconds: 50));

  final gatedOutStayedOffThePool = escaped.isEmpty;
  print('   gated-out line stayed off the pool? $gatedOutStayedOffThePool');
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
  // Example 9: TomRemoteLogOutput resilience — retry + bounded replay queue
  // ===========================================================================

  print('9. TomRemoteLogOutput resilience (retry + replay queue):');

  final resilienceFallback = _CapturingOutput();
  TomRemoteLogOutput.globalSettingFallbackOutput = resilienceFallback;
  TomRemoteLogOutput.globalSettingMaxSendRetries = 3;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 4;
  TomRemoteLogOutput.clearReplayQueue();

  final resilientOutput = TomRemoteLogOutput();

  // 9a: a flaky endpoint fails twice, then the retry recovers — no data loss,
  // no fallback needed.
  final flaky = _ScriptedLogEndpoint([
    _SendOutcome.throwError,
    _SendOutcome.throwError,
    _SendOutcome.ok,
  ]);
  TomRemoteLogOutput.remoteEndpoint = flaky;
  resilientOutput.output(TomLogLevel.production, TomLogLevel.info,
      TomLogger.INFO, 'recovered by retry', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  final retriedSends = flaky.sendCount;
  final retriedAccepted = flaky.accepted.map((m) => m.message).toList();

  // 9b: the endpoint is fully down — the record is buffered for replay (and
  // still surfaced locally so nothing is lost).
  final down = _ScriptedLogEndpoint([_SendOutcome.throwError]);
  TomRemoteLogOutput.remoteEndpoint = down;
  resilientOutput.output(TomLogLevel.production, TomLogLevel.info,
      TomLogger.INFO, 'buffered while down', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  final queuedAfterOutage = TomRemoteLogOutput.replayQueueLength;

  // 9c: the endpoint recovers — the next record drains the buffer oldest-first
  // before sending itself, so ordering is preserved across the outage.
  final recovered = _ScriptedLogEndpoint([_SendOutcome.ok]);
  TomRemoteLogOutput.remoteEndpoint = recovered;
  resilientOutput.output(TomLogLevel.production, TomLogLevel.info,
      TomLogger.INFO, 'flush trigger', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  final drainedAccepted = recovered.accepted.map((m) => m.message).toList();
  final queueAfterDrain = TomRemoteLogOutput.replayQueueLength;

  // Restore defaults so the example leaves no global state behind.
  TomRemoteLogOutput.globalSettingFallbackOutput = originalRemoteFallback;
  TomRemoteLogOutput.remoteEndpoint = null;
  TomRemoteLogOutput.globalSettingMaxSendRetries = 0;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
  TomRemoteLogOutput.clearReplayQueue();

  print('   9a retry: $retriedSends sends, accepted=$retriedAccepted');
  print('   9b outage: queued=$queuedAfterOutage record(s)');
  print('   9c drain:  accepted=$drainedAccepted, queue now $queueAfterDrain');
  print('');

  // ===========================================================================
  // Example 10: Durable replay store — buffered records survive a restart
  // ===========================================================================

  print('10. Durable replay store (records survive a process restart):');

  // The replay queue's storage is pluggable. The default keeps records in
  // memory (lost if the process exits mid-outage); a file-backed store mirrors
  // them to disk so a fresh process resumes with the buffered records.
  final storeDir =
      Directory.systemTemp.createTempSync('tom_core_kernel_replay_');
  final storePath = '${storeDir.path}/replay_queue.json';

  final durableFallback = _CapturingOutput();
  TomRemoteLogOutput.globalSettingFallbackOutput = durableFallback;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 4;

  // 10a: first process — endpoint is down, so records buffer to disk.
  TomRemoteLogOutput.globalSettingReplayStore =
      TomFileLogReplayStore(storePath);
  TomRemoteLogOutput.remoteEndpoint =
      _ScriptedLogEndpoint([_SendOutcome.throwError]);
  final firstProcess = TomRemoteLogOutput();
  firstProcess.output(TomLogLevel.production, TomLogLevel.info, TomLogger.INFO,
      'queued before restart A', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  firstProcess.output(TomLogLevel.production, TomLogLevel.info, TomLogger.INFO,
      'queued before restart B', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  final bufferedBeforeRestart = TomRemoteLogOutput.replayQueueLength;

  // 10b: simulate a restart — a brand-new store instance at the same path
  // reloads what the "previous process" buffered.
  TomRemoteLogOutput.globalSettingReplayStore =
      TomFileLogReplayStore(storePath);
  final reloadedAfterRestart = TomRemoteLogOutput.replayQueueLength;

  // 10c: the endpoint recovers — the reloaded records drain oldest-first.
  final durableRecovered = _ScriptedLogEndpoint([_SendOutcome.ok]);
  TomRemoteLogOutput.remoteEndpoint = durableRecovered;
  final secondProcess = TomRemoteLogOutput();
  secondProcess.output(TomLogLevel.production, TomLogLevel.info, TomLogger.INFO,
      'after restart C', 'main', fixedTime, null);
  await Future<void>.delayed(Duration.zero);
  final durableDrained =
      durableRecovered.accepted.map((m) => m.message).toList();
  final durableQueueAfter = TomRemoteLogOutput.replayQueueLength;

  // Restore defaults (back to the zero-config in-memory store) and clean up.
  TomRemoteLogOutput.globalSettingFallbackOutput = originalRemoteFallback;
  TomRemoteLogOutput.remoteEndpoint = null;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
  TomRemoteLogOutput.globalSettingReplayStore = TomInMemoryLogReplayStore();
  TomRemoteLogOutput.clearReplayQueue();
  storeDir.deleteSync(recursive: true);

  print('   10a before restart: buffered=$bufferedBeforeRestart to disk');
  print('   10b after restart:  reloaded=$reloadedAfterRestart from disk');
  print('   10c drain:          accepted=$durableDrained, '
      'queue now $durableQueueAfter');
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

  // Example 3: isolate output — pool wired, gated-out line never dispatched
  assert(poolIsWired);
  assert(gatedOutStayedOffThePool);

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

  // Example 9: retry recovers, outage buffers, recovery drains in order
  assert(retriedSends == 3); // two failures + one success
  assert(retriedAccepted.length == 1 && retriedAccepted.first == 'recovered by retry');
  assert(queuedAfterOutage == 1); // record buffered while endpoint down
  // The buffered record drains before the trigger, preserving order.
  assert(drainedAccepted.length == 2);
  assert(drainedAccepted[0] == 'buffered while down');
  assert(drainedAccepted[1] == 'flush trigger');
  assert(queueAfterDrain == 0); // queue fully drained

  // Example 10: durable store persists the queue across a simulated restart
  assert(bufferedBeforeRestart == 2); // both records buffered to disk
  assert(reloadedAfterRestart == 2); // reloaded by the fresh store instance
  assert(durableDrained.length == 3); // two reloaded + the trigger record
  assert(durableDrained[0] == 'queued before restart A');
  assert(durableDrained[1] == 'queued before restart B');
  assert(durableDrained[2] == 'after restart C');
  assert(durableQueueAfter == 0); // queue fully drained after recovery
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

/// How a single scripted [_ScriptedLogEndpoint] send should behave.
enum _SendOutcome {
  /// Succeed with an empty result and no error.
  ok,

  /// Throw a transport exception (simulating an unreachable endpoint).
  throwError,
}

/// Offline remote endpoint whose per-call behaviour is scripted, used to
/// demonstrate [TomRemoteLogOutput]'s retry and replay-queue paths without a
/// live server. The channel/specs handed to `super` are never used because
/// [send] is fully overridden.
class _ScriptedLogEndpoint
    extends TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult> {
  _ScriptedLogEndpoint(this.script)
      : super(
          TomServerChannel('localhost', 80),
          TomServerCallSpecs('POST', Uri.parse('http://localhost/remotelog')),
        );

  /// Per-call outcomes; the last entry repeats once the script is exhausted.
  final List<_SendOutcome> script;

  int sendCount = 0;

  /// Records accepted by an `ok` outcome, in order — lets the example assert
  /// the exact drain/replay ordering.
  final List<TomRemoteLogMessage> accepted = [];

  @override
  Future<(TomRemoteLogResult, TomServerCallError?)> send(
    TomRemoteLogMessage load, [
    TomRemoteLogResult? responseObject,
  ]) async {
    final outcome =
        script[sendCount < script.length ? sendCount : script.length - 1];
    sendCount++;
    switch (outcome) {
      case _SendOutcome.throwError:
        throw Exception('endpoint unreachable');
      case _SendOutcome.ok:
        accepted.add(load);
        return (responseObject ?? TomRemoteLogResult(), null);
    }
  }
}

Future<void> main() async {
  await run();
}
