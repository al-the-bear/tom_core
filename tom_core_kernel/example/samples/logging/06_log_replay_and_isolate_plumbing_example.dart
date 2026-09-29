/// Demonstrates the kernel-owned isolate and remote logging surface.
///
/// The first four logging examples (`01`–`04`) cover the `tom_basics`
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
/// Every sink here is exercised connection-free: the single worker pool is
/// closed before anything is dispatched to it, and the remote path runs either
/// with no endpoint set (so it takes the local fallback) or against a scripted
/// stand-in that answers in memory. This keeps the example deterministic and
/// fast while still touching the real public API.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/logging/06_log_replay_and_isolate_plumbing_example.dart
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

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

  /// Every captured line in order. A failed remote send writes two — the
  /// warning that says why, then the record itself — so [lastMessage] alone
  /// cannot show the reason the send failed.
  final List<String> messages = [];

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
      messages.add(lastMessage!);
    }
  }
}

/// Builds the logging worker context used to spawn the pool and to demonstrate
/// the isolate-side setup hook.
///
/// Uses literal environment / platform values so the example does not depend on
/// the global [TomRuntime] singleton being initialised.
TomLoggingWorkerContext _emptyLoggingContext() {
  return SampleLoggingWorkerContext(
    const TomEnvironment('example', isTest: true),
    platformWeb,
    const <String>[],
    'L',
  );
}

