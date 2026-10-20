// ignore_for_file: avoid_print
/// Executable example of a graceful shutdown: what a server does between
/// SIGTERM and exiting.
///
/// `TomServer.start` registers its `TomGracefulShutdown` for SIGTERM and SIGINT,
/// and the shutdown runs in a fixed order: readiness turns to 503, new
/// requests are refused, the requests in flight and the scheduled runs already
/// started finish within the grace period, the schedulers' leases are released
/// and the data sources closed. This example drives the same shutdown by
/// calling it, around a handler and a scheduler of its own, so every step can
/// be observed on its own.
///
/// No socket is bound and no signal is sent: the requests run through the
/// shutdown's middleware directly. The signal, the socket and the process exit
/// are covered by `test/graceful_shutdown_test.dart`, which sends a real
/// SIGTERM to a server process; `doc/server.md` describes the shutdown in a
/// real server.
///
/// Run with `dart run example/server/graceful_shutdown_example.dart`. Every
/// step checks its own result and the run fails when one does not hold, so a
/// green run is a verification and not just a transcript.
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A scheduled run that keeps going until [release] completes.
class _Report extends TomCommand {
  _Report(this.started, this.release);

  final Completer<void> started;
  final Future<void> release;

  @override
  Future<Object?> execute() async {
    started.complete();
    await release;
    return 'report written';
  }
}

Future<void> run() async {
  tomLog.setLogLevel(TomLogLevel.errors);
  final shutdown = TomGracefulShutdown(gracePeriod: const Duration(seconds: 5));

  // The application's handler behind the gate; `/slow` waits for a release.
  final finishSlow = Completer<void>();
  final handler = shutdown.middleware()((request) async {
    if (request.url.path == 'slow') await finishSlow.future;
    return Response.ok('answered ${request.url.path}');
  });
  Future<Response> get(String path) => Future.sync(
    () => handler(Request('GET', Uri.parse('http://localhost/$path'))),
  );

  // A scheduler with one run in progress, holding its lease.
  final lock = TomMemoryLeaseLock();
  final scheduler = TomScheduler(
    store: TomMemoryJobStore(),
    dispatcher: const TomInlineJobDispatcher(),
    lock: lock,
  );
  final runStarted = Completer<void>();
  final finishRun = Completer<void>();
  scheduler.register(
    TomJobDefinition(
      name: 'report',
      schedule: const TomEventSchedule(
        Stream<Object?>.empty(),
        sourceName: 'example',
      ),
      body: (_) => _Report(runStarted, finishRun.future),
    ),
  );
  final now = DateTime.now();
  await scheduler.store.enqueue(
    TomJobRun(id: 'report:1', jobName: 'report', scheduledFor: now, runAt: now),
  );
  unawaited(scheduler.start());
  await runStarted.future;

  // 1. Before the shutdown: a request in flight is counted, the run holds its
  //    lease, readiness answers 200.
  final slow = get('slow');
  await Future<void>.delayed(Duration.zero);
  final readyBefore = await TomHealthServer().ready();
  print(
    '1. in flight: ${shutdown.inFlight}, lease held: '
    '${(await lock.inspect('job:report')).isHeld}, '
    '/ready ${readyBefore.statusCode}',
  );
  check(shutdown.inFlight == 1, 'the gate counts the request in flight');
  check(
    (await lock.inspect('job:report')).isHeld,
    'the running job holds its lease',
  );
  check(readyBefore.statusCode == 200, 'the server is ready before it stops');

  // 2. The shutdown starts: readiness turns to 503 and liveness stays 200,
  //    because a draining process is alive.
  final done = shutdown.shutdown();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final ready = await TomHealthServer().ready();
  final live = await TomHealthServer().health();
  final readyBody = await ready.readAsString();
  print(
    '2. /ready ${ready.statusCode} "$readyBody", /health ${live.statusCode}',
  );
  check(ready.statusCode == 503, 'readiness reports the shutdown');
  check(readyBody == 'shutting down', 'and says why');
  check(live.statusCode == 200, 'liveness keeps answering');

  // 3. A new request is refused at the gate, with the headers that send a
  //    client elsewhere.
  final refused = await get('orders');
  print(
    '3. new request -> ${refused.statusCode}, Connection: '
    '${refused.headers['connection']}, Retry-After: '
    '${refused.headers['retry-after']}',
  );
  check(shutdown.isDraining, 'the shutdown is draining');
  check(refused.statusCode == 503, 'a new request is refused');
  check(
    refused.headers['connection'] == 'close' &&
        refused.headers['retry-after'] == '1',
    'the refusal closes the connection and invites a retry elsewhere',
  );

  // 4. The probe paths pass the gate, so the orchestrator keeps seeing an
  //    alive, unready process.
  final probe = await get('health');
  print('4. probe paths $tomProbePaths -> /health ${probe.statusCode}');
  check(probe.statusCode == 200, 'a probe is passed through while draining');

  // 5. The scheduler is stopped, so no new run begins, but the run already
  //    started is waited for.
  print(
    '5. scheduler running: ${scheduler.isRunning}, still started: '
    '${TomScheduler.started.contains(scheduler)}',
  );
  check(!scheduler.isRunning, 'no new run may start');
  check(
    TomScheduler.started.contains(scheduler),
    'the scheduler is not closed while its run drains',
  );

  // 6. The work finishes: the request is answered, the run succeeds, and the
  //    lease is released rather than left to its TTL.
  finishSlow.complete();
  finishRun.complete();
  final answered = await slow;
  await done;
  final released = !(await lock.inspect('job:report')).isHeld;
  final runState = (await scheduler.store.all()).single.state;
  print(
    '6. slow request -> ${answered.statusCode}, run $runState, '
    'lease released: $released, in flight: ${shutdown.inFlight}',
  );
  check(answered.statusCode == 200, 'the request in flight was answered');
  check(runState == TomJobRunState.succeeded, 'the run was drained');
  check(released, 'the lease was handed back on close');
  check(shutdown.inFlight == 0, 'nothing is left in flight');
  check(
    identical(shutdown.shutdown(), done),
    'a second call is handed the first shutdown',
  );

  TomHealthServer.resetHealthChecks();
  print('\nGraceful shutdown example completed.');
}

void main() => run();