Future<void> run() async {
  print('=== 06: Log Replay and Isolate Plumbing Example ===\n');

  final fixedTime = DateTime(2026, 1, 2, 9, 30, 0);

  // ===========================================================================
  // Example 1: TomInterIsolateLogMessage — the cross-isolate record
  // ===========================================================================

  print('1. TomInterIsolateLogMessage (the record passed between isolates):');

  final record = TomInterIsolateLogMessage(
    loggerLevel: TomLogLevel.production,
    logLevel: TomLogLevel.info,
    level: TomLogger.INFO,
    message: 'worker started',
    isolateName: 'worker-1',
    timeStamp: fixedTime,
    origin: 'App.boot',
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
  // Any TomLogOutput can stand in here — the slot is the interface, not the
  // console class — so this reuses the same capture the other examples use.
  final creatorFallback = _CapturingOutput();
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

  print(
    '   off-isolate message ->  fallback captured: $creatorFallbackMessage',
  );
  print('   gated-out message   ->  fallback captured: $creatorGatedMessage');
  print('');

  // ===========================================================================
  // Example 5: TomLoggingWorkerContext / TomIsolateLogging setup entry points
  // ===========================================================================

  print('5. Setup entry points:');

  final context = _emptyLoggingContext();

  // Everything TomLoggingWorkerContext adds over a plain TomWorkerContext is in
  // its initializeIsolate(): it registers the executor that replays records
  // arriving in the spawned worker. The pool runs that hook inside the isolate,
  // where nothing here can watch it, so this calls it directly and reads the
  // dispatch chain back. (That the context is accepted by a pool at all — the
  // inheritance — is already exercised above, where example 3 builds one from
  // it.)
  final executorsBefore = List<TomExecutor>.of(TomWorker.executors);
  await context.initializeIsolate();
  final registeredExecutor =
      TomWorker.executors.length == executorsBefore.length
      ? null
      : TomWorker.executors.last;
  // Restore: the chain just written is the main isolate's, not a worker's.
  TomWorker.clearExecutors();
  executorsBefore.forEach(TomWorker.addExecutor);

  final registersLoggingExecutor = registeredExecutor is TomLoggingExecutor;
  print(
    '   initializeIsolate registers a TomLoggingExecutor? '
    '$registersLoggingExecutor (${registeredExecutor.runtimeType})',
  );

  // startLoggingToCreator swaps the global output to a creator-routing sink.
  final beforeSwap = tomLog.logOutput;
  TomIsolateLogging.startLoggingToCreator();
  final swappedToCreator = tomLog.logOutput is TomCreatorLogOutput;
  tomLog.logOutput = beforeSwap; // restore
  print(
    '   startLoggingToCreator installs TomCreatorLogOutput? '
    '$swappedToCreator',
  );
  print(
    '   (startIsolatedLogging spawns a real logging pool — shown in tests)',
  );
  print('');

  // ===========================================================================
  // Example 6: Remote payloads — TomRemoteLogMessage / Result / Context
  // ===========================================================================

  print('6. Remote-logging payloads:');

  final emptyRemote = TomRemoteLogMessage();
  final originalSenderId = TomRemoteLogMessage.globalSettingSenderIdResolver;
  TomRemoteLogMessage.globalSettingSenderIdResolver = () => 'edge-node-7';
  final remoteMessage = TomRemoteLogMessage.of(
    TomLogLevel.production.levelPattern,
    TomLogLevel.info.levelPattern,
    TomLogger.INFO,
    'remote hello',
    'main',
    fixedTime.toIso8601String(),
    'App.ping',
  );
  TomRemoteLogMessage.globalSettingSenderIdResolver = originalSenderId;

  print('   default sender:         "${emptyRemote.sender}"');
  print('   configured sender:      ${remoteMessage.sender}');
  print('   message.toString():     ${remoteMessage.toString()}');

  final okResult = TomRemoteLogResult();
  final errResult = TomRemoteLogResult.withError('sink unavailable');
  print('   ok result   -> hasError=${okResult.hasError}');
  print(
    '   err result  -> hasError=${errResult.hasError} '
    '"${errResult.errorMessage}"',
  );

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

  print(
    '   receive(clean)  -> hasError=${cleanResult.hasError}, '
    'isolate="$serverIsolateName" (sender prefixed)',
  );
  print(
    '   receive(hostile)-> hasError=${hostileResult.hasError}, '
    'sanitized="$sanitizedMessage"',
  );
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
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'recovered by retry',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final retriedSends = flaky.sendCount;
  final retriedAccepted = flaky.accepted.map((m) => m.message).toList();

  // 9b: the endpoint is fully down — the record is buffered for replay (and
  // still surfaced locally so nothing is lost).
  final down = _ScriptedLogEndpoint([_SendOutcome.throwError]);
  TomRemoteLogOutput.remoteEndpoint = down;
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'buffered while down',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final queuedAfterOutage = TomRemoteLogOutput.replayQueueLength;

  // 9c: the endpoint recovers — the next record drains the buffer oldest-first
  // before sending itself, so ordering is preserved across the outage.
  final recovered = _ScriptedLogEndpoint([_SendOutcome.ok]);
  TomRemoteLogOutput.remoteEndpoint = recovered;
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'flush trigger',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final drainedAccepted = recovered.accepted.map((m) => m.message).toList();
  final queueAfterDrain = TomRemoteLogOutput.replayQueueLength;

  // 9d: the endpoint is reachable and answers HTTP 200 — but refuses to store
  // the record, saying so in the response body. Nothing about the transport is
  // wrong, so this is the one failure a sender that only checks the HTTP status
  // would report as a complete success. It is treated like any other failure:
  // retried, surfaced locally with the server's own reason, and buffered.
  final refusing = _ScriptedLogEndpoint([_SendOutcome.returnServerRejection]);
  TomRemoteLogOutput.remoteEndpoint = refusing;
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'refused by collector',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final refusedSends = refusing.sendCount;
  final queuedAfterRefusal = TomRemoteLogOutput.replayQueueLength;
  // lastWhere, not firstWhere: 9b's outage already wrote a warning into this
  // same sink, and the one being demonstrated here is the most recent.
  final refusalWarning = resilienceFallback.messages.lastWhere(
    (m) => m.startsWith('Could not send log message'),
    orElse: () => '',
  );

  // 9e: two records logged back to back. output() returns before its record is
  // sent, so the second call starts while the first is still draining the
  // buffer left by 9d — overlapping calls are the normal case, not an exotic
  // one. Deliveries are serialised in call order, so the backlog still arrives
  // ahead of the live records and no record is sent twice.
  final ordered = _ScriptedLogEndpoint([_SendOutcome.ok]);
  TomRemoteLogOutput.remoteEndpoint = ordered;
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'back to back 1',
    'main',
    fixedTime,
    null,
  );
  resilientOutput.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'back to back 2',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final orderedAccepted = ordered.accepted.map((m) => m.message).toList();

  // Restore defaults so the example leaves no global state behind.
  TomRemoteLogOutput.globalSettingFallbackOutput = originalRemoteFallback;
  TomRemoteLogOutput.remoteEndpoint = null;
  TomRemoteLogOutput.globalSettingMaxSendRetries = 0;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
  TomRemoteLogOutput.clearReplayQueue();

  print('   9a retry: $retriedSends sends, accepted=$retriedAccepted');
  print('   9b outage: queued=$queuedAfterOutage record(s)');
  print('   9c drain:  accepted=$drainedAccepted, queue now $queueAfterDrain');
  print(
    '   9d refusal: $refusedSends sends, queued=$queuedAfterRefusal, '
    'warning="$refusalWarning"',
  );
  print('   9e order:  accepted=$orderedAccepted');
  print('');

  // ===========================================================================
  // Example 10: Durable replay store — buffered records survive a restart
  // ===========================================================================

  print('10. Durable replay store (records survive a process restart):');

  // The replay queue's storage is pluggable. The default keeps records in
  // memory (lost if the process exits mid-outage); a file-backed store mirrors
  // them to disk so a fresh process resumes with the buffered records.
  final storeDir = Directory.systemTemp.createTempSync(
    'tom_core_kernel_replay_',
  );
  final storePath = '${storeDir.path}/replay_queue.json';

  final durableFallback = _CapturingOutput();
  TomRemoteLogOutput.globalSettingFallbackOutput = durableFallback;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 4;

  // 10a: first process — endpoint is down, so records buffer to disk.
  TomRemoteLogOutput.globalSettingReplayStore = TomFileLogReplayStore(
    storePath,
  );
  TomRemoteLogOutput.remoteEndpoint = _ScriptedLogEndpoint([
    _SendOutcome.throwError,
  ]);
  final firstProcess = TomRemoteLogOutput();
  firstProcess.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'queued before restart A',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  firstProcess.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'queued before restart B',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final bufferedBeforeRestart = TomRemoteLogOutput.replayQueueLength;

  // 10b: simulate a restart — a brand-new store instance at the same path
  // reloads what the "previous process" buffered.
  TomRemoteLogOutput.globalSettingReplayStore = TomFileLogReplayStore(
    storePath,
  );
  final reloadedAfterRestart = TomRemoteLogOutput.replayQueueLength;

  // 10c: the endpoint recovers — the reloaded records drain oldest-first.
  final durableRecovered = _ScriptedLogEndpoint([_SendOutcome.ok]);
  TomRemoteLogOutput.remoteEndpoint = durableRecovered;
  final secondProcess = TomRemoteLogOutput();
  secondProcess.output(
    TomLogLevel.production,
    TomLogLevel.info,
    TomLogger.INFO,
    'after restart C',
    'main',
    fixedTime,
    null,
  );
  await Future<void>.delayed(Duration.zero);
  final durableDrained = durableRecovered.accepted
      .map((m) => m.message)
      .toList();
  final durableQueueAfter = TomRemoteLogOutput.replayQueueLength;

  // A record in the store's on-disk shape, for hand-building damaged files.
  String onDisk(String message) => jsonEncode({
    'sender': '',
    'timeStamp': fixedTime.toIso8601String(),
    'loggerLevel': TomLogLevel.production.levelPattern,
    'logLevel': TomLogLevel.info.levelPattern,
    'level': TomLogger.INFO,
    'message': message,
    'isolateName': 'main',
    'origin': null,
  });

  // 10d: a crash mid-write leaves a half-written array. Refusing to open it
  // would be the durable buffer taking down the process it exists to protect,
  // so the store opens it, reports the loss, and moves the unreadable bytes
  // aside for diagnosis rather than overwriting them.
  // Nothing is salvaged here, and that is not a shortcoming of the recovery:
  // JSON parses all-or-nothing, so a truncated array has no readable prefix.
  File(storePath).writeAsStringSync('[${onDisk('lost to truncation')}, "half');
  durableFallback.messages.clear();
  final afterCrash = TomFileLogReplayStore(storePath);
  final crashSalvaged = afterCrash.snapshot().map((m) => m.message).toList();
  final crashReported = durableFallback.messages.any(
    (m) => m.contains('could not be read'),
  );
  final quarantined = File('$storePath.corrupt').existsSync();

  // 10e: damage the parser *can* see past — a well-formed array with junk
  // among the records. Here salvage is real: the readable records are kept
  // and only the junk is dropped, so partial damage no longer presents as an
  // empty queue. The count of what was dropped is reported.
  File(
    storePath,
  ).writeAsStringSync('[1, ${onDisk('kept A')}, "junk", ${onDisk('kept B')}]');
  durableFallback.messages.clear();
  final afterPartial = TomFileLogReplayStore(storePath);
  final partialSalvaged = afterPartial
      .snapshot()
      .map((m) => m.message)
      .toList();
  final partialReport = durableFallback.messages.firstWhere(
    (m) => m.contains('unreadable'),
    orElse: () => '',
  );

  // Restore defaults (back to the zero-config in-memory store) and clean up.
  TomRemoteLogOutput.globalSettingFallbackOutput = originalRemoteFallback;
  TomRemoteLogOutput.remoteEndpoint = null;
  TomRemoteLogOutput.globalSettingReplayQueueMaxSize = 0;
  TomRemoteLogOutput.globalSettingReplayStore = TomInMemoryLogReplayStore();
  TomRemoteLogOutput.clearReplayQueue();
  storeDir.deleteSync(recursive: true);

  print('   10a before restart: buffered=$bufferedBeforeRestart to disk');
  print('   10b after restart:  reloaded=$reloadedAfterRestart from disk');
  print(
    '   10c drain:          accepted=$durableDrained, '
    'queue now $durableQueueAfter',
  );
  print(
    '   10d truncated file: salvaged=$crashSalvaged, '
    'reported=$crashReported, quarantined=$quarantined',
  );
  print('   10e partial damage: salvaged=$partialSalvaged');
  print('');

  // ===========================================================================
  // Assertions (run under --enable-asserts)
  // ===========================================================================

  // Example 1: inter-isolate record
  assert(record.isolateName == 'worker-1');
  assert(record.level == TomLogger.INFO);
  assert(record.message == 'worker started');
  assert(record.origin == 'App.boot');
  assert(
    record.toString() ==
        'TomInterIsolateLogMessage worker-1 INFO    worker started',
  );

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
  assert(registersLoggingExecutor);
  assert(swappedToCreator);

  // Example 6: remote payloads
  assert(emptyRemote.sender == '');
  assert(remoteMessage.sender == 'edge-node-7');
  assert(remoteMessage.message == 'remote hello');
  assert(remoteMessage.origin == 'App.ping');
  assert(
    remoteMessage.toString() == 'TomRemoteLogMessage main INFO    remote hello',
  );
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
  assert(
    retriedAccepted.length == 1 &&
        retriedAccepted.first == 'recovered by retry',
  );
  assert(queuedAfterOutage == 1); // record buffered while endpoint down
  // The buffered record drains before the trigger, preserving order.
  assert(drainedAccepted.length == 2);
  assert(drainedAccepted[0] == 'buffered while down');
  assert(drainedAccepted[1] == 'flush trigger');
  assert(queueAfterDrain == 0); // queue fully drained
  // A payload refusal over HTTP 200 is a failure like any other: the full
  // retry budget is spent, the record is buffered, and the collector's own
  // reason reaches the operator rather than a bare "something went wrong".
  assert(refusedSends == 4); // one attempt + three retries
  assert(queuedAfterRefusal == 1);
  assert(refusalWarning.contains(_rejectionReason));
  // Two overlapping calls: 9d's buffered record drains first, then the two live
  // records in the order they were logged, each exactly once.
  assert(orderedAccepted.length == 3);
  assert(orderedAccepted[0] == 'refused by collector');
  assert(orderedAccepted[1] == 'back to back 1');
  assert(orderedAccepted[2] == 'back to back 2');

  // Example 10: durable store persists the queue across a simulated restart
  assert(bufferedBeforeRestart == 2); // both records buffered to disk
  assert(reloadedAfterRestart == 2); // reloaded by the fresh store instance
  assert(durableDrained.length == 3); // two reloaded + the trigger record
  assert(durableDrained[0] == 'queued before restart A');
  assert(durableDrained[1] == 'queued before restart B');
  assert(durableDrained[2] == 'after restart C');
  assert(durableQueueAfter == 0); // queue fully drained after recovery
  // A truncated file opens instead of throwing. Nothing survives it — JSON
  // has no readable prefix — but the loss is reported and the bytes kept.
  assert(crashSalvaged.isEmpty);
  assert(crashReported);
  assert(quarantined);
  // Damage the parser can see past is salvaged: the two records survive and
  // only the two junk entries are dropped, with the count reported.
  assert(partialSalvaged.length == 2);
  assert(partialSalvaged[0] == 'kept A');
  assert(partialSalvaged[1] == 'kept B');
  assert(partialReport.contains('2 unreadable entries'));
}

/// How a single scripted [_ScriptedLogEndpoint] send should behave.
enum _SendOutcome {
  /// Succeed with an empty result and no error.
  ok,

  /// Throw a transport exception (simulating an unreachable endpoint).
  throwError,

  /// Answer with HTTP success but refuse the record in the payload, as a
  /// collector does when it is reachable and healthy but will not store what
  /// it was sent — out of disk, over quota, a rejected schema.
  ///
  /// Nothing about the transport is wrong here, so this is the failure a
  /// sender misses if it inspects only [TomServerCallError].
  returnServerRejection,
}

/// The refusal reason [_SendOutcome.returnServerRejection] answers with.
const String _rejectionReason = 'quota exceeded';

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
      case _SendOutcome.returnServerRejection:
        // No TomServerCallError: the call itself succeeded, and the refusal is
        // in the body the server sent back.
        return (TomRemoteLogResult.withError(_rejectionReason), null);
      case _SendOutcome.ok:
        accepted.add(load);
        return (responseObject ?? TomRemoteLogResult(), null);
    }
  }
}

Future<void> main() async {
  prepareSampleProcess();
  await run();
}
